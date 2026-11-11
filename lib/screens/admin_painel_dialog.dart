import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../database/talentos_repository.dart';
import '../services/firestore_sync_service.dart';
import '../theme/adventure_theme.dart';
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
  FirestoreSyncService? _syncService;
  int _pendentes = 0;
  bool _conectado = false;
  bool _testandoConexao = true;
  bool _sincronizando = false;
  SyncResult? _ultimoResultado;

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  Future<void> _inicializar() async {
    final service = await FirestoreSyncService.getInstance();
    final totalPendentes = await widget.repository.contarTotalPendentesSincronizacao();

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AdventureTheme.darkSurface : AdventureTheme.surface;
    final cardBg = isDark ? AdventureTheme.darkSurfaceVariant : Colors.white;
    final textColor = isDark ? AdventureTheme.darkTextLight : AdventureTheme.textDark;
    final borderColor = isDark ? AdventureTheme.darkOutline : AdventureTheme.woodBrown;

    return Dialog(
      backgroundColor: bgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: borderColor, width: 2.5),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cabeçalho Estilo Stitch
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AdventureTheme.goldCoin,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AdventureTheme.goldDark, width: 2),
                    ),
                    child: const Icon(Icons.cloud_sync_rounded, color: AdventureTheme.woodDark, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sincronização & Gestão',
                          style: AdventureTheme.titleFredoka.copyWith(
                            fontSize: 18,
                            color: textColor,
                          ),
                        ),
                        Text(
                          'Google Cloud Firestore (Offline-First)',
                          style: AdventureTheme.bodyNunito.copyWith(
                            fontSize: 12,
                            color: isDark ? AdventureTheme.darkTextMuted : AdventureTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: textColor),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(color: borderColor.withValues(alpha: 0.3)),
              const SizedBox(height: 8),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Cartões de Status (Firebase Nuvem + Pendentes SQLite)
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatusCard(
                              context: context,
                              titulo: 'STATUS FIREBASE',
                              conteudo: _testandoConexao
                                  ? 'Verificando...'
                                  : (!kIsWeb && defaultTargetPlatform == TargetPlatform.linux)
                                      ? 'SQLite Local (Linux)'
                                      : (_conectado ? 'Conectado (Nuvem)' : 'Cache Local Ativo'),
                              cor: _conectado ? AdventureTheme.forestGreen : AdventureTheme.skyBlue,
                              icone: _conectado ? Icons.cloud_done : Icons.cloud_queue,
                              bgColor: cardBg,
                              borderColor: borderColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatusCard(
                              context: context,
                              titulo: 'PENDENTES LOCAL',
                              conteudo: '$_pendentes registro(s)',
                              cor: _pendentes > 0 ? AdventureTheme.goldCoin : AdventureTheme.forestGreen,
                              icone: Icons.pending_actions,
                              bgColor: cardBg,
                              borderColor: borderColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Informações do Projeto Firebase
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: borderColor.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.local_fire_department, size: 20, color: Colors.orange),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Projeto: talentos-f34f3',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: textColor,
                                    ),
                                  ),
                                  Text(
                                    'Última sincronização: ${_formatarDataHora(_syncService?.ultimaSincronizacao)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? AdventureTheme.darkTextMuted : AdventureTheme.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Verificar conexão',
                              icon: Icon(Icons.refresh, size: 20, color: textColor),
                              onPressed: _testandoConexao ? null : _verificarConexao,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Botão Principal: Sincronizar Agora (AdventureButton 3D)
                      AdventureButton(
                        backgroundColor: AdventureTheme.goldCoin,
                        borderColor: AdventureTheme.goldDark,
                        shadowColor: AdventureTheme.woodDark,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        onPressed: (_sincronizando || _syncService == null) ? null : _executarSincronizacao,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _sincronizando
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: AdventureTheme.woodDark),
                                  )
                                : const Icon(Icons.sync, color: AdventureTheme.woodDark, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              _sincronizando ? 'SINCRONIZANDO COM FIREBASE...' : 'SINCRONIZAR COM FIREBASE',
                              style: AdventureTheme.titleFredoka.copyWith(
                                color: AdventureTheme.woodDark,
                                fontSize: 14,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Banner do Resultado da Sincronização
                      if (_ultimoResultado != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _ultimoResultado!.sucesso
                                ? AdventureTheme.forestGreen.withValues(alpha: 0.15)
                                : AdventureTheme.errorCoral.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _ultimoResultado!.sucesso
                                  ? AdventureTheme.forestGreen
                                  : AdventureTheme.errorCoral,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _ultimoResultado!.sucesso ? Icons.check_circle : Icons.error_outline,
                                color: _ultimoResultado!.sucesso
                                    ? AdventureTheme.forestGreen
                                    : AdventureTheme.errorCoral,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _ultimoResultado!.mensagem,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: _ultimoResultado!.sucesso
                                        ? AdventureTheme.forestGreen
                                        : AdventureTheme.errorCoral,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),
                      Divider(color: borderColor.withValues(alpha: 0.3)),
                      const SizedBox(height: 10),

                      // Seção de Segurança: Alterar PIN
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: borderColor.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AdventureTheme.goldCoin.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.pin, color: AdventureTheme.goldDark, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'PIN do Professor / Admin',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor),
                                  ),
                                  Text(
                                    'Altere a senha numérica de 4 dígitos',
                                    style: TextStyle(fontSize: 11, color: isDark ? AdventureTheme.darkTextMuted : AdventureTheme.textMuted),
                                  ),
                                ],
                              ),
                            ),
                            AdventureButton(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              backgroundColor: cardBg,
                              borderColor: borderColor,
                              shadowColor: isDark ? Colors.black45 : AdventureTheme.woodDark,
                              borderRadius: 12,
                              onPressed: () => PinAuthDialog.abrirAlteracaoDePin(context),
                              child: Text(
                                'Alterar PIN',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Seção do Modo Sandbox (Demonstração / Testes)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: widget.repository.isSandboxMode
                              ? Colors.orange.withValues(alpha: 0.15)
                              : cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: widget.repository.isSandboxMode
                                ? Colors.orange
                                : borderColor.withValues(alpha: 0.4),
                            width: widget.repository.isSandboxMode ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.science, color: Colors.orange, size: 22),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Modo Demonstração (Sandbox)',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor),
                                  ),
                                ),
                                Switch(
                                  value: widget.repository.isSandboxMode,
                                  activeTrackColor: Colors.orange,
                                  onChanged: (val) {
                                    setState(() {
                                      widget.repository.setSandboxMode(val);
                                    });
                                    widget.onDadosAtualizados?.call();
                                  },
                                ),
                              ],
                            ),
                            Text(
                              'Executa o app em memória isolada sem salvar alterações no banco de dados da nuvem.',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AdventureTheme.darkTextMuted : AdventureTheme.textMuted,
                              ),
                            ),
                            if (widget.repository.isSandboxMode) ...[
                              const SizedBox(height: 12),
                              AdventureButton(
                                backgroundColor: Colors.orange.shade800,
                                borderColor: Colors.orange.shade900,
                                shadowColor: Colors.brown.shade900,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                onPressed: () {
                                  widget.repository.gerarDadosDemonstracao();
                                  widget.onDadosAtualizados?.call();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('5 crianças e 6 produtos fictícios carregados no Sandbox!'),
                                      backgroundColor: Colors.orange,
                                    ),
                                  );
                                },
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(Icons.auto_awesome, size: 16, color: Colors.white),
                                    SizedBox(width: 6),
                                    Text(
                                      'Gerar Dados de Demonstração',
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
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
    required BuildContext context,
    required String titulo,
    required String conteudo,
    required Color cor,
    required IconData icone,
    required Color bgColor,
    required Color borderColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor.withValues(alpha: 0.4)),
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
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: isDark ? AdventureTheme.darkTextMuted : AdventureTheme.textMuted,
                ),
              ),
              Icon(icone, color: cor, size: 18),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            conteudo,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: cor,
            ),
          ),
        ],
      ),
    );
  }
}
