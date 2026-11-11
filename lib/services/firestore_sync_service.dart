import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/talentos_repository.dart';
import '../firebase_options.dart';

class SyncResult {
  final bool sucesso;
  final bool offline;
  final String mensagem;
  final int alunosEnviados;
  final int produtosEnviados;
  final int transacoesEnviadas;
  final int vendasEnviadas;
  final int registrosRecebidos;

  const SyncResult({
    required this.sucesso,
    this.offline = false,
    required this.mensagem,
    this.alunosEnviados = 0,
    this.produtosEnviados = 0,
    this.transacoesEnviadas = 0,
    this.vendasEnviadas = 0,
    this.registrosRecebidos = 0,
  });

  factory SyncResult.offline([String mensagem = 'Sem conexão com a nuvem Firebase ou Firestore inacessível.']) {
    return SyncResult(
      sucesso: false,
      offline: true,
      mensagem: mensagem,
    );
  }

  factory SyncResult.erro(String erro) {
    return SyncResult(
      sucesso: false,
      offline: false,
      mensagem: erro,
    );
  }

  int get totalEnviados =>
      alunosEnviados + produtosEnviados + transacoesEnviadas + vendasEnviadas;
}

class FirestoreSyncService {
  static const String _lastSyncKey = 'firestore_last_sync_time';

  final SharedPreferences _prefs;
  static bool _firebaseIniciado = false;

  FirestoreSyncService(this._prefs);

  static Future<FirestoreSyncService> getInstance() async {
    final prefs = await SharedPreferences.getInstance();
    await _garantirFirebase();
    return FirestoreSyncService(prefs);
  }

  static Future<void> _garantirFirebase() async {
    if (_firebaseIniciado) return;
    try {
      if (Firebase.apps.isEmpty) {
        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.linux) {
          // Linux desktop local não tem suporte nativo ao SDK C++ do Firestore
          return;
        }
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      _firebaseIniciado = true;
    } catch (e) {
      debugPrint('Firebase init aviso/erro: $e');
    }
  }

  String? get ultimaSincronizacao => _prefs.getString(_lastSyncKey);

  bool get isPlataformaSuportada {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.linux) {
      return false;
    }
    return true;
  }

  /// Testa se a conexão com o Firestore está operacional
  Future<bool> testarConexao() async {
    if (!isPlataformaSuportada) return false;
    await _garantirFirebase();
    try {
      final db = FirebaseFirestore.instance;
      await db.collection('alunos').limit(1).get(const GetOptions(source: Source.server)).timeout(
        const Duration(seconds: 5),
      );
      return true;
    } catch (e) {
      debugPrint('Firestore testarConexao: $e');
      return false;
    }
  }

  /// Executa o ciclo de sincronização entre o SQLite Local e o Firestore
  Future<SyncResult> sincronizarTudo(TalentosRepository repo) async {
    if (!isPlataformaSuportada) {
      return SyncResult.offline(
        'Ambiente Linux Desktop utiliza armazenamento SQLite local nativo.',
      );
    }

    await _garantirFirebase();
    if (Firebase.apps.isEmpty) {
      return SyncResult.erro('Firebase não inicializado nesta plataforma.');
    }

    try {
      final db = FirebaseFirestore.instance;

      int alunosEnviados = 0;
      int produtosEnviados = 0;
      int transacoesEnviadas = 0;
      int vendasEnviadas = 0;
      int registrosRecebidos = 0;

      // ------------------------------------------
      // 1. PUSH: SQLite -> Firestore
      // ------------------------------------------
      final alunosPendentes = await repo.obterAlunosPendentes();
      if (alunosPendentes.isNotEmpty) {
        final batch = db.batch();
        for (final a in alunosPendentes) {
          final uid = a['uid'] as String;
          final map = Map<String, dynamic>.from(a);
          map.remove('synced');
          batch.set(db.collection('alunos').doc(uid), map, SetOptions(merge: true));
        }
        await batch.commit();
        await repo.marcarAlunosSincronizados(alunosPendentes.map((a) => a['uid'] as String).toList());
        alunosEnviados = alunosPendentes.length;
      }

      final produtosPendentes = await repo.obterProdutosPendentes();
      if (produtosPendentes.isNotEmpty) {
        final batch = db.batch();
        for (final p in produtosPendentes) {
          final id = (p['id'] as num).toInt();
          final map = Map<String, dynamic>.from(p);
          map.remove('synced');
          batch.set(db.collection('produtos').doc(id.toString()), map, SetOptions(merge: true));
        }
        await batch.commit();
        await repo.marcarProdutosSincronizados(produtosPendentes.map((p) => (p['id'] as num).toInt()).toList());
        produtosEnviados = produtosPendentes.length;
      }

      final transacoesPendentes = await repo.obterTransacoesPendentes();
      if (transacoesPendentes.isNotEmpty) {
        final batch = db.batch();
        for (final t in transacoesPendentes) {
          final id = t['id'] as String;
          final map = Map<String, dynamic>.from(t);
          map.remove('synced');
          batch.set(db.collection('transacoes_saldo').doc(id), map, SetOptions(merge: true));
        }
        await batch.commit();
        await repo.marcarTransacoesSincronizadas(transacoesPendentes.map((t) => t['id'] as String).toList());
        transacoesEnviadas = transacoesPendentes.length;
      }

      final vendasPendentes = await repo.obterVendasPendentes();
      if (vendasPendentes.isNotEmpty) {
        final batch = db.batch();
        for (final v in vendasPendentes) {
          final id = v['id'] as String;
          final map = Map<String, dynamic>.from(v);
          map.remove('synced');
          final itens = await repo.obterItensVenda(id);
          map['itens'] = itens;
          batch.set(db.collection('vendas').doc(id), map, SetOptions(merge: true));
        }
        await batch.commit();
        await repo.marcarVendasSincronizadas(vendasPendentes.map((v) => v['id'] as String).toList());
        vendasEnviadas = vendasPendentes.length;
      }

      // ------------------------------------------
      // 2. PULL: Firestore -> SQLite
      // ------------------------------------------
      try {
        final alunosSnap = await db.collection('alunos').get();
        final mapAlunos = alunosSnap.docs.map((d) => d.data()).toList();
        registrosRecebidos += await repo.mesclarAlunosRemotos(mapAlunos);
      } catch (e) {
        debugPrint('Erro ao baixar alunos Firestore: $e');
      }

      try {
        final produtosSnap = await db.collection('produtos').get();
        final mapProdutos = produtosSnap.docs.map((d) => d.data()).toList();
        registrosRecebidos += await repo.mesclarProdutosRemotos(mapProdutos);
      } catch (e) {
        debugPrint('Erro ao baixar produtos Firestore: $e');
      }

      final nowIso = DateTime.now().toIso8601String();
      await _prefs.setString(_lastSyncKey, nowIso);

      return SyncResult(
        sucesso: true,
        offline: false,
        mensagem: 'Sincronização com Firebase concluída com sucesso!',
        alunosEnviados: alunosEnviados,
        produtosEnviados: produtosEnviados,
        transacoesEnviadas: transacoesEnviadas,
        vendasEnviadas: vendasEnviadas,
        registrosRecebidos: registrosRecebidos,
      );
    } catch (e, stack) {
      debugPrint('Erro sincronizar Firestore: $e\n$stack');
      return SyncResult.erro('Falha durante a sincronização com Firebase: $e');
    }
  }
}
