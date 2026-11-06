import 'package:flutter/material.dart';
import '../database/talentos_repository.dart';
import '../services/supabase_sync_service.dart';
import '../widgets/pin_auth_dialog.dart';

class AdminPainelDialog extends StatefulWidget {
  final TalentosRepository repository;
  final VoidCallback? onDadosAtualizados;

  const AdminPainelDialog({
    super.key,
    required this.repository,
    this.onDadosAtualizados,
  });

  static Future<void> show(
    BuildContext context, {
    required TalentosRepository repository,
    VoidCallback? onDadosAtualizados,
  }) async {
    // Exige autenticação por PIN antes de abrir
    final autorizado = await PinAuthDialog.solicitarPin(
      context,
      titulo: 'Painel Administrativo',
      subtitulo: 'Digite o PIN para acessar a sincronização e ajustes',
    );

    if (autorizado && context.mounted) {
      await showDialog(
        context: context,
        builder: (_) => AdminPainelDialog(
          repository: repository,
          onDadosAtualizados: onDadosAtualizados,
        ),
      );
    }
  }

  @override
  State<AdminPainelDialog> createState() => _AdminPainelDialogState();
}

class _AdminPainelDialogState extends State<AdminPainelDialog> {
  SupabaseSyncService? _syncService;
  int _pendentes = 0;
  bool _conectado = false;
  bool _testandoConexao = true;
  bool _sincronizando = false;
  SyncResult? _ultimoResultado;

  final _urlController = TextEditingController();
  final _anonKeyController = TextEditingController();
  bool _editandoCredenciais = false;

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _anonKeyController.dispose();
    super.dispose();
  }

  Future<void> _inicializar() async {
    final service = await SupabaseSyncService.getInstance();
    final totalPendentes = await widget.repository.contarTotalPendentesSincronizacao();

    _urlController.text = service.supabaseUrl;
    _anonKeyController.text = service.supabaseAnonKey;

    if (mounted) {
      setState(() {
        _syncService = service;
        _pendentes = totalPendentes;
      });
    }

    await _verificarConexao();
  }

  Future<void> _verificarConexao() async {
    if (_syncService == null) return;
    setState(() => _testandoConexao = true);

    final ok = await _syncService!.testarConexao();
    final totalPendentes = await widget.repository.contarTotalPendentesSincronizacao();

    if (mounted) {
      setState(() {
        _conectado = ok;
        _pendentes = totalPendentes;
        _testandoConexao = false;
      });
    }
  }

  Future<void> _executarSincronizacao() async {
    if (_syncService == null || _sincronizando) return;

    setState(() {
      _sincronizando = true;
      _ultimoResultado = null;
    });

    final resultado = await _syncService!.sincronizarTudo(widget.repository);
    final totalPendentes = await widget.repository.contarTotalPendentesSincronizacao();

    if (mounted) {
      setState(() {
        _sincronizando = false;
        _ultimoResultado = resultado;
        _pendentes = totalPendentes;
        _conectado = resultado.sucesso;
      });

      widget.onDadosAtualizados?.call();
    }
  }

  Future<void> _salvarCredenciais() async {
    if (_syncService == null) return;
    await _syncService!.salvarConfiguracoes(
      url: _urlController.text.trim(),
      anonKey: _anonKeyController.text.trim(),
    );

    setState(() => _editandoCredenciais = false);
    await _verificarConexao();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Configurações do Supabase salvas com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  String _formatarDataHora(String? iso) {
    if (iso == null || iso.isEmpty) return 'Nunca sincronizado';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final dia = dt.day.toString().padLeft(2, '0');
      final mes = dt.month.toString().padLeft(2, '0');
      final hora = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      return '$dia/$mes/${dt.year} às $hora:$min';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cabeçalho
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.cloud_sync_rounded, color: Colors.amber, size: 26),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Painel de Sincronização & Gestão',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Arquitetura Local-First (Offline-First)',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 24),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Cartões de Status (Conexão + Pendentes)
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatusCard(
                              titulo: 'STATUS NUVEM',
                              conteudo: _testandoConexao
                                  ? 'Testando...'
                                  : (_conectado ? 'Conectado' : 'Offline / Inacessível'),
                              cor: _conectado ? Colors.greenAccent : Colors.grey,
                              icone: _conectado ? Icons.cloud_done : Icons.cloud_off,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatusCard(
                              titulo: 'PENDENTES (SQLITE)',
                              conteudo: '$_pendentes registro(s)',
                              cor: _pendentes > 0 ? Colors.orangeAccent : Colors.blueAccent,
                              icone: Icons.pending_actions,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Data da última sincronização
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF252525),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.access_time_rounded, size: 18, color: Colors.grey),
                            const SizedBox(width: 8),
                            const Text('Última Sincronização: ', style: TextStyle(color: Colors.grey, fontSize: 13)),
                            Expanded(
                              child: Text(
                                _formatarDataHora(_syncService?.ultimaSincronizacao),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Verificar conexão',
                              icon: const Icon(Icons.refresh, size: 18),
                              onPressed: _testandoConexao ? null : _verificarConexao,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Botão Principal: Sincronizar Agora
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.amber,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: (_sincronizando || _syncService == null) ? null : _executarSincronizacao,
                        icon: _sincronizando
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                              )
                            : const Icon(Icons.sync),
                        label: Text(
                          _sincronizando ? 'Sincronizando com Supabase...' : 'SINCRONIZAR AGORA',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 1),
                        ),
                      ),

                      // Banner do Resultado da Sincronização
                      if (_ultimoResultado != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: _ultimoResultado!.sucesso
                                ? Colors.green.shade900.withValues(alpha: 0.3)
                                : Colors.red.shade900.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _ultimoResultado!.sucesso ? Colors.greenAccent : Colors.redAccent,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    _ultimoResultado!.sucesso ? Icons.check_circle : Icons.error_outline,
                                    color: _ultimoResultado!.sucesso ? Colors.greenAccent : Colors.redAccent,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _ultimoResultado!.mensagem,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: _ultimoResultado!.sucesso ? Colors.greenAccent : Colors.redAccent,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (_ultimoResultado!.sucesso) ...[
                                const SizedBox(height: 8),
                                Text(
                                  '• Enviados para a nuvem: ${_ultimoResultado!.totalEnviados} '
                                  '(Alunos: ${_ultimoResultado!.alunosEnviados}, Produtos: ${_ultimoResultado!.produtosEnviados}, '
                                  'Transações: ${_ultimoResultado!.transacoesEnviadas}, Vendas: ${_ultimoResultado!.vendasEnviadas})\n'
                                  '• Baixados da nuvem: ${_ultimoResultado!.registrosRecebidos} registro(s)',
                                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 8),

                      // Configuração de Credenciais do Supabase
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.key_rounded, size: 18, color: Colors.amber),
                              SizedBox(width: 8),
                              Text('Credenciais Supabase', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            ],
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() => _editandoCredenciais = !_editandoCredenciais);
                            },
                            child: Text(_editandoCredenciais ? 'Ocultar' : 'Editar / Ver'),
                          ),
                        ],
                      ),

                      if (_editandoCredenciais) ...[
                        const SizedBox(height: 8),
                        TextField(
                          controller: _urlController,
                          decoration: const InputDecoration(
                            labelText: 'Supabase URL',
                            hintText: 'https://xyzcompany.supabase.co',
                            isDense: true,
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.link),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _anonKeyController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Supabase Anon Key',
                            isDense: true,
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.vpn_key),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.icon(
                            onPressed: _salvarCredenciais,
                            icon: const Icon(Icons.save),
                            label: const Text('Salvar Credenciais'),
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),

                      // Seção de Segurança: Alterar PIN
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFF282828),
                          child: Icon(Icons.pin, color: Colors.amber),
                        ),
                        title: const Text('PIN de Acesso Administrativo', style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: const Text('Altere a senha numérica de 4 dígitos', style: TextStyle(fontSize: 12)),
                        trailing: OutlinedButton(
                          onPressed: () {
                            PinAuthDialog.abrirAlteracaoDePin(context);
                          },
                          child: const Text('Alterar PIN'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard({
    required String titulo,
    required String conteudo,
    required Color cor,
    required IconData icone,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF252525),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                titulo,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                  color: Colors.grey.shade400,
                ),
              ),
              Icon(icone, color: cor, size: 18),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            conteudo,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: cor,
            ),
          ),
        ],
      ),
    );
  }
}
