import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'app_database.dart';
import 'models.dart';

class TalentosRepository {
  final AppDatabase _appDatabase;
  final _uuid = const Uuid();

  TalentosRepository([AppDatabase? appDatabase])
      : _appDatabase = appDatabase ?? AppDatabase();

  Future<Database> get _db async => await _appDatabase.database;

  String _nowIso() => DateTime.now().toIso8601String();

  // ==========================================
  // OPERAÇÕES DE ALUNOS
  // ==========================================

  Future<AlunoModel?> buscarAlunoPorUid(String uid) async {
    final db = await _db;
    final results = await db.query(
      'alunos',
      where: 'uid = ?',
      whereArgs: [uid],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return AlunoModel.fromMap(results.first);
  }

  Future<AlunoModel> buscarOuCadastrarAluno(String uid, {String nomePadrao = 'Novo Aluno'}) async {
    final existente = await buscarAlunoPorUid(uid);
    if (existente != null) return existente;

    final novo = AlunoModel(
      uid: uid,
      nome: nomePadrao,
      saldoTalentos: 0,
      ativo: true,
      updatedAt: _nowIso(),
      synced: false,
    );
    await cadastrarAluno(novo);
    return novo;
  }

  Future<void> cadastrarAluno(AlunoModel aluno) async {
    final db = await _db;
    await db.insert(
      'alunos',
      aluno.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> atualizarNomeAluno(String uid, String novoNome) async {
    final db = await _db;
    await db.update(
      'alunos',
      {
        'nome': novoNome,
        'updated_at': _nowIso(),
        'synced': 0,
      },
      where: 'uid = ?',
      whereArgs: [uid],
    );
  }

  Future<List<AlunoModel>> listarAlunos({bool apenasAtivos = true}) async {
    final db = await _db;
    final results = await db.query(
      'alunos',
      where: apenasAtivos ? 'ativo = 1' : null,
      orderBy: 'nome ASC',
    );
    return results.map((e) => AlunoModel.fromMap(e)).toList();
  }

  Future<List<AlunoModel>> buscarAlunosPorNome(String termo) async {
    final db = await _db;
    final results = await db.query(
      'alunos',
      where: 'nome LIKE ?',
      whereArgs: ['%$termo%'],
      orderBy: 'nome ASC',
    );
    return results.map((e) => AlunoModel.fromMap(e)).toList();
  }

  /// Lista alunos que ainda não possuem tag NFC física vinculada (UID manual começando com MANUAL_)
  Future<List<AlunoModel>> listarAlunosSemTag() async {
    final db = await _db;
    final results = await db.query(
      'alunos',
      where: 'uid LIKE ? AND ativo = 1',
      whereArgs: ['MANUAL_%'],
      orderBy: 'nome ASC',
    );
    return results.map((e) => AlunoModel.fromMap(e)).toList();
  }

  /// Transfere/substitui o UID temporário por uma tag NFC real
  Future<void> vincularTagAoAluno({
    required String uidAntigo,
    required String novoUidTag,
  }) async {
    final db = await _db;
    await db.transaction((txn) async {
      final now = _nowIso();

      // Busca dados do aluno antigo
      final rows = await txn.query('alunos', where: 'uid = ?', whereArgs: [uidAntigo]);
      if (rows.isEmpty) throw StateError('Aluno não encontrado.');
      final aluno = AlunoModel.fromMap(rows.first);

      // Insere com o novo UID
      await txn.insert('alunos', {
        'uid': novoUidTag,
        'nome': aluno.nome,
        'turma': aluno.turma,
        'saldo_talentos': aluno.saldoTalentos,
        'ativo': aluno.ativo ? 1 : 0,
        'updated_at': now,
        'synced': 0,
      });

      // Atualiza referências em transações e vendas
      await txn.update(
        'transacoes_saldo',
        {'aluno_uid': novoUidTag, 'synced': 0},
        where: 'aluno_uid = ?',
        whereArgs: [uidAntigo],
      );

      await txn.update(
        'vendas',
        {'aluno_uid': novoUidTag, 'synced': 0},
        where: 'aluno_uid = ?',
        whereArgs: [uidAntigo],
      );

      // Remove o registro temporário
      await txn.delete('alunos', where: 'uid = ?', whereArgs: [uidAntigo]);
    });
  }

  // ==========================================
  // REGRAS DE NEGÓCIO E TRANSAÇÕES ATÔMICAS
  // ==========================================

  /// Incrementa ou decrementa talentos do aluno de forma atômica com registro de transação
  Future<int> adicionarTalentos({
    required String alunoUid,
    required int quantidade,
    required String motivo,
    String operador = 'Professor',
  }) async {
    final db = await _db;
    return await db.transaction<int>((txn) async {
      // 1. Busca aluno atual para travar estado dentro da transação
      final rows = await txn.query(
        'alunos',
        columns: ['saldo_talentos'],
        where: 'uid = ?',
        whereArgs: [alunoUid],
        limit: 1,
      );

      if (rows.isEmpty) {
        throw StateError('Aluno com UID $alunoUid não encontrado.');
      }

      final saldoAtual = (rows.first['saldo_talentos'] as num).toInt();
      final novoSaldo = saldoAtual + quantidade;

      if (novoSaldo < 0) {
        throw SaldoInsuficienteException(
          alunoUid: alunoUid,
          saldoAtual: saldoAtual,
          totalNecessario: quantidade.abs(),
        );
      }

      final now = _nowIso();

      // 2. Atualiza saldo do aluno
      await txn.update(
        'alunos',
        {
          'saldo_talentos': novoSaldo,
          'updated_at': now,
          'synced': 0,
        },
        where: 'uid = ?',
        whereArgs: [alunoUid],
      );

      // 3. Registra na tabela de transacoes_saldo
      final transacao = TransacaoSaldoModel(
        id: _uuid.v4(),
        alunoUid: alunoUid,
        tipo: quantidade >= 0 ? 'ENTRADA' : 'SAIDA',
        quantidade: quantidade.abs(),
        motivo: motivo,
        operador: operador,
        createdAt: now,
        synced: false,
      );
      await txn.insert('transacoes_saldo', transacao.toMap());

      return novoSaldo;
    });
  }

  /// Processa venda de produtos/cantina de forma atômica
  Future<String> processarVenda({
    required String alunoUid,
    required List<ItemVendaDto> itens,
    required int totalTalentos,
  }) async {
    if (itens.isEmpty) {
      throw ArgumentError('A venda deve conter ao menos um item.');
    }

    final db = await _db;
    return await db.transaction<String>((txn) async {
      // 1. Validação estrita de saldo do aluno
      final rows = await txn.query(
        'alunos',
        columns: ['saldo_talentos'],
        where: 'uid = ?',
        whereArgs: [alunoUid],
        limit: 1,
      );

      if (rows.isEmpty) {
        throw StateError('Aluno com UID $alunoUid não encontrado.');
      }

      final saldoAtual = (rows.first['saldo_talentos'] as num).toInt();
      if (saldoAtual < totalTalentos) {
        throw SaldoInsuficienteException(
          alunoUid: alunoUid,
          saldoAtual: saldoAtual,
          totalNecessario: totalTalentos,
        );
      }

      final now = _nowIso();
      final novoSaldo = saldoAtual - totalTalentos;
      final vendaId = _uuid.v4();

      // 2. Deduz o saldo do aluno
      await txn.update(
        'alunos',
        {
          'saldo_talentos': novoSaldo,
          'updated_at': now,
          'synced': 0,
        },
        where: 'uid = ?',
        whereArgs: [alunoUid],
      );

      // 3. Registra transacao de débito
      final transacao = TransacaoSaldoModel(
        id: _uuid.v4(),
        alunoUid: alunoUid,
        tipo: 'SAIDA',
        quantidade: totalTalentos,
        motivo: 'Compra na Lojinha/Cantina (Venda #$vendaId)',
        operador: 'Caixa',
        createdAt: now,
        synced: false,
      );
      await txn.insert('transacoes_saldo', transacao.toMap());

      // 4. Cria registro na tabela de vendas
      final venda = VendaModel(
        id: vendaId,
        alunoUid: alunoUid,
        totalTalentos: totalTalentos,
        createdAt: now,
        synced: false,
      );
      await txn.insert('vendas', venda.toMap());

      // 5. Insere itens e deduz estoque de produtos existentes
      for (final item in itens) {
        await txn.insert('venda_itens', item.toMap(vendaId));

        if (item.produtoId != null) {
          // Busca produto para decrementar estoque
          final prodRows = await txn.query(
            'produtos',
            columns: ['estoque'],
            where: 'id = ?',
            whereArgs: [item.produtoId],
            limit: 1,
          );

          if (prodRows.isNotEmpty) {
            final estoqueAtual = (prodRows.first['estoque'] as num).toInt();
            final novoEstoque = (estoqueAtual - item.quantidade).clamp(0, 999999);
            await txn.update(
              'produtos',
              {
                'estoque': novoEstoque,
                'esgotado': novoEstoque == 0 ? 1 : 0,
                'updated_at': now,
                'synced': 0,
              },
              where: 'id = ?',
              whereArgs: [item.produtoId],
            );
          }
        }
      }

      return vendaId;
    });
  }

  // ==========================================
  // OPERAÇÕES DE PRODUTOS
  // ==========================================

  Future<int> criarProduto(ProdutoModel produto) async {
    final db = await _db;
    return await db.insert('produtos', produto.toMap());
  }

  Future<List<ProdutoModel>> listarProdutos({bool apenasDisponiveis = true}) async {
    final db = await _db;
    final results = await db.query(
      'produtos',
      where: apenasDisponiveis ? 'esgotado = 0' : null,
      orderBy: 'nome ASC',
    );
    return results.map((e) => ProdutoModel.fromMap(e)).toList();
  }

  Future<void> alternarStatusEsgotado(int produtoId, bool esgotado) async {
    final db = await _db;
    await db.update(
      'produtos',
      {
        'esgotado': esgotado ? 1 : 0,
        'updated_at': _nowIso(),
        'synced': 0,
      },
      where: 'id = ?',
      whereArgs: [produtoId],
    );
  }

  // ==========================================
  // HISTÓRICO DE TRANSAÇÕES DO ALUNO
  // ==========================================

  Future<List<TransacaoSaldoModel>> listarTransacoesDoAluno(String alunoUid, {int limit = 20}) async {
    final db = await _db;
    final results = await db.query(
      'transacoes_saldo',
      where: 'aluno_uid = ?',
      whereArgs: [alunoUid],
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return results.map((e) => TransacaoSaldoModel.fromMap(e)).toList();
  }

  // ==========================================
  // SINCRONIZAÇÃO HÍBRIDA (LOCAL-FIRST)
  // ==========================================

  Future<int> contarTotalPendentesSincronizacao() async {
    final db = await _db;
    final a = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM alunos WHERE synced = 0')) ?? 0;
    final p = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM produtos WHERE synced = 0')) ?? 0;
    final t = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM transacoes_saldo WHERE synced = 0')) ?? 0;
    final v = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM vendas WHERE synced = 0')) ?? 0;
    return a + p + t + v;
  }

  Future<List<Map<String, dynamic>>> obterAlunosPendentes() async {
    final db = await _db;
    return await db.query('alunos', where: 'synced = 0');
  }

  Future<List<Map<String, dynamic>>> obterProdutosPendentes() async {
    final db = await _db;
    return await db.query('produtos', where: 'synced = 0');
  }

  Future<List<Map<String, dynamic>>> obterTransacoesPendentes() async {
    final db = await _db;
    return await db.query('transacoes_saldo', where: 'synced = 0');
  }

  Future<List<Map<String, dynamic>>> obterVendasPendentes() async {
    final db = await _db;
    return await db.query('vendas', where: 'synced = 0');
  }

  Future<List<Map<String, dynamic>>> obterItensVenda(String vendaId) async {
    final db = await _db;
    return await db.query('venda_itens', where: 'venda_id = ?', whereArgs: [vendaId]);
  }

  Future<void> marcarAlunosSincronizados(List<String> uids) async {
    if (uids.isEmpty) return;
    final db = await _db;
    final batch = db.batch();
    for (final uid in uids) {
      batch.update('alunos', {'synced': 1}, where: 'uid = ?', whereArgs: [uid]);
    }
    await batch.commit(noResult: true);
  }

  Future<void> marcarProdutosSincronizados(List<int> ids) async {
    if (ids.isEmpty) return;
    final db = await _db;
    final batch = db.batch();
    for (final id in ids) {
      batch.update('produtos', {'synced': 1}, where: 'id = ?', whereArgs: [id]);
    }
    await batch.commit(noResult: true);
  }

  Future<void> marcarTransacoesSincronizadas(List<String> ids) async {
    if (ids.isEmpty) return;
    final db = await _db;
    final batch = db.batch();
    for (final id in ids) {
      batch.update('transacoes_saldo', {'synced': 1}, where: 'id = ?', whereArgs: [id]);
    }
    await batch.commit(noResult: true);
  }

  Future<void> marcarVendasSincronizadas(List<String> ids) async {
    if (ids.isEmpty) return;
    final db = await _db;
    final batch = db.batch();
    for (final id in ids) {
      batch.update('vendas', {'synced': 1}, where: 'id = ?', whereArgs: [id]);
    }
    await batch.commit(noResult: true);
  }

  /// Mescla alunos recebidos do Supabase com o banco local
  Future<int> mesclarAlunosRemotos(List<Map<String, dynamic>> alunosRemotos) async {
    if (alunosRemotos.isEmpty) return 0;
    final db = await _db;
    int alterados = 0;

    await db.transaction((txn) async {
      for (final remoto in alunosRemotos) {
        final uid = remoto['uid'] as String?;
        if (uid == null) continue;

        final local = await txn.query('alunos', where: 'uid = ?', whereArgs: [uid], limit: 1);
        final dadosParaSalvar = {
          'uid': uid,
          'nome': remoto['nome'] ?? 'Aluno',
          'turma': remoto['turma'],
          'saldo_talentos': (remoto['saldo_talentos'] as num?)?.toInt() ?? 0,
          'ativo': (remoto['ativo'] == true || remoto['ativo'] == 1) ? 1 : 0,
          'updated_at': remoto['updated_at'] ?? _nowIso(),
          'synced': 1,
        };

        if (local.isEmpty) {
          await txn.insert('alunos', dadosParaSalvar);
          alterados++;
        } else {
          // Se o local já está sincronizado ou o remoto tem data mais recente, atualiza
          final localSynced = (local.first['synced'] as num?)?.toInt() ?? 0;
          if (localSynced == 1) {
            await txn.update('alunos', dadosParaSalvar, where: 'uid = ?', whereArgs: [uid]);
            alterados++;
          }
        }
      }
    });

    return alterados;
  }

  /// Mescla produtos recebidos do Supabase com o banco local
  Future<int> mesclarProdutosRemotos(List<Map<String, dynamic>> produtosRemotos) async {
    if (produtosRemotos.isEmpty) return 0;
    final db = await _db;
    int alterados = 0;

    await db.transaction((txn) async {
      for (final remoto in produtosRemotos) {
        final id = (remoto['id'] as num?)?.toInt();
        if (id == null) continue;

        final local = await txn.query('produtos', where: 'id = ?', whereArgs: [id], limit: 1);
        final dadosParaSalvar = {
          'id': id,
          'nome': remoto['nome'] ?? 'Produto',
          'valor_talentos': (remoto['valor_talentos'] as num?)?.toInt() ?? 1,
          'estoque': (remoto['estoque'] as num?)?.toInt() ?? 0,
          'esgotado': (remoto['esgotado'] == true || remoto['esgotado'] == 1) ? 1 : 0,
          'updated_at': remoto['updated_at'] ?? _nowIso(),
          'synced': 1,
        };

        if (local.isEmpty) {
          await txn.insert('produtos', dadosParaSalvar);
          alterados++;
        } else {
          final localSynced = (local.first['synced'] as num?)?.toInt() ?? 0;
          if (localSynced == 1) {
            await txn.update('produtos', dadosParaSalvar, where: 'id = ?', whereArgs: [id]);
            alterados++;
          }
        }
      }
    });

    return alterados;
  }
}
