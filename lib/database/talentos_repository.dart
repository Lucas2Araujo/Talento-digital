import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'app_database.dart';
import 'models.dart';

class TalentosRepository {
  final AppDatabase _appDatabase;
  final _uuid = const Uuid();

  // ------------------------------------------
  // MODO SANDBOX (100% In-Memory)
  // ------------------------------------------
  bool _isSandboxMode = false;
  bool get isSandboxMode => _isSandboxMode;

  final Map<String, AlunoModel> _sandboxAlunos = {};
  final Map<int, ProdutoModel> _sandboxProdutos = {};
  final List<TransacaoSaldoModel> _sandboxTransacoes = [];
  final List<VendaModel> _sandboxVendas = [];

  void setSandboxMode(bool enabled) {
    _isSandboxMode = enabled;
    if (enabled && _sandboxAlunos.isEmpty && _sandboxProdutos.isEmpty) {
      gerarDadosDemonstracao();
    }
  }

  void gerarDadosDemonstracao() {
    _sandboxAlunos.clear();
    _sandboxProdutos.clear();
    _sandboxTransacoes.clear();
    _sandboxVendas.clear();

    final now = _nowIso();

    final demos = [
      AlunoModel(
        uid: 'DEMO_1',
        tagAtualUid: 'TAG_LUCAS',
        nome: 'Lucas Silva',
        turma: 'Primários',
        saldoTalentos: 45,
        avatarId: 'leao',
        ativo: true,
        updatedAt: now,
      ),
      AlunoModel(
        uid: 'DEMO_2',
        tagAtualUid: 'TAG_SOPHIA',
        nome: 'Sophia Oliveira',
        turma: 'Juvenis',
        saldoTalentos: 80,
        avatarId: 'ovelha',
        ativo: true,
        updatedAt: now,
      ),
      AlunoModel(
        uid: 'DEMO_3',
        tagAtualUid: 'TAG_MATEUS',
        nome: 'Mateus Santos',
        turma: 'Adolescentes',
        saldoTalentos: 25,
        avatarId: 'aguia',
        ativo: true,
        updatedAt: now,
      ),
      AlunoModel(
        uid: 'DEMO_4',
        tagAtualUid: 'TAG_ISABELA',
        nome: 'Isabela Costa',
        turma: 'Primários',
        saldoTalentos: 60,
        avatarId: 'panda',
        ativo: true,
        updatedAt: now,
      ),
      AlunoModel(
        uid: 'DEMO_5',
        tagAtualUid: 'TAG_DANIEL',
        nome: 'Daniel Rocha',
        turma: 'Jardim',
        saldoTalentos: 15,
        avatarId: 'urso',
        ativo: true,
        updatedAt: now,
      ),
    ];

    for (final a in demos) {
      _sandboxAlunos[a.uid] = a;
    }

    final produtosDemo = [
      ProdutoModel(
        id: 1,
        nome: 'Lanchinho Natural',
        valorTalentos: 10,
        estoque: 15,
        iconeId: 'lanche',
        updatedAt: now,
      ),
      ProdutoModel(
        id: 2,
        nome: 'Mini Bíblia Infantil',
        valorTalentos: 25,
        estoque: 8,
        iconeId: 'biblia',
        updatedAt: now,
      ),
      ProdutoModel(
        id: 3,
        nome: 'Ursinho de Pelúcia',
        valorTalentos: 35,
        estoque: 5,
        iconeId: 'brinquedo',
        updatedAt: now,
      ),
      ProdutoModel(
        id: 4,
        nome: 'Kit Lápis de Cor',
        valorTalentos: 15,
        estoque: 12,
        iconeId: 'material',
        updatedAt: now,
      ),
      ProdutoModel(
        id: 5,
        nome: 'Cartela de Adesivos',
        valorTalentos: 5,
        estoque: 30,
        iconeId: 'adesivo',
        updatedAt: now,
      ),
      ProdutoModel(
        id: 6,
        nome: 'Pacote de Guloseimas',
        valorTalentos: 8,
        estoque: 20,
        iconeId: 'doce',
        updatedAt: now,
      ),
    ];

    for (final p in produtosDemo) {
      _sandboxProdutos[p.id!] = p;
    }
  }

  TalentosRepository([AppDatabase? appDatabase])
      : _appDatabase = appDatabase ?? AppDatabase();

  Future<Database> get _db async => await _appDatabase.database;

  String _nowIso() => DateTime.now().toIso8601String();

  // ==========================================
  // OPERAÇÕES DE ALUNOS
  // ==========================================

  Future<AlunoModel?> buscarAlunoPorUid(String uid) async {
    final result = await buscarAlunoPorTag(uid);
    if (result is BuscaTagResultEncontradoAtivo) {
      return result.aluno;
    } else if (result is BuscaTagResultEncontradoExtraviado) {
      return result.antigoDono;
    }
    return null;
  }

  /// Busca inteligente de tag NFC:
  /// - Encontrado ativo se tagAtualUid == tagUid ou uid == tagUid
  /// - Encontrado extraviado se tagUid está em tagsAntigas
  /// - Não cadastrado se nunca foi usada
  Future<BuscaTagResult> buscarAlunoPorTag(String tagUid) async {
    if (_isSandboxMode) {
      for (final a in _sandboxAlunos.values) {
        if (a.tagAtualUid == tagUid || a.uid == tagUid) {
          return BuscaTagResult.encontradoAtivo(a);
        }
      }
      for (final a in _sandboxAlunos.values) {
        if (a.tagsAntigas.contains(tagUid)) {
          return BuscaTagResult.encontradoExtraviado(a, tagUid);
        }
      }
      return BuscaTagResult.naoCadastrado(tagUid);
    }

    final db = await _db;
    // 1. Ativo
    final resultsAtivo = await db.query(
      'alunos',
      where: 'tag_atual_uid = ? OR uid = ?',
      whereArgs: [tagUid, tagUid],
      limit: 1,
    );
    if (resultsAtivo.isNotEmpty) {
      final aluno = AlunoModel.fromMap(resultsAtivo.first);
      if (aluno.tagAtualUid == tagUid ||
          (!aluno.tagsAntigas.contains(tagUid) && aluno.uid == tagUid)) {
        return BuscaTagResult.encontradoAtivo(aluno);
      }
    }

    // 2. Extraviado (busca em tags_antigas)
    final todos = await db.query('alunos');
    for (final row in todos) {
      final aluno = AlunoModel.fromMap(row);
      if (aluno.tagsAntigas.contains(tagUid)) {
        return BuscaTagResult.encontradoExtraviado(aluno, tagUid);
      }
    }

    return BuscaTagResult.naoCadastrado(tagUid);
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
    if (_isSandboxMode) {
      _sandboxAlunos[aluno.uid] = aluno;
      return;
    }

    final db = await _db;
    await db.insert(
      'alunos',
      aluno.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> atualizarNomeAluno(String uid, String novoNome) async {
    if (_isSandboxMode) {
      final a = _sandboxAlunos[uid];
      if (a != null) {
        _sandboxAlunos[uid] = a.copyWith(nome: novoNome, updatedAt: _nowIso());
      }
      return;
    }

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
    if (_isSandboxMode) {
      var list = _sandboxAlunos.values.toList();
      if (apenasAtivos) {
        list = list.where((a) => a.ativo).toList();
      }
      list.sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
      return list;
    }

    final db = await _db;
    final results = await db.query(
      'alunos',
      where: apenasAtivos ? 'ativo = 1' : null,
      orderBy: 'nome ASC',
    );
    return results.map((e) => AlunoModel.fromMap(e)).toList();
  }

  Future<List<AlunoModel>> buscarAlunosPorNome(String termo) async {
    if (_isSandboxMode) {
      final todos = await listarAlunos(apenasAtivos: false);
      final termoNorm = termo.trim().toLowerCase();
      return todos.where((a) => a.nome.toLowerCase().contains(termoNorm)).toList();
    }

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
    if (_isSandboxMode) {
      final todos = await listarAlunos(apenasAtivos: true);
      return todos.where((a) => a.uid.startsWith('MANUAL_')).toList();
    }

    final db = await _db;
    final results = await db.query(
      'alunos',
      where: 'uid LIKE ? AND ativo = 1',
      whereArgs: ['MANUAL_%'],
      orderBy: 'nome ASC',
    );
    return results.map((e) => AlunoModel.fromMap(e)).toList();
  }

  /// Vincula uma nova tag NFC ao aluno, preservando o histórico de tags antigas
  Future<void> vincularTagAoAluno({
    required String uidAntigo,
    required String novoUidTag,
  }) async {
    final now = _nowIso();

    final alunoAtual = await buscarAlunoPorUid(uidAntigo);
    if (alunoAtual == null) throw StateError('Aluno não encontrado: $uidAntigo');

    final tagsAntigasAtualizadas = List<String>.from(alunoAtual.tagsAntigas);
    final tagAnterior = alunoAtual.tagAtualUid ?? alunoAtual.uid;
    if (!tagAnterior.startsWith('MANUAL_') &&
        tagAnterior != novoUidTag &&
        !tagsAntigasAtualizadas.contains(tagAnterior)) {
      tagsAntigasAtualizadas.add(tagAnterior);
    }
    tagsAntigasAtualizadas.remove(novoUidTag);

    if (_isSandboxMode) {
      _sandboxAlunos[alunoAtual.uid] = alunoAtual.copyWith(
        tagAtualUid: novoUidTag,
        tagsAntigas: tagsAntigasAtualizadas,
        updatedAt: now,
      );
      return;
    }

    final db = await _db;
    await db.update(
      'alunos',
      {
        'tag_atual_uid': novoUidTag,
        'tags_antigas': jsonEncode(tagsAntigasAtualizadas),
        'updated_at': now,
        'synced': 0,
      },
      where: 'uid = ?',
      whereArgs: [alunoAtual.uid],
    );
  }

  /// Move a tag de volta de tags_antigas para tag_atual_uid (e a atual para tags_antigas)
  Future<void> reativarTagAntiga({
    required String alunoUid,
    required String tagUid,
  }) async {
    final now = _nowIso();
    final aluno = await buscarAlunoPorUid(alunoUid);
    if (aluno == null) throw StateError('Aluno não encontrado: $alunoUid');

    final tagsAntigasAtualizadas = List<String>.from(aluno.tagsAntigas);
    tagsAntigasAtualizadas.remove(tagUid);

    final tagAtual = aluno.tagAtualUid ?? aluno.uid;
    if (!tagAtual.startsWith('MANUAL_') &&
        tagAtual != tagUid &&
        !tagsAntigasAtualizadas.contains(tagAtual)) {
      tagsAntigasAtualizadas.add(tagAtual);
    }

    if (_isSandboxMode) {
      _sandboxAlunos[aluno.uid] = aluno.copyWith(
        tagAtualUid: tagUid,
        tagsAntigas: tagsAntigasAtualizadas,
        updatedAt: now,
      );
      return;
    }

    final db = await _db;
    await db.update(
      'alunos',
      {
        'tag_atual_uid': tagUid,
        'tags_antigas': jsonEncode(tagsAntigasAtualizadas),
        'updated_at': now,
        'synced': 0,
      },
      where: 'uid = ?',
      whereArgs: [aluno.uid],
    );
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
    if (_isSandboxMode) {
      final aluno = _sandboxAlunos[alunoUid];
      if (aluno == null) throw StateError('Aluno com UID $alunoUid não encontrado.');

      final saldoAtual = aluno.saldoTalentos;
      final novoSaldo = saldoAtual + quantidade;
      if (novoSaldo < 0) {
        throw SaldoInsuficienteException(
          alunoUid: alunoUid,
          saldoAtual: saldoAtual,
          totalNecessario: quantidade.abs(),
        );
      }

      final now = _nowIso();
      _sandboxAlunos[alunoUid] = aluno.copyWith(
        saldoTalentos: novoSaldo,
        updatedAt: now,
      );

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
      _sandboxTransacoes.insert(0, transacao);

      return novoSaldo;
    }

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

    if (_isSandboxMode) {
      final aluno = _sandboxAlunos[alunoUid];
      if (aluno == null) throw StateError('Aluno com UID $alunoUid não encontrado.');

      final saldoAtual = aluno.saldoTalentos;
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

      _sandboxAlunos[alunoUid] = aluno.copyWith(
        saldoTalentos: novoSaldo,
        updatedAt: now,
      );

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
      _sandboxTransacoes.insert(0, transacao);

      final venda = VendaModel(
        id: vendaId,
        alunoUid: alunoUid,
        totalTalentos: totalTalentos,
        createdAt: now,
        synced: false,
      );
      _sandboxVendas.insert(0, venda);

      for (final item in itens) {
        if (item.produtoId != null && _sandboxProdutos.containsKey(item.produtoId)) {
          final prod = _sandboxProdutos[item.produtoId]!;
          final novoEstoque = (prod.estoque - item.quantidade).clamp(0, 999999);
          _sandboxProdutos[item.produtoId!] = prod.copyWith(
            estoque: novoEstoque,
            esgotado: novoEstoque == 0,
            updatedAt: now,
          );
        }
      }

      return vendaId;
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
    if (_isSandboxMode) {
      final novoId = produto.id ?? (_sandboxProdutos.length + 1);
      final p = produto.copyWith(id: novoId);
      _sandboxProdutos[novoId] = p;
      return novoId;
    }

    final db = await _db;
    return await db.insert('produtos', produto.toMap());
  }

  Future<List<ProdutoModel>> listarProdutos({bool apenasDisponiveis = true}) async {
    if (_isSandboxMode) {
      var list = _sandboxProdutos.values.toList();
      if (apenasDisponiveis) {
        list = list.where((p) => !p.esgotado && p.estoque > 0).toList();
      }
      list.sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
      return list;
    }

    final db = await _db;
    final results = await db.query(
      'produtos',
      where: apenasDisponiveis ? 'esgotado = 0' : null,
      orderBy: 'nome ASC',
    );
    return results.map((e) => ProdutoModel.fromMap(e)).toList();
  }

  Future<void> alternarStatusEsgotado(int produtoId, bool esgotado) async {
    if (_isSandboxMode) {
      final p = _sandboxProdutos[produtoId];
      if (p != null) {
        _sandboxProdutos[produtoId] = p.copyWith(esgotado: esgotado, updatedAt: _nowIso());
      }
      return;
    }

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
    if (_isSandboxMode) {
      final list = _sandboxTransacoes
          .where((t) => t.alunoUid == alunoUid)
          .take(limit)
          .toList();
      return list;
    }

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
