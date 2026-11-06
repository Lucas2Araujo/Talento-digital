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
  });
}
