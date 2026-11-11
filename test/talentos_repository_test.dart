import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:talento_digital/database/app_database.dart';
import 'package:talento_digital/database/models.dart';
import 'package:talento_digital/database/talentos_repository.dart';

class TestAppDatabase extends AppDatabase {
  final Database _customDb;
  TestAppDatabase(this._customDb);

  @override
  Future<Database> get database async => _customDb;
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;
  late TalentosRepository repo;

  setUp(() async {
    // Banco SQLite in-memory para testes isolados
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE alunos (
              uid TEXT PRIMARY KEY,
              tag_atual_uid TEXT,
              tags_antigas TEXT,
              avatar_id TEXT,
              foto_base64 TEXT,
              nome TEXT NOT NULL,
              turma TEXT,
              saldo_talentos INTEGER NOT NULL DEFAULT 0,
              ativo INTEGER NOT NULL DEFAULT 1,
              updated_at TEXT NOT NULL,
              synced INTEGER NOT NULL DEFAULT 0
            )
          ''');

          await db.execute('''
            CREATE TABLE produtos (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              icone_id TEXT,
              foto_base64 TEXT,
              nome TEXT NOT NULL,
              valor_talentos INTEGER NOT NULL,
              estoque INTEGER NOT NULL DEFAULT 0,
              esgotado INTEGER NOT NULL DEFAULT 0,
              updated_at TEXT NOT NULL,
              synced INTEGER NOT NULL DEFAULT 0
            )
          ''');

          await db.execute('''
            CREATE TABLE transacoes_saldo (
              id TEXT PRIMARY KEY,
              aluno_uid TEXT NOT NULL,
              tipo TEXT NOT NULL,
              quantidade INTEGER NOT NULL,
              motivo TEXT NOT NULL,
              operador TEXT NOT NULL DEFAULT 'Professor',
              created_at TEXT NOT NULL,
              synced INTEGER NOT NULL DEFAULT 0,
              FOREIGN KEY (aluno_uid) REFERENCES alunos(uid) ON DELETE CASCADE
            )
          ''');

          await db.execute('''
            CREATE TABLE vendas (
              id TEXT PRIMARY KEY,
              aluno_uid TEXT NOT NULL,
              total_talentos INTEGER NOT NULL,
              created_at TEXT NOT NULL,
              synced INTEGER NOT NULL DEFAULT 0,
              FOREIGN KEY (aluno_uid) REFERENCES alunos(uid) ON DELETE CASCADE
            )
          ''');

          await db.execute('''
            CREATE TABLE venda_itens (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              venda_id TEXT NOT NULL,
              produto_id INTEGER,
              descricao_livre TEXT,
              quantidade INTEGER NOT NULL,
              preco_unitario INTEGER NOT NULL,
              FOREIGN KEY (venda_id) REFERENCES vendas(id) ON DELETE CASCADE,
              FOREIGN KEY (produto_id) REFERENCES produtos(id) ON DELETE SET NULL
            )
          ''');
        },
      ),
    );

    repo = TalentosRepository(TestAppDatabase(db));
  });

  tearDown(() async {
    await db.close();
  });

  group('TalentosRepository - Alunos', () {
    test('buscarOuCadastrarAluno cria novo aluno com saldo 0', () async {
      final aluno = await repo.buscarOuCadastrarAluno('041693AB8A2681', nomePadrao: 'Lucas');
      expect(aluno.uid, '041693AB8A2681');
      expect(aluno.nome, 'Lucas');
      expect(aluno.saldoTalentos, 0);

      final buscado = await repo.buscarAlunoPorUid('041693AB8A2681');
      expect(buscado, isNotNull);
      expect(buscado!.nome, 'Lucas');
    });

    test('atualizarNomeAluno altera o nome e atualiza synced para 0', () async {
      await repo.buscarOuCadastrarAluno('TAG1', nomePadrao: 'Aluno Antigo');
      await repo.atualizarNomeAluno('TAG1', 'Aluno Novo');

      final atualizado = await repo.buscarAlunoPorUid('TAG1');
      expect(atualizado!.nome, 'Aluno Novo');
      expect(atualizado.synced, isFalse);
    });
  });

  group('TalentosRepository - Transações de Saldo', () {
    test('adicionarTalentos incrementa saldo e cria registro em transacoes_saldo', () async {
      await repo.buscarOuCadastrarAluno('TAG_SALDO', nomePadrao: 'Teste');

      final novoSaldo = await repo.adicionarTalentos(
        alunoUid: 'TAG_SALDO',
        quantidade: 10,
        motivo: 'Presença na Escola Sabatina',
        operador: 'Tia Ana',
      );

      expect(novoSaldo, 10);
      final aluno = await repo.buscarAlunoPorUid('TAG_SALDO');
      expect(aluno!.saldoTalentos, 10);

      final transacoes = await repo.listarTransacoesDoAluno('TAG_SALDO');
      expect(transacoes.length, 1);
      expect(transacoes.first.tipo, 'ENTRADA');
      expect(transacoes.first.quantidade, 10);
      expect(transacoes.first.motivo, 'Presença na Escola Sabatina');
      expect(transacoes.first.operador, 'Tia Ana');
    });

    test('adicionarTalentos com quantidade negativa (dedução) funciona se houver saldo', () async {
      await repo.buscarOuCadastrarAluno('TAG_SALDO_2', nomePadrao: 'Teste');
      await repo.adicionarTalentos(alunoUid: 'TAG_SALDO_2', quantidade: 15, motivo: 'Bonus');

      final saldoFinal = await repo.adicionarTalentos(
        alunoUid: 'TAG_SALDO_2',
        quantidade: -5,
        motivo: 'Ajuste manual',
      );

      expect(saldoFinal, 10);
      final aluno = await repo.buscarAlunoPorUid('TAG_SALDO_2');
      expect(aluno!.saldoTalentos, 10);
    });

    test('adicionarTalentos lanca SaldoInsuficienteException se saldo ficar negativo', () async {
      await repo.buscarOuCadastrarAluno('TAG_POBRE', nomePadrao: 'Sem Saldo');

      expect(
        () => repo.adicionarTalentos(alunoUid: 'TAG_POBRE', quantidade: -5, motivo: 'Tentativa indevida'),
        throwsA(isA<SaldoInsuficienteException>()),
      );

      final aluno = await repo.buscarAlunoPorUid('TAG_POBRE');
      expect(aluno!.saldoTalentos, 0); // Permanece intacto
    });
  });

  group('TalentosRepository - Vendas e Produtos', () {
    test('processarVenda bem-sucedida debita saldo, grava venda, itens e deduz estoque', () async {
      await repo.buscarOuCadastrarAluno('TAG_COMPRA', nomePadrao: 'Comprador');
      await repo.adicionarTalentos(alunoUid: 'TAG_COMPRA', quantidade: 20, motivo: 'Carga inicial');

      final prodId = await repo.criarProduto(ProdutoModel(
        nome: 'Livrinho Bíblico',
        valorTalentos: 5,
        estoque: 10,
        updatedAt: DateTime.now().toIso8601String(),
      ));

      final vendaId = await repo.processarVenda(
        alunoUid: 'TAG_COMPRA',
        itens: [
          ItemVendaDto(produtoId: prodId, quantidade: 2, precoUnitario: 5),
          ItemVendaDto(descricaoLivre: 'Doce avulso', quantidade: 1, precoUnitario: 2),
        ],
        totalTalentos: 12,
      );

      expect(vendaId, isNotEmpty);

      // Verifica saldo do aluno (20 - 12 = 8)
      final aluno = await repo.buscarAlunoPorUid('TAG_COMPRA');
      expect(aluno!.saldoTalentos, 8);

      // Verifica estoque do produto (10 - 2 = 8)
      final produtos = await repo.listarProdutos();
      final produtoAtualizado = produtos.firstWhere((p) => p.id == prodId);
      expect(produtoAtualizado.estoque, 8);
      expect(produtoAtualizado.esgotado, isFalse);

      // Verifica registro na tabela de vendas
      final rawVendas = await db.query('vendas', where: 'id = ?', whereArgs: [vendaId]);
      expect(rawVendas.length, 1);
      expect(rawVendas.first['total_talentos'], 12);

      // Verifica itens gravados
      final rawItens = await db.query('venda_itens', where: 'venda_id = ?', whereArgs: [vendaId]);
      expect(rawItens.length, 2);
    });

    test('processarVenda aborta atômica e lanca SaldoInsuficienteException se saldo < total', () async {
      await repo.buscarOuCadastrarAluno('TAG_POBRE_VENDA', nomePadrao: 'Aluno');
      await repo.adicionarTalentos(alunoUid: 'TAG_POBRE_VENDA', quantidade: 5, motivo: 'Pouco saldo');

      final prodId = await repo.criarProduto(ProdutoModel(
        nome: 'Bíblia Ilustrada',
        valorTalentos: 30,
        estoque: 5,
        updatedAt: DateTime.now().toIso8601String(),
      ));

      expect(
        () => repo.processarVenda(
          alunoUid: 'TAG_POBRE_VENDA',
          itens: [
            ItemVendaDto(produtoId: prodId, quantidade: 1, precoUnitario: 30),
          ],
          totalTalentos: 30,
        ),
        throwsA(isA<SaldoInsuficienteException>()),
      );

      // Saldo do aluno não foi alterado
      final aluno = await repo.buscarAlunoPorUid('TAG_POBRE_VENDA');
      expect(aluno!.saldoTalentos, 5);

      // Estoque do produto não foi reduzido (Rollback atômico)
      final produtos = await repo.listarProdutos();
      final produto = produtos.firstWhere((p) => p.id == prodId);
      expect(produto.estoque, 5);

      // Nenhuma venda gravada
      final vendas = await db.query('vendas');
      expect(vendas, isEmpty);
    });
    test('BuscaTagResult identifica tag ativa, extraviada e não cadastrada', () async {
      await repo.cadastrarAluno(AlunoModel(
        uid: 'ALUNO_1',
        tagAtualUid: 'TAG_NOVA',
        tagsAntigas: ['TAG_ANTIGA_1', 'TAG_ANTIGA_2'],
        nome: 'Pedrinho',
        saldoTalentos: 10,
        updatedAt: DateTime.now().toIso8601String(),
      ));

      // 1. Tag ativa
      final resAtivo = await repo.buscarAlunoPorTag('TAG_NOVA');
      expect(resAtivo, isA<BuscaTagResultEncontradoAtivo>());
      expect((resAtivo as BuscaTagResultEncontradoAtivo).aluno.nome, equals('Pedrinho'));

      // 2. Tag antiga (extraviada)
      final resExtraviado = await repo.buscarAlunoPorTag('TAG_ANTIGA_1');
      expect(resExtraviado, isA<BuscaTagResultEncontradoExtraviado>());
      expect((resExtraviado as BuscaTagResultEncontradoExtraviado).antigoDono.nome, equals('Pedrinho'));

      // 3. Tag nunca cadastrada
      final resNaoCadastrado = await repo.buscarAlunoPorTag('TAG_DESCONHECIDA');
      expect(resNaoCadastrado, isA<BuscaTagResultNaoCadastrado>());
    });

    test('vincularTagAoAluno arquiva a tag anterior em tags_antigas', () async {
      final aluno = await repo.buscarOuCadastrarAluno('TAG_INICIAL', nomePadrao: 'Aninha');
      expect(aluno.tagAtualUid, equals('TAG_INICIAL'));
      expect(aluno.tagsAntigas, isEmpty);

      // Vincula nova tag física
      await repo.vincularTagAoAluno(uidAntigo: aluno.uid, novoUidTag: 'TAG_SEGUNDA');

      final atualizado = await repo.buscarAlunoPorUid('TAG_SEGUNDA');
      expect(atualizado, isNotNull);
      expect(atualizado!.tagAtualUid, equals('TAG_SEGUNDA'));
      expect(atualizado.tagsAntigas, contains('TAG_INICIAL'));

      // Reativa tag antiga
      await repo.reativarTagAntiga(alunoUid: atualizado.uid, tagUid: 'TAG_INICIAL');
      final reativado = await repo.buscarAlunoPorUid('TAG_INICIAL');
      expect(reativado, isNotNull);
      expect(reativado!.tagAtualUid, equals('TAG_INICIAL'));
      expect(reativado.tagsAntigas, contains('TAG_SEGUNDA'));
    });

    test('Modo Sandbox opera 100% isolado em memória com dados de demonstração', () async {
      repo.setSandboxMode(true);
      expect(repo.isSandboxMode, isTrue);

      final alunos = await repo.listarAlunos();
      expect(alunos.length, equals(5));

      final produtos = await repo.listarProdutos();
      expect(produtos.length, equals(6));

      // Teste de movimentação no sandbox
      final saldoFinal = await repo.adicionarTalentos(
        alunoUid: 'DEMO_1',
        quantidade: 10,
        motivo: 'Presença no Sandbox',
      );
      expect(saldoFinal, equals(55));

      final alunoAtualizado = await repo.buscarAlunoPorUid('DEMO_1');
      expect(alunoAtualizado?.saldoTalentos, equals(55));
    });
    test('Edge case: resiliência no fromMap com dados legados e tags nulas/corrompidas', () {
      final mapaLegado = {
        'uid': '04A1B2C3',
        'nome': 'Criança Sem Tag Nova',
        'saldo_talentos': '50', // string no lugar de num
        'ativo': 1,
        'tag_atual_uid': null,
        'tags_antigas': null,
      };

      final aluno = AlunoModel.fromMap(mapaLegado);
      expect(aluno.uid, equals('04A1B2C3'));
      expect(aluno.tagAtualUid, equals('04A1B2C3')); // fallback para uid
      expect(aluno.tagsAntigas, isEmpty);
      expect(aluno.saldoTalentos, equals(50));
    });

    test('Edge case: reativação de tag sem ciclo infinito e dedução atômica no limite exato de saldo', () async {
      await repo.cadastrarAluno(AlunoModel(
        uid: 'ALUNO_EXATO',
        tagAtualUid: 'TAG_1',
        nome: 'João',
        saldoTalentos: 15,
        updatedAt: DateTime.now().toIso8601String(),
      ));

      // Vincula TAG_2 e depois TAG_3
      await repo.vincularTagAoAluno(uidAntigo: 'ALUNO_EXATO', novoUidTag: 'TAG_2');
      await repo.vincularTagAoAluno(uidAntigo: 'ALUNO_EXATO', novoUidTag: 'TAG_3');

      final alunoHistorico = await repo.buscarAlunoPorUid('TAG_3');
      expect(alunoHistorico!.tagsAntigas, containsAll(['TAG_1', 'TAG_2']));

      // Reativa TAG_1 (TAG_3 deve ir para tags antigas, e TAG_1 não pode ficar duplicada)
      await repo.reativarTagAntiga(alunoUid: 'ALUNO_EXATO', tagUid: 'TAG_1');
      final reativado = await repo.buscarAlunoPorUid('TAG_1');
      expect(reativado!.tagAtualUid, equals('TAG_1'));
      expect(reativado.tagsAntigas, containsAll(['TAG_2', 'TAG_3']));
      expect(reativado.tagsAntigas.where((t) => t == 'TAG_1'), isEmpty);

      // Dedução atômica no limite exato de saldo (15 - 15 = 0 deve passar)
      final saldoRestante = await repo.adicionarTalentos(
        alunoUid: 'ALUNO_EXATO',
        quantidade: -15,
        motivo: 'Gasto total',
      );
      expect(saldoRestante, equals(0));

      // Dedução de mais 1 com saldo 0 deve falhar com SaldoInsuficienteException
      expect(
        () => repo.adicionarTalentos(
          alunoUid: 'ALUNO_EXATO',
          quantidade: -1,
          motivo: 'Tentativa de saldo negativo',
        ),
        throwsA(isA<SaldoInsuficienteException>()),
      );
    });
  });
}
