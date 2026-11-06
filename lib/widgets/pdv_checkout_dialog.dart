import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database/models.dart';
import '../database/talentos_repository.dart';
import '../services/nfc_usb_listener.dart';
import 'aluno_detalhes_modal.dart';

enum CheckoutState {
  aguardando,
  processando,
  aprovado,
  recusado,
}

class PdvCheckoutDialog extends StatefulWidget {
  final int totalTalentos;
  final List<ItemVendaDto> itensVenda;
  final TalentosRepository repository;
  final AlunoModel? alunoPreSelecionado;
  final VoidCallback onVendaConcluida;

  const PdvCheckoutDialog({
    super.key,
    required this.totalTalentos,
    required this.itensVenda,
    required this.repository,
    this.alunoPreSelecionado,
    required this.onVendaConcluida,
  });

  static Future<void> show(
    BuildContext context, {
    required int totalTalentos,
    required List<ItemVendaDto> itensVenda,
    required TalentosRepository repository,
    AlunoModel? alunoPreSelecionado,
    required VoidCallback onVendaConcluida,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PdvCheckoutDialog(
        totalTalentos: totalTalentos,
        itensVenda: itensVenda,
        repository: repository,
        alunoPreSelecionado: alunoPreSelecionado,
        onVendaConcluida: onVendaConcluida,
      ),
    );
  }

  @override
  State<PdvCheckoutDialog> createState() => _PdvCheckoutDialogState();
}

class _PdvCheckoutDialogState extends State<PdvCheckoutDialog>
    with SingleTickerProviderStateMixin {
  late final NfcUsbListener _nfcListener;
  final TextEditingController _buscaNomeController = TextEditingController();

  CheckoutState _estado = CheckoutState.aguardando;
  AlunoModel? _alunoAtual;
  int _novoSaldo = 0;
  String _erroMsg = '';
  List<AlunoModel> _alunosEncontrados = [];
  bool _buscando = false;

  Timer? _timerAutoRetorno;
  int _segundosRestantes = 4;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _nfcListener = NfcUsbListener(onTagScanned: _tratarTagLida);
    _nfcListener.start();

    if (widget.alunoPreSelecionado != null) {
      _processarTentativaVenda(widget.alunoPreSelecionado!);
    }
  }

  @override
  void dispose() {
    _nfcListener.stop();
    _timerAutoRetorno?.cancel();
    _pulseController.dispose();
    _buscaNomeController.dispose();
    super.dispose();
  }

  Future<void> _tratarTagLida(String uid) async {
    if (_estado == CheckoutState.processando || _estado == CheckoutState.aprovado) {
      return;
    }

    setState(() {
      _estado = CheckoutState.processando;
      _erroMsg = '';
    });

    try {
      final aluno = await widget.repository.buscarAlunoPorUid(uid);
      if (!mounted) return;

      if (aluno == null) {
        setState(() {
          _estado = CheckoutState.aguardando;
          _erroMsg = 'Tag "$uid" não está cadastrada para nenhum aluno!';
        });
        return;
      }

      await _processarTentativaVenda(aluno);
    } catch (e) {
      if (mounted) {
        setState(() {
          _estado = CheckoutState.aguardando;
          _erroMsg = 'Erro ao consultar tag: $e';
        });
      }
    }
  }

  Future<void> _processarTentativaVenda(AlunoModel aluno) async {
    setState(() {
      _alunoAtual = aluno;
      _estado = CheckoutState.processando;
      _erroMsg = '';
    });

    // Validação estrita de saldo (Sem venda fiada)
    if (aluno.saldoTalentos < widget.totalTalentos) {
      HapticFeedback.heavyImpact();
      SystemSound.play(SystemSoundType.alert);
      setState(() {
        _estado = CheckoutState.recusado;
      });
      return;
    }

    // Saldo suficiente -> Processar venda de forma atômica
    try {
      await widget.repository.processarVenda(
        alunoUid: aluno.uid,
        itens: widget.itensVenda,
        totalTalentos: widget.totalTalentos,
      );

      HapticFeedback.mediumImpact();
      SystemSound.play(SystemSoundType.click);

      final alunoAtualizado = await widget.repository.buscarAlunoPorUid(aluno.uid);
      final saldoFinal = alunoAtualizado?.saldoTalentos ?? (aluno.saldoTalentos - widget.totalTalentos);

      if (!mounted) return;

      setState(() {
        _novoSaldo = saldoFinal;
        _estado = CheckoutState.aprovado;
      });

      widget.onVendaConcluida();
      _iniciarContagemAutoRetorno();
    } catch (e) {
      if (mounted) {
        setState(() {
          _estado = CheckoutState.recusado;
          _erroMsg = 'Falha ao registrar venda: $e';
        });
      }
    }
  }

  void _iniciarContagemAutoRetorno() {
    _timerAutoRetorno?.cancel();
    _segundosRestantes = 4;
    _timerAutoRetorno = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_segundosRestantes <= 1) {
        timer.cancel();
        Navigator.of(context).pop();
      } else {
        setState(() => _segundosRestantes--);
      }
    });
  }

  Future<void> _buscarPorNome(String termo) async {
    final query = termo.trim();
    if (query.isEmpty) {
      setState(() {
        _alunosEncontrados = [];
        _buscando = false;
      });
      return;
    }

    setState(() => _buscando = true);
    final resultados = await widget.repository.buscarAlunosPorNome(query);
    if (mounted) {
      setState(() {
        _alunosEncontrados = resultados;
        _buscando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        color: _calcularCorFundo(),
        child: SafeArea(
          child: Column(
            children: [
              // Barra de Título Superior
              _buildTopBar(),

              // Conteúdo Centralizado
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: _buildConteudoPorEstado(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _calcularCorFundo() {
    switch (_estado) {
      case CheckoutState.aprovado:
        return const Color(0xFF14381C); // Verde maquininha aprovada
      case CheckoutState.recusado:
        return const Color(0xFF381414); // Vermelho maquininha recusada
      case CheckoutState.processando:
      case CheckoutState.aguardando:
        return const Color(0xFF161616);
    }
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black26,
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.point_of_sale_rounded, color: Colors.amber),
              const SizedBox(width: 8),
              Text(
                'FEIRINHA - PAGAMENTO',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: Colors.grey.shade300,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          IconButton(
            tooltip: 'Cancelar e Voltar',
            icon: const Icon(Icons.close, size: 28),
            onPressed: () {
              _timerAutoRetorno?.cancel();
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildConteudoPorEstado() {
    switch (_estado) {
      case CheckoutState.aguardando:
        return _buildAguardandoLeitura();
      case CheckoutState.processando:
        return _buildProcessando();
      case CheckoutState.aprovado:
        return _buildAprovado();
      case CheckoutState.recusado:
        return _buildRecusado();
    }
  }

  Widget _buildAguardandoLeitura() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Cartão do Valor Total em Destaque
        Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
          decoration: BoxDecoration(
            color: const Color(0xFF222222),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.amber.withValues(alpha: 0.4), width: 1.5),
          ),
          child: Column(
            children: [
              const Text(
                'VALOR TOTAL A COBRAR',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  const Icon(Icons.monetization_on, color: Colors.amber, size: 36),
                  const SizedBox(width: 8),
                  Text(
                    '${widget.totalTalentos}',
                    style: const TextStyle(
                      fontSize: 54,
                      fontWeight: FontWeight.w900,
                      color: Colors.amber,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Talentos',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.amber,
                    ),
                  ),
                ],
              ),
              Text(
                '${widget.itensVenda.length} item(ns) no carrinho',
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        // Ícone Pulsante de NFC USB
        ScaleTransition(
          scale: _pulseAnimation,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.amber.withValues(alpha: 0.12),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.3), width: 2),
            ),
            child: const Icon(
              Icons.nfc_rounded,
              size: 72,
              color: Colors.amber,
            ),
          ),
        ),

        const SizedBox(height: 16),
        const Text(
          'Aproxime o chaveiro NFC da criança...',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          'Leitor USB ativo. Ou pesquise pelo nome abaixo:',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),

        if (_erroMsg.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.red.shade900.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.redAccent),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _erroMsg,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 24),

        // Campo de Busca Manual (Contingência)
        TextField(
          controller: _buscaNomeController,
          onChanged: _buscarPorNome,
          decoration: InputDecoration(
            hintText: 'Digite o nome da criança...',
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: const Color(0xFF242424),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            suffixIcon: _buscaNomeController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _buscaNomeController.clear();
                      _buscarPorNome('');
                    },
                  )
                : null,
          ),
        ),

        // Resultados da Busca por Nome
        if (_buscando) ...[
          const SizedBox(height: 16),
          const Center(child: CircularProgressIndicator()),
        ] else if (_alunosEncontrados.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            constraints: const BoxConstraints(maxHeight: 220),
            decoration: BoxDecoration(
              color: const Color(0xFF222222),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _alunosEncontrados.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final aluno = _alunosEncontrados[index];
                final temSaldoSuficiente = aluno.saldoTalentos >= widget.totalTalentos;
                return ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    backgroundColor: temSaldoSuficiente ? Colors.green.shade800 : Colors.red.shade800,
                    foregroundColor: Colors.white,
                    child: Text(
                      aluno.nome.isNotEmpty ? aluno.nome[0].toUpperCase() : '?',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(
                    aluno.nome,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  subtitle: Text(
                    aluno.turma ?? 'Sem turma',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Saldo: ${aluno.saldoTalentos}T',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: temSaldoSuficiente ? Colors.greenAccent : Colors.redAccent,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right, size: 20),
                    ],
                  ),
                  onTap: () => _processarTentativaVenda(aluno),
                );
              },
            ),
          ),
        ],

        const SizedBox(height: 16),
        // Botão utilitário para desenvolvedores / simulação
        Center(
          child: TextButton.icon(
            icon: const Icon(Icons.developer_mode, size: 16),
            label: const Text('Simular leitura de Tag (Demo)'),
            style: TextButton.styleFrom(foregroundColor: Colors.grey),
            onPressed: () => _nfcListener.simulateScan('041693AB8A2681'),
          ),
        ),
      ],
    );
  }

  Widget _buildProcessando() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 64,
          height: 64,
          child: CircularProgressIndicator(strokeWidth: 4, color: Colors.amber),
        ),
        const SizedBox(height: 24),
        Text(
          _alunoAtual != null
              ? 'Validando saldo de ${_alunoAtual!.nome}...'
              : 'Consultando leitor...',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildAprovado() {
    return InkWell(
      onTap: () {
        _timerAutoRetorno?.cancel();
        Navigator.of(context).pop();
      },
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.6), width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.greenAccent,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded, color: Colors.black, size: 64),
            ),
            const SizedBox(height: 20),
            const Text(
              'COMPRA APROVADA!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Colors.greenAccent,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 10),
            if (_alunoAtual != null) ...[
              Text(
                _alunoAtual!.nome,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              if (_alunoAtual!.turma != null)
                Text(
                  _alunoAtual!.turma!,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
            ],
            const SizedBox(height: 24),
            const Divider(color: Colors.white24),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildResumoPill(
                  titulo: 'TOTAL PAGO',
                  valor: '${widget.totalTalentos} T',
                  cor: Colors.amberAccent,
                ),
                _buildResumoPill(
                  titulo: 'NOVO SALDO',
                  valor: '$_novoSaldo T',
                  cor: Colors.greenAccent,
                ),
              ],
            ),
            const SizedBox(height: 28),
            Text(
              'Retornando automaticamente em $_segundosRestantes segundos...',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.greenAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: () {
                _timerAutoRetorno?.cancel();
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Nova Venda (Concluir)', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecusado() {
    final saldoAtual = _alunoAtual?.saldoTalentos ?? 0;
    final faltam = (widget.totalTalentos - saldoAtual).clamp(0, 999999);

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.6), width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.redAccent,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.close_rounded, color: Colors.white, size: 64),
          ),
          const SizedBox(height: 20),
          const Text(
            'SALDO INSUFICIENTE!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: Colors.redAccent,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          if (_alunoAtual != null) ...[
            Text(
              _alunoAtual!.nome,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            if (_alunoAtual!.turma != null)
              Text(
                _alunoAtual!.turma!,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
          ],
          const SizedBox(height: 20),
          const Divider(color: Colors.white24),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildResumoPill(
                titulo: 'SALDO ATUAL',
                valor: '$saldoAtual T',
                cor: Colors.white70,
              ),
              _buildResumoPill(
                titulo: 'TOTAL VENDA',
                valor: '${widget.totalTalentos} T',
                cor: Colors.amberAccent,
              ),
              _buildResumoPill(
                titulo: 'FALTAM',
                valor: '$faltam T',
                cor: Colors.redAccent,
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Não é permitida venda com saldo negativo.\nAjuste os itens no carrinho ou credite novos talentos.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white60),
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Voltar ao Carrinho'),
              ),
              if (_alunoAtual != null) ...[
                const SizedBox(width: 12),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: Colors.amber.shade800),
                  onPressed: () {
                    AlunoDetalhesModal.show(
                      context,
                      aluno: _alunoAtual!,
                      repository: widget.repository,
                      onDataChanged: () async {
                        final recarregado = await widget.repository.buscarAlunoPorUid(_alunoAtual!.uid);
                        if (mounted && recarregado != null) {
                          setState(() {
                            _alunoAtual = recarregado;
                          });
                        }
                      },
                    );
                  },
                  icon: const Icon(Icons.add_circle_outline, color: Colors.black),
                  label: const Text(
                    'Creditar Talentos',
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResumoPill({
    required String titulo,
    required String valor,
    required Color cor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cor.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Text(
            titulo,
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1.1,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            valor,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: cor,
            ),
          ),
        ],
      ),
    );
  }
}
