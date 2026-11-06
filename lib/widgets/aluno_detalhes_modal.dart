import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database/models.dart';
import '../database/talentos_repository.dart';

class AlunoDetalhesModal extends StatefulWidget {
  final AlunoModel alunoInicial;
  final TalentosRepository repository;
  final VoidCallback onDataChanged;

  const AlunoDetalhesModal({
    super.key,
    required this.alunoInicial,
    required this.repository,
    required this.onDataChanged,
  });

  static Future<void> show(
    BuildContext context, {
    required AlunoModel aluno,
    required TalentosRepository repository,
    required VoidCallback onDataChanged,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AlunoDetalhesModal(
        alunoInicial: aluno,
        repository: repository,
        onDataChanged: onDataChanged,
      ),
    );
  }

  @override
  State<AlunoDetalhesModal> createState() => _AlunoDetalhesModalState();
}

class _AlunoDetalhesModalState extends State<AlunoDetalhesModal> {
  late AlunoModel _aluno;
  bool _loading = false;
  List<TransacaoSaldoModel>? _historico;
  bool _exibindoHistorico = false;

  @override
  void initState() {
    super.initState();
    _aluno = widget.alunoInicial;
  }

  Future<void> _adicionarTalentos(int quantidade, String motivo) async {
    setState(() => _loading = true);
    try {
      final novoSaldo = await widget.repository.adicionarTalentos(
        alunoUid: _aluno.uid,
        quantidade: quantidade,
        motivo: motivo,
      );

      HapticFeedback.mediumImpact();
      SystemSound.play(SystemSoundType.click);

      if (mounted) {
        setState(() {
          _aluno = AlunoModel(
            uid: _aluno.uid,
            nome: _aluno.nome,
            turma: _aluno.turma,
            saldoTalentos: novoSaldo,
            ativo: _aluno.ativo,
            updatedAt: DateTime.now().toIso8601String(),
          );
          _loading = false;
        });

        widget.onDataChanged();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              quantidade >= 0
                  ? '+$quantidade Talentos: $motivo'
                  : '$quantidade Talentos: $motivo',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: quantidade >= 0 ? Colors.green.shade800 : Colors.red.shade800,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );

        if (_exibindoHistorico) {
          _carregarHistorico();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _abrirAjusteLivre() async {
    final controllerQtd = TextEditingController();
    final controllerMotivo = TextEditingController(text: 'Ajuste manual');
    bool ehAdicao = true;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Ajuste Livre de Saldo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ChoiceChip(
                    label: const Text('+ Adicionar'),
                    selected: ehAdicao,
                    onSelected: (val) => setDialogState(() => ehAdicao = true),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('- Subtrair'),
                    selected: !ehAdicao,
                    onSelected: (val) => setDialogState(() => ehAdicao = false),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controllerQtd,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Quantidade de Talentos',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.monetization_on),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controllerMotivo,
                decoration: const InputDecoration(
                  labelText: 'Motivo do Ajuste',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final qtd = int.tryParse(controllerQtd.text.trim()) ?? 0;
                if (qtd > 0) {
                  Navigator.pop(ctx);
                  final valorFinal = ehAdicao ? qtd : -qtd;
                  _adicionarTalentos(valorFinal, controllerMotivo.text.trim());
                }
              },
              child: const Text('Confirmar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _dialogVincularOuTrocarTag({required bool ehSubstituicao}) async {
    final controllerTag = TextEditingController();

    bool listenerTemporario(KeyEvent event) {
      if (event is! KeyDownEvent) return false;
      if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.numpadEnter) {
        final code = controllerTag.text.trim();
        if (code.isNotEmpty && RegExp(r'^[0-9a-fA-F]{8,20}$').hasMatch(code)) {
          return true;
        }
      }
      return false;
    }

    HardwareKeyboard.instance.addHandler(listenerTemporario);

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(
                ehSubstituicao ? Icons.sync_problem : Icons.nfc,
                color: ehSubstituicao ? Colors.orangeAccent : Colors.amber,
              ),
              const SizedBox(width: 10),
              Text(ehSubstituicao ? 'Substituir Tag Perdida' : 'Cadastrar Tag NFC'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ehSubstituicao
                    ? 'Aproxime o NOVO chaveiro NFC do leitor USB (ou digite o UID abaixo). O saldo e o histórico de ${_aluno.nome} serão migrados para a nova tag.'
                    : 'Aproxime o chaveiro NFC do leitor USB para vincular a ${_aluno.nome}:',
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controllerTag,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'UID da Nova Tag',
                  hintText: 'Ex: 044EE8A8892681',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.credit_card),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                final novaTag = controllerTag.text.trim().toUpperCase();
                if (novaTag.isEmpty) return;

                // Verifica se a tag já pertence a outro aluno
                final existente = await widget.repository.buscarAlunoPorUid(novaTag);
                if (existente != null) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text('Esta tag já está cadastrada para o aluno: ${existente.nome}!'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                  return;
                }

                try {
                  await widget.repository.vincularTagAoAluno(
                    uidAntigo: _aluno.uid,
                    novoUidTag: novaTag,
                  );

                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                  }

                  final alunoAtualizado = await widget.repository.buscarAlunoPorUid(novaTag);
                  if (mounted && alunoAtualizado != null) {
                    setState(() {
                      _aluno = alunoAtualizado;
                    });
                    widget.onDataChanged();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(ehSubstituicao ? 'Tag substituída com sucesso!' : 'Tag vinculada com sucesso!'),
                        backgroundColor: Colors.green.shade800,
                      ),
                    );
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Erro ao vincular: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('Confirmar Vínculo'),
            ),
          ],
        ),
      ),
    );

    HardwareKeyboard.instance.removeHandler(listenerTemporario);
  }

  Future<void> _carregarHistorico() async {
    final list = await widget.repository.listarTransacoesDoAluno(_aluno.uid, limit: 15);
    if (mounted) {
      setState(() {
        _historico = list;
        _exibindoHistorico = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isManual = _aluno.uid.startsWith('MANUAL_');

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle do modal
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade700,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Cabeçalho do Aluno
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.amber.shade700,
                  child: Text(
                    _aluno.nome.isNotEmpty ? _aluno.nome[0].toUpperCase() : '?',
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _aluno.nome,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (_aluno.turma != null && _aluno.turma!.isNotEmpty) ...[
                            Text(
                              _aluno.turma!,
                              style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
                            ),
                            const Text(' • ', style: TextStyle(color: Colors.grey)),
                          ],
                          Flexible(
                            child: Text(
                              isManual ? 'Sem Tag NFC' : 'Tag: ${_aluno.uid}',
                              style: TextStyle(
                                fontSize: 13,
                                fontFamily: isManual ? null : 'monospace',
                                color: isManual ? Colors.orangeAccent : Colors.grey.shade400,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Botões contextuais de gerenciamento de tag
                      if (isManual)
                        InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: () => _dialogVincularOuTrocarTag(ehSubstituicao: false),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.add_link, size: 16, color: Colors.amber),
                                const SizedBox(width: 4),
                                Text(
                                  'Cadastrar Tag NFC',
                                  style: TextStyle(fontSize: 12, color: Colors.amber.shade300, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: () => _dialogVincularOuTrocarTag(ehSubstituicao: true),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.swap_horiz, size: 16, color: Colors.orangeAccent),
                                const SizedBox(width: 4),
                                const Text(
                                  'Perdi a tag (Substituir)',
                                  style: TextStyle(fontSize: 12, color: Colors.orangeAccent, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
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
            const Divider(height: 32),

            // Destaque de Saldo de Talentos
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  const Text('SALDO DISPONÍVEL', style: TextStyle(fontSize: 12, letterSpacing: 1.5, color: Colors.grey)),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.monetization_on, color: Colors.amber, size: 40),
                      const SizedBox(width: 10),
                      Text(
                        '${_aluno.saldoTalentos}',
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Botões de Ação Rápida
            const Text(
              'Lançamento Rápido de Talentos',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 10),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildActionChip(
                  label: '+1 Presença',
                  color: Colors.blueAccent,
                  onTap: _loading ? null : () => _adicionarTalentos(1, 'Presença na Escola Sabatina'),
                ),
                _buildActionChip(
                  label: '+2 Lição Feita',
                  color: Colors.tealAccent,
                  onTap: _loading ? null : () => _adicionarTalentos(2, 'Lição da Semana Completa'),
                ),
                _buildActionChip(
                  label: '+5 Verso Bíblico',
                  color: Colors.amberAccent,
                  onTap: _loading ? null : () => _adicionarTalentos(5, 'Versículo Decorado'),
                ),
                _buildActionChip(
                  label: '+3 Ação Especial',
                  color: Colors.purpleAccent,
                  onTap: _loading ? null : () => _adicionarTalentos(3, 'Participação / Ação Especial'),
                ),
                ActionChip(
                  avatar: const Icon(Icons.tune, size: 16),
                  label: const Text('Ajuste Livre (+/-)'),
                  onPressed: _loading ? null : _abrirAjusteLivre,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Botão de Histórico
            OutlinedButton.icon(
              icon: Icon(_exibindoHistorico ? Icons.keyboard_arrow_up : Icons.history),
              label: Text(_exibindoHistorico ? 'Ocultar Histórico' : 'Ver Últimas Movimentações'),
              onPressed: () {
                if (_exibindoHistorico) {
                  setState(() => _exibindoHistorico = false);
                } else {
                  _carregarHistorico();
                }
              },
            ),

            if (_exibindoHistorico) ...[
              const SizedBox(height: 12),
              if (_historico == null)
                const Center(child: CircularProgressIndicator())
              else if (_historico!.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: Center(child: Text('Nenhuma movimentação registrada.')),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _historico!.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final item = _historico![i];
                    final isEntrada = item.tipo == 'ENTRADA';
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        isEntrada ? Icons.arrow_upward : Icons.arrow_downward,
                        color: isEntrada ? Colors.greenAccent : Colors.redAccent,
                        size: 20,
                      ),
                      title: Text(item.motivo, style: const TextStyle(fontSize: 14)),
                      subtitle: Text(
                        '${item.createdAt.substring(0, 10)} • Por ${item.operador}',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      trailing: Text(
                        '${isEntrada ? "+" : "-"}${item.quantidade}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isEntrada ? Colors.greenAccent : Colors.redAccent,
                        ),
                      ),
                    );
                  },
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionChip({
    required String label,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return ActionChip(
      backgroundColor: color.withValues(alpha: 0.15),
      side: BorderSide(color: color.withValues(alpha: 0.5)),
      label: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
      onPressed: onTap,
    );
  }
}
