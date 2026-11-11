import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'platform_io_helper.dart';

class AppDatabase {
  static const String _dbName = 'talentos_igreja.db';
  static const int _dbVersion = 1;

  Database? _db;
  Future<Database>? _initFuture;

  Future<Database> get database async {
    if (_db != null && _db!.isOpen) return _db!;
    _initFuture ??= _initDatabase();
    try {
      _db = await _initFuture!;
      return _db!;
    } catch (e) {
      _initFuture = null;
      rethrow;
    }
  }

  /// Inicializa o driver FFI correspondente à plataforma (Web ou Desktop)
  static void setupPlatformDriver() {
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWebNoWebWorker;
    } else if (defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  }

  Future<Database> _initDatabase() async {
    setupPlatformDriver();

    String fullPath;

    if (kIsWeb) {
      // No Web, o sqflite_common_ffi_web persiste os dados via IndexedDB no navegador
      fullPath = _dbName;
    } else {
      String dbDirectory;
      if (defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS) {
        final appSupportDir = await getApplicationSupportDirectory();
        dbDirectory = appSupportDir.path;
      } else {
        dbDirectory = await getDatabasesPath();
      }

      // Garante que o diretório exista no disco Desktop/Mobile
      ensureDirectoryExists(dbDirectory);
      fullPath = p.join(dbDirectory, _dbName);
    }

    return await databaseFactory.openDatabase(
      fullPath,
      options: OpenDatabaseOptions(
        version: _dbVersion,
        onConfigure: (db) async {
          // No Web (Wasm), PRAGMA foreign_keys pode emitir aviso ou falhar; habilitamos apenas fora da Web
          if (!kIsWeb) {
            await db.execute('PRAGMA foreign_keys = ON');
          }
        },
        onCreate: (db, version) async {
          await _createTables(db);
        },
        onOpen: (db) async {
          // Garante que todas as tabelas existam mesmo se o banco já foi inicializado anteriormente
          await _createTables(db);
        },
      ),
    );
  }

  static Future<void> _createTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS alunos (
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
      CREATE TABLE IF NOT EXISTS produtos (
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
      CREATE TABLE IF NOT EXISTS transacoes_saldo (
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
      CREATE TABLE IF NOT EXISTS vendas (
        id TEXT PRIMARY KEY,
        aluno_uid TEXT NOT NULL,
        total_talentos INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (aluno_uid) REFERENCES alunos(uid) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS venda_itens (
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
  }

  Future<void> close() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
      _db = null;
    }
  }
}
