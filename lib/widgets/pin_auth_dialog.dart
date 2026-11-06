import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/pin_security_service.dart';

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
      // Modo Validação Normal
      final valido = _pinService!.verificarPin(_pinBuffer);
      if (valido) {
        HapticFeedback.mediumImpact();
        SystemSound.play(SystemSoundType.click);
        Navigator.of(context).pop(true);
      } else {
        HapticFeedback.heavyImpact();
        SystemSound.play(SystemSoundType.alert);
        setState(() {
          _erroMsg = 'PIN incorreto. Tente novamente.';
          _pinBuffer = '';
        });
      }
    } else {
      // Modo Alteração de PIN em Etapas
      if (_etapaAlteracao == 0) {
        // Validação do PIN atual
        if (_pinService!.verificarPin(_pinBuffer)) {
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
      } else if (_etapaAlteracao == 1) {
        // Novo PIN digitado
        setState(() {
          _novoPinDigitado = _pinBuffer;
          _etapaAlteracao = 2;
          _pinBuffer = '';
          _erroMsg = '';
        });
      } else if (_etapaAlteracao == 2) {
        // Confirmação do novo PIN
        if (_pinBuffer == _novoPinDigitado) {
          await _pinService!.alterarPin(
            pinAtualDigitado: _pinAtualValidado,
            novoPin: _novoPinDigitado,
          );
          HapticFeedback.mediumImpact();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('PIN alterado com sucesso!'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.of(context).pop(true);
          }
        } else {
          HapticFeedback.heavyImpact();
          setState(() {
            _erroMsg = 'Os PINs não conferem. Digite o novo PIN novamente.';
            _etapaAlteracao = 1;
            _pinBuffer = '';
          });
        }
      }
    }
  }

  String _getSubtituloEtapa() {
    if (!widget.modoAlteracao) return widget.subtitulo;
    switch (_etapaAlteracao) {
      case 0:
        return 'Digite o PIN atual';
      case 1:
        return 'Digite o NOVO PIN de 4 dígitos';
      case 2:
        return 'Confirme o NOVO PIN de 4 dígitos';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
                  color: Colors.amber.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_rounded, color: Colors.amber, size: 32),
              ),
              const SizedBox(height: 12),
              Text(
                widget.titulo,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                _getSubtituloEtapa(),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
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
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: preenchido ? Colors.amber : Colors.transparent,
                      border: Border.all(
                        color: preenchido ? Colors.amber : Colors.grey.shade600,
                        width: 2,
                      ),
                      boxShadow: preenchido
                          ? [
                              BoxShadow(
                                color: Colors.amber.withValues(alpha: 0.4),
                                blurRadius: 8,
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
                        style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
                      )
                    : null,
              ),

              const SizedBox(height: 8),

              // Teclado Numérico Touch
              _buildTecladoNumerico(),

              const SizedBox(height: 12),

              // Botão Cancelar
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTecladoNumerico() {
    return Table(
      children: [
        TableRow(
          children: [
            _buildKeypadBtn('1'),
            _buildKeypadBtn('2'),
            _buildKeypadBtn('3'),
          ],
        ),
        TableRow(
          children: [
            _buildKeypadBtn('4'),
            _buildKeypadBtn('5'),
            _buildKeypadBtn('6'),
          ],
        ),
        TableRow(
          children: [
            _buildKeypadBtn('7'),
            _buildKeypadBtn('8'),
            _buildKeypadBtn('9'),
          ],
        ),
        TableRow(
          children: [
            _buildKeypadBtn('C', cor: Colors.redAccent, onTap: _limpar),
            _buildKeypadBtn('0'),
            _buildKeypadBtn('⌫', cor: Colors.orangeAccent, onTap: _apagar),
          ],
        ),
      ],
    );
  }

  Widget _buildKeypadBtn(String rotulo, {Color? cor, VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: Material(
        color: const Color(0xFF282828),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap ?? () => _onTeclaPressionada(rotulo),
          child: Container(
            height: 52,
            alignment: Alignment.center,
            child: Text(
              rotulo,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: cor ?? Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
