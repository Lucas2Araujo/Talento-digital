import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database/talentos_repository.dart';

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

  factory SyncResult.offline([String mensagem = 'Sem conexão com a internet ou Supabase inacessível.']) {
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

class SupabaseSyncService {
  static const String _urlKey = 'supabase_config_url';
  static const String _anonKey = 'supabase_config_anon_key';
  static const String _lastSyncKey = 'supabase_last_sync_time';

  // Fallback para ambiente de desenvolvimento caso o usuário ainda não tenha configurado no app
  static const String fallbackUrl = 'https://xyzcompany.supabase.co';
  static const String fallbackAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.dummy';

  final SharedPreferences _prefs;
  SupabaseClient? _client;

  SupabaseSyncService(this._prefs);

  static Future<SupabaseSyncService> getInstance() async {
    final prefs = await SharedPreferences.getInstance();
    return SupabaseSyncService(prefs);
  }

  String get supabaseUrl => _prefs.getString(_urlKey) ?? '';
  String get supabaseAnonKey => _prefs.getString(_anonKey) ?? '';
  String? get ultimaSincronizacao => _prefs.getString(_lastSyncKey);

  bool get estaConfigurado =>
      supabaseUrl.trim().isNotEmpty && supabaseAnonKey.trim().isNotEmpty;

  Future<void> salvarConfiguracoes({
    required String url,
    required String anonKey,
  }) async {
    await _prefs.setString(_urlKey, url.trim());
    await _prefs.setString(_anonKey, anonKey.trim());
    _client = null; // Reinicia o cliente com as novas credenciais
  }

  SupabaseClient? _obterCliente() {
    if (!estaConfigurado) return null;
    _client ??= SupabaseClient(supabaseUrl, supabaseAnonKey);
    return _client;
  }

  /// Testa se a conexão com o Supabase está operacional com timeout rápido
  Future<bool> testarConexao() async {
    final client = _obterCliente();
    if (client == null) return false;

    try {
      // Faz um select limit(1) leve com timeout de 5 segundos
      await client.from('alunos').select('uid').limit(1).timeout(
            const Duration(seconds: 5),
          );
      return true;
    } catch (e) {
      debugPrint('Supabase testarConexao: $e');
      return false;
    }
  }

  /// Executa o ciclo completo de sincronização Híbrida Local-First
  Future<SyncResult> sincronizarTudo(TalentosRepository repo) async {
    final client = _obterCliente();
    if (client == null) {
      return SyncResult.erro(
        'Supabase não configurado. Acesse as configurações e informe a URL e a Anon Key.',
      );
    }

    try {
      // 1. Verificação prévia de conectividade
      final conectado = await testarConexao();
      if (!conectado) {
        return SyncResult.offline(
          'Supabase inacessível ou sem conexão no momento. Seus dados continuam salvos com segurança localmente.',
        );
      }

      int alunosEnviados = 0;
      int produtosEnviados = 0;
      int transacoesEnviadas = 0;
      int vendasEnviadas = 0;
      int registrosRecebidos = 0;

      // ==========================================
      // FASE PUSH: SQLite -> Supabase
      // ==========================================

      // 1. Envia Alunos Pendentes
      final alunosPendentes = await repo.obterAlunosPendentes();
      if (alunosPendentes.isNotEmpty) {
        final payload = alunosPendentes.map((a) {
          final map = Map<String, dynamic>.from(a);
          map.remove('synced');
          return map;
        }).toList();

        await client.from('alunos').upsert(payload);
        final uids = alunosPendentes.map((a) => a['uid'] as String).toList();
        await repo.marcarAlunosSincronizados(uids);
        alunosEnviados = alunosPendentes.length;
      }

      // 2. Envia Produtos Pendentes
      final produtosPendentes = await repo.obterProdutosPendentes();
      if (produtosPendentes.isNotEmpty) {
        final payload = produtosPendentes.map((p) {
          final map = Map<String, dynamic>.from(p);
          map.remove('synced');
          return map;
        }).toList();

        await client.from('produtos').upsert(payload);
        final ids = produtosPendentes.map((p) => (p['id'] as num).toInt()).toList();
        await repo.marcarProdutosSincronizados(ids);
        produtosEnviados = produtosPendentes.length;
      }

      // 3. Envia Transações de Saldo Pendentes
      final transacoesPendentes = await repo.obterTransacoesPendentes();
      if (transacoesPendentes.isNotEmpty) {
        final payload = transacoesPendentes.map((t) {
          final map = Map<String, dynamic>.from(t);
          map.remove('synced');
          return map;
        }).toList();

        await client.from('transacoes_saldo').upsert(payload);
        final ids = transacoesPendentes.map((t) => t['id'] as String).toList();
        await repo.marcarTransacoesSincronizadas(ids);
        transacoesEnviadas = transacoesPendentes.length;
      }

      // 4. Envia Vendas Pendentes e seus Itens
      final vendasPendentes = await repo.obterVendasPendentes();
      if (vendasPendentes.isNotEmpty) {
        final payloadVendas = vendasPendentes.map((v) {
          final map = Map<String, dynamic>.from(v);
          map.remove('synced');
          return map;
        }).toList();

        await client.from('vendas').upsert(payloadVendas);

        // Envia os itens correspondentes a cada venda
        for (final venda in vendasPendentes) {
          final vendaId = venda['id'] as String;
          final itens = await repo.obterItensVenda(vendaId);
          if (itens.isNotEmpty) {
            final payloadItens = itens.map((item) {
              final map = Map<String, dynamic>.from(item);
              map.remove('id'); // Deixa o Postgres gerar ou manter compatível
              return map;
            }).toList();
            await client.from('venda_itens').upsert(payloadItens);
          }
        }

        final idsVendas = vendasPendentes.map((v) => v['id'] as String).toList();
        await repo.marcarVendasSincronizadas(idsVendas);
        vendasEnviadas = vendasPendentes.length;
      }

      // ==========================================
      // FASE PULL: Supabase -> SQLite
      // ==========================================

      // 1. Baixa Alunos do Supabase
      try {
        final List<dynamic> alunosRemotos = await client.from('alunos').select();
        final mapAlunos = alunosRemotos.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        final alunosAtualizados = await repo.mesclarAlunosRemotos(mapAlunos);
        registrosRecebidos += alunosAtualizados;
      } catch (e) {
        debugPrint('Aviso ao puxar alunos: $e');
      }

      // 2. Baixa Produtos do Supabase
      try {
        final List<dynamic> produtosRemotos = await client.from('produtos').select();
        final mapProdutos = produtosRemotos.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        final produtosAtualizados = await repo.mesclarProdutosRemotos(mapProdutos);
        registrosRecebidos += produtosAtualizados;
      } catch (e) {
        debugPrint('Aviso ao puxar produtos: $e');
      }

      // Atualiza timestamp da última sincronização
      final nowIso = DateTime.now().toIso8601String();
      await _prefs.setString(_lastSyncKey, nowIso);

      return SyncResult(
        sucesso: true,
        offline: false,
        mensagem: 'Sincronização concluída com sucesso!',
        alunosEnviados: alunosEnviados,
        produtosEnviados: produtosEnviados,
        transacoesEnviadas: transacoesEnviadas,
        vendasEnviadas: vendasEnviadas,
        registrosRecebidos: registrosRecebidos,
      );
    } catch (e, stack) {
      debugPrint('Erro em sincronizarTudo: $e\n$stack');
      return SyncResult.erro('Falha durante a sincronização: $e');
    }
  }
}
