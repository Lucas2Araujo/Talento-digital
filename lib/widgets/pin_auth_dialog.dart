import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/pin_security_service.dart';
import '../theme/adventure_theme.dart';

class PinAuthDialog extends StatefulWidget {
  final String titulo;
  final String subtitulo;
  final bool modoAlteracao;

  const PinAuthDialog({
    super.key,
    this.titulo = 'Acesso Administrativo',
    this.subtitulo = 'Digite o PIN de 4 dígitos para continuar',
    this.modoAlteracao = false,
  });

  /// Abre o diálogo para validar o PIN. Retorna `true` se autenticado com sucesso.
  static Future<bool> solicitarPin(
    BuildContext context, {
    String titulo = 'Acesso Administrativo',
    String subtitulo = 'Digite o PIN de 4 dígitos para continuar',
  }) async {
    final resultado = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => PinAuthDialog(
        titulo: titulo,
        subtitulo: subtitulo,
        modoAlteracao: false,
      ),
    );
    return resultado ?? false;
  }

  /// Abre o fluxo guiado para alterar o PIN (PIN atual -> Novo PIN -> Confirmar).
  static Future<bool> abrirAlteracaoDePin(BuildContext context) async {
    final resultado = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const PinAuthDialog(
        titulo: 'Alterar PIN de Segurança',
        subtitulo: 'Digite o PIN atual',
        modoAlteracao: true,
      ),
    );
    return resultado ?? false;
  }

  @override
  State<PinAuthDialog> createState() => _PinAuthDialogState();
}

class _PinAuthDialogState extends State<PinAuthDialog> {
  PinSecurityService? _pinService;
  String _pinBuffer = '';
  String _erroMsg = '';

  // Variáveis para o fluxo de alteração de PIN
  int _etapaAlteracao = 0; // 0: PIN atual, 1: Novo PIN, 2: Confirmar novo PIN
  String _pinAtualValidado = '';
  String _novoPinDigitado = '';

  @override
  void initState() {
    super.initState();
    _carregarService();
  }

  Future<void> _carregarService() async {
    final service = await PinSecurityService.getInstance();
    if (mounted) {
      setState(() => _pinService = service);
    }
  }

  void _onTeclaPressionada(String digito) {
    if (_pinBuffer.length >= 4) return;
    HapticFeedback.lightImpact();
    setState(() {
      _pinBuffer += digito;
      _erroMsg = '';
    });

    if (_pinBuffer.length == 4) {
      _processarPinCompleto();
    }
  }

  void _limpar() {
    HapticFeedback.selectionClick();
    setState(() {
      _pinBuffer = '';
      _erroMsg = '';
    });
  }

  void _apagar() {
    if (_pinBuffer.isNotEmpty) {
      HapticFeedback.selectionClick();
      setState(() {
        _pinBuffer = _pinBuffer.substring(0, _pinBuffer.length - 1);
        _erroMsg = '';
      });
    }
  }

  Future<void> _processarPinCompleto() async {
    if (_pinService == null) return;

    if (!widget.modoAlteracao) {
      // Modo Normal: Validação simples
      final valido = _pinService!.verificarPin(_pinBuffer);
      if (valido) {
        HapticFeedback.mediumImpact();
        Navigator.of(context).pop(true);
      } else {
        HapticFeedback.heavyImpact();
        setState(() {
          _erroMsg = 'PIN incorreto. Tente novamente.';
          _pinBuffer = '';
        });
      }
    } else {
      // Modo Alteração de PIN
      switch (_etapaAlteracao) {
        case 0: // Validar PIN atual
          final valido = _pinService!.verificarPin(_pinBuffer);
          if (valido) {
            HapticFeedback.mediumImpact();
            setState(() {
              _pinAtualValidado = _pinBuffer;
              _etapaAlteracao = 1;
              _pinBuffer = '';
              _erroMsg = '';
            });
          } else {
            HapticFeedback.heavyImpact();
            setState(() {
              _erroMsg = 'PIN atual incorreto.';
              _pinBuffer = '';
            });
          }
          break;

        case 1: // Receber Novo PIN
          setState(() {
            _novoPinDigitado = _pinBuffer;
            _etapaAlteracao = 2;
            _pinBuffer = '';
            _erroMsg = '';
          });
          break;

        case 2: // Confirmar Novo PIN
          if (_pinBuffer == _novoPinDigitado) {
            try {
              final ok = await _pinService!.alterarPin(
                pinAtualDigitado: _pinAtualValidado,
                novoPin: _novoPinDigitado,
              );
              if (ok && mounted) {
                HapticFeedback.mediumImpact();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('PIN alterado com sucesso!'),
                    backgroundColor: AdventureTheme.forestGreen,
                  ),
                );
                Navigator.of(context).pop(true);
              }
            } catch (e) {
              setState(() {
                _erroMsg = 'Erro: $e';
                _pinBuffer = '';
              });
            }
          } else {
            HapticFeedback.heavyImpact();
            setState(() {
              _erroMsg = 'Os PINs não coincidem. Recomece.';
              _etapaAlteracao = 1;
              _pinBuffer = '';
              _novoPinDigitado = '';
            });
          }
          break;
      }
    }
  }

  String _getSubtituloEtapa() {
    if (!widget.modoAlteracao) return widget.subtitulo;
    switch (_etapaAlteracao) {
      case 0:
        return 'Digite o PIN atual para autorizar a troca';
      case 1:
        return 'Digite o NOVO PIN de 4 dígitos';
      case 2:
        return 'Confirme o NOVO PIN digitado';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AdventureTheme.darkSurface : AdventureTheme.surface;
    final cardBg = isDark ? AdventureTheme.darkSurfaceVariant : Colors.white;
    final textColor = isDark ? AdventureTheme.darkTextLight : AdventureTheme.textDark;
    final textMuted = isDark ? AdventureTheme.darkTextMuted : AdventureTheme.textMuted;
    final borderColor = isDark ? AdventureTheme.darkOutline : AdventureTheme.woodBrown;

    return Dialog(
      backgroundColor: bgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: borderColor, width: 2.5),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Ícone e Título
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AdventureTheme.goldCoin,
                  shape: BoxShape.circle,
                  border: Border.all(color: AdventureTheme.goldDark, width: 2),
                ),
                child: const Icon(Icons.lock_rounded, color: AdventureTheme.woodDark, size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                widget.titulo,
                textAlign: TextAlign.center,
                style: AdventureTheme.titleFredoka.copyWith(fontSize: 18, color: textColor),
              ),
              const SizedBox(height: 4),
              Text(
                _getSubtituloEtapa(),
                textAlign: TextAlign.center,
                style: AdventureTheme.bodyNunito.copyWith(fontSize: 13, color: textMuted),
              ),
              const SizedBox(height: 20),

              // 4 Indicadores de Dígitos (Dots)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  final preenchido = index < _pinBuffer.length;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: preenchido ? AdventureTheme.goldCoin : cardBg,
                      border: Border.all(
                        color: preenchido ? AdventureTheme.goldDark : borderColor.withValues(alpha: 0.5),
                        width: 2.2,
                      ),
                      boxShadow: preenchido
                          ? [
                              BoxShadow(
                                color: AdventureTheme.goldDark.withValues(alpha: 0.4),
                                blurRadius: 6,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                  );
                }),
              ),

              // Mensagem de Erro
              Container(
                height: 28,
                alignment: Alignment.center,
                child: _erroMsg.isNotEmpty
                    ? Text(
                        _erroMsg,
                        style: const TextStyle(color: AdventureTheme.errorCoral, fontSize: 12, fontWeight: FontWeight.bold),
                      )
                    : null,
              ),

              const SizedBox(height: 8),

              // Teclado Numérico Touch
              _buildTecladoNumerico(cardBg, textColor, borderColor),

              const SizedBox(height: 12),

              // Botão Cancelar
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('Cancelar', style: TextStyle(color: textMuted, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTecladoNumerico(Color btnBg, Color txtColor, Color border) {
    return Table(
      children: [
        TableRow(
          children: [
            _buildKeypadBtn('1', btnBg, txtColor, border),
            _buildKeypadBtn('2', btnBg, txtColor, border),
            _buildKeypadBtn('3', btnBg, txtColor, border),
          ],
        ),
        TableRow(
          children: [
            _buildKeypadBtn('4', btnBg, txtColor, border),
            _buildKeypadBtn('5', btnBg, txtColor, border),
            _buildKeypadBtn('6', btnBg, txtColor, border),
          ],
        ),
        TableRow(
          children: [
            _buildKeypadBtn('7', btnBg, txtColor, border),
            _buildKeypadBtn('8', btnBg, txtColor, border),
            _buildKeypadBtn('9', btnBg, txtColor, border),
          ],
        ),
        TableRow(
          children: [
            _buildKeypadBtn('C', btnBg, AdventureTheme.errorCoral, border, onTap: _limpar),
            _buildKeypadBtn('0', btnBg, txtColor, border),
            _buildKeypadBtn('⌫', btnBg, AdventureTheme.goldDark, border, onTap: _apagar),
          ],
        ),
      ],
    );
  }

  Widget _buildKeypadBtn(
    String rotulo,
    Color btnBg,
    Color txtColor,
    Color border, {
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: AdventureButton(
        padding: const EdgeInsets.symmetric(vertical: 12),
        backgroundColor: btnBg,
        borderColor: border.withValues(alpha: 0.6),
        shadowColor: border,
        borderRadius: 14,
        onPressed: onTap ?? () => _onTeclaPressionada(rotulo),
        child: Center(
          child: Text(
            rotulo,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: txtColor,
            ),
          ),
        ),
      ),
    );
  }
}
