import 'package:flutter/material.dart';
import '../database/models.dart';
import '../database/talentos_repository.dart';
import '../services/image_helper_service.dart';
import '../services/pin_security_service.dart';
import '../theme/adventure_theme.dart';
import 'pin_auth_dialog.dart';

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
    return showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: const Color(0xFF2D261E).withValues(alpha: 0.65),
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: AlunoDetalhesModal(
          alunoInicial: aluno,
          repository: repository,
          onDataChanged: onDataChanged,
        ),
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

  Future<void> _adicionarTalentos(int qtd, String motivo) async {
    setState(() => _loading = true);
    try {
      final novoSaldo = await widget.repository.adicionarTalentos(
        alunoUid: _aluno.uid,
        quantidade: qtd,
        motivo: motivo,
        operador: 'Professor',
      );
      setState(() {
        _aluno = _aluno.copyWith(saldoTalentos: novoSaldo);
      });
      widget.onDataChanged();
      if (_exibindoHistorico) _carregarHistorico();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e'),
            backgroundColor: AdventureTheme.errorCoral,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _abrirAjusteLivre() async {
    final controller = TextEditingController();
    final motivoCtrl = TextEditingController(text: 'Bonificação Especial');
    bool ehAdicao = true;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AdventureTheme.woodBrown, width: 2.5),
          ),
          backgroundColor: AdventureTheme.surface,
          title: Text(
            'Ajuste Livre de Talentos',
            style: AdventureTheme.titleFredoka.copyWith(fontSize: 18),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ChoiceChip(
                    label: const Text('+ Adicionar'),
                    selected: ehAdicao,
                    selectedColor: AdventureTheme.forestGreen,
                    onSelected: (val) => setDlg(() => ehAdicao = true),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('- Remover'),
                    selected: !ehAdicao,
                    selectedColor: AdventureTheme.errorCoral,
                    onSelected: (val) => setDlg(() => ehAdicao = false),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Quantidade de Talentos',
                  hintText: 'Ex: 10',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.monetization_on, color: AdventureTheme.goldCoin),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: motivoCtrl,
                decoration: InputDecoration(
                  labelText: 'Motivo',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.description),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar', style: TextStyle(color: AdventureTheme.woodDark)),
            ),
            AdventureButton(
              backgroundColor: ehAdicao ? AdventureTheme.forestGreen : AdventureTheme.errorCoral,
              borderColor: ehAdicao ? AdventureTheme.forestGreenDark : const Color(0xFFB24B32),
              onPressed: () {
                final qtd = int.tryParse(controller.text.trim()) ?? 0;
                if (qtd > 0) {
                  Navigator.pop(ctx);
                  _adicionarTalentos(
                    ehAdicao ? qtd : -qtd,
                    motivoCtrl.text.trim().isEmpty ? 'Ajuste manual' : motivoCtrl.text.trim(),
                  );
                }
              },
              child: const Text('Confirmar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _dialogVincularOuTrocarTag({required bool ehSubstituicao}) async {
    final autorizado = await PinAuthDialog.solicitarPin(
      context,
      titulo: ehSubstituicao ? 'Substituir Tag Perdida' : 'Cadastrar Tag NFC',
      subtitulo: 'Digite o PIN para alterar a tag de ${_aluno.nome}',
    );
    if (!autorizado || !mounted) return;

    final controllerTag = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AdventureTheme.woodBrown, width: 2.5),
        ),
        backgroundColor: AdventureTheme.surface,
        title: Text(
          ehSubstituicao ? 'Substituir Tag Perdida' : 'Cadastrar Tag NFC',
          style: AdventureTheme.titleFredoka.copyWith(fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ehSubstituicao
                  ? 'Aproxime a NOVA tag do leitor ou digite o UID. O saldo de ${_aluno.nome} será preservado.'
                  : 'Aproxime a tag NFC para vincular a ${_aluno.nome}:',
              style: AdventureTheme.bodyNunito.copyWith(fontSize: 13, color: AdventureTheme.textMuted),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controllerTag,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'UID da Nova Tag',
                hintText: 'Ex: 041693AB8A2681',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.credit_card),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: AdventureTheme.woodDark)),
          ),
          AdventureButton(
            onPressed: () async {
              final novaTag = controllerTag.text.trim().toUpperCase();
              if (novaTag.isEmpty) return;

              final existente = await widget.repository.buscarAlunoPorUid(novaTag);
              if (existente != null && existente.uid != _aluno.uid) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text('Tag já pertence a ${existente.nome}!'),
                      backgroundColor: AdventureTheme.errorCoral,
                    ),
                  );
                }
                return;
              }

              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              await widget.repository.vincularTagAoAluno(
                uidAntigo: _aluno.uid,
                novoUidTag: novaTag,
              );

              final recarregado = await widget.repository.buscarAlunoPorUid(novaTag);
              if (recarregado != null && mounted) {
                setState(() => _aluno = recarregado);
                widget.onDataChanged();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Tag vinculada com sucesso!'),
                    backgroundColor: AdventureTheme.forestGreen,
                  ),
                );
              }
            },
            child: const Text('Salvar Tag', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
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
    final nivel = (_aluno.saldoTalentos ~/ 20) + 1;
    final isManual = _aluno.uid.startsWith('MANUAL_');

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        // 1. Container do Crachá
        Container(
          constraints: const BoxConstraints(maxWidth: 480),
          decoration: BoxDecoration(
            color: AdventureTheme.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AdventureTheme.woodBrown, width: 3.5),
            boxShadow: const [
              BoxShadow(
                color: AdventureTheme.woodDark,
                offset: Offset(0, 10),
                blurRadius: 0,
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Linha de Cabeçalho: Status NFC + Fechar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD8F3DC),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AdventureTheme.forestGreenDark.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.check_circle, size: 14, color: AdventureTheme.forestGreenDark),
                          SizedBox(width: 4),
                          Text(
                            'CRACHÁ MÁGICO',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: AdventureTheme.forestGreenDark,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AdventureTheme.woodDark, size: 22),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // 2. Avatar Circular 120x120 com borda dourada e Nível
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    ImageHelperService.buildAvatarWidget(
                      fotoBase64: _aluno.fotoBase64,
                      avatarId: _aluno.avatarId,
                      nome: _aluno.nome,
                      size: 110,
                      borderWidth: 4,
                      borderColor: AdventureTheme.goldCoin,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AdventureTheme.goldCoin,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AdventureTheme.woodBrown, width: 1.8),
                        boxShadow: const [
                          BoxShadow(color: AdventureTheme.woodDark, offset: Offset(0, 2), blurRadius: 0),
                        ],
                      ),
                      child: Text(
                        '⭐ Lvl $nivel',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: AdventureTheme.woodDark,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Nome Completo
                Text(
                  _aluno.nome,
                  textAlign: TextAlign.center,
                  style: AdventureTheme.titleFredoka.copyWith(fontSize: 22),
                ),
                const SizedBox(height: 6),

                // Chips de Turma e ID
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  alignment: WrapAlignment.center,
                  children: [
                    if (_aluno.turma != null && _aluno.turma!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: AdventureTheme.skyBlue.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AdventureTheme.skyBlueDark.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          'Turma: ${_aluno.turma}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AdventureTheme.skyBlueDark),
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: AdventureTheme.woodBrown.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AdventureTheme.woodBrown.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        isManual ? 'Sem Tag NFC' : 'Tag: ${_aluno.tagAtualUid ?? _aluno.uid}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AdventureTheme.woodDark),
                      ),
                    ),
                  ],
                ),

                // Gestão de Tag no Modo Professor
                if (PinSecurityService.isModoProfessorAtivo.value) ...[
                  const SizedBox(height: 6),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: isManual ? AdventureTheme.forestGreen : AdventureTheme.woodBrown,
                    ),
                    icon: Icon(isManual ? Icons.add_link : Icons.swap_horiz, size: 16),
                    label: Text(
                      isManual ? 'Cadastrar Tag NFC' : 'Substituir Tag Perdida',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () => _dialogVincularOuTrocarTag(ehSubstituicao: !isManual),
                  ),
                ],
                const SizedBox(height: 14),

                // 3. Baú do Tesouro (Saldo de Talentos)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF9E6),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AdventureTheme.goldCoin, width: 2.5),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AdventureTheme.goldCoin,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AdventureTheme.goldDark, width: 2),
                          boxShadow: const [
                            BoxShadow(color: AdventureTheme.goldDark, offset: Offset(0, 3), blurRadius: 0),
                          ],
                        ),
                        child: const Icon(Icons.monetization_on, color: AdventureTheme.woodDark, size: 30),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'TESOURO NO BAÚ',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1,
                                color: AdventureTheme.woodBrown,
                              ),
                            ),
                            Text(
                              '${_aluno.saldoTalentos} Talentos',
                              style: AdventureTheme.titleFredoka.copyWith(fontSize: 24, color: AdventureTheme.woodDark),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 4. Painel do Professor (quando desbloqueado)
                if (PinSecurityService.isModoProfessorAtivo.value) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AdventureTheme.woodBrown.withValues(alpha: 0.4), width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.military_tech, color: AdventureTheme.forestGreen, size: 18),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Painel do Professor • Recompensas',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AdventureTheme.woodDark),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: AdventureButton(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                backgroundColor: AdventureTheme.forestGreen,
                                borderColor: AdventureTheme.forestGreenDark,
                                onPressed: _loading ? null : () => _adicionarTalentos(1, 'Presença na Escola Sabatina'),
                                child: Column(
                                  children: const [
                                    Text('Presença', style: TextStyle(fontSize: 10, color: Colors.white70)),
                                    Text('+1 🪙', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: AdventureButton(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                backgroundColor: AdventureTheme.skyBlue,
                                borderColor: AdventureTheme.skyBlueDark,
                                onPressed: _loading ? null : () => _adicionarTalentos(2, 'Bíblia / Lição'),
                                child: Column(
                                  children: const [
                                    Text('Bíblia', style: TextStyle(fontSize: 10, color: Colors.white70)),
                                    Text('+2 🪙', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: AdventureButton(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                backgroundColor: AdventureTheme.goldCoin,
                                borderColor: AdventureTheme.goldDark,
                                onPressed: _loading ? null : () => _adicionarTalentos(5, 'Lição Completa'),
                                child: Column(
                                  children: const [
                                    Text('Lição', style: TextStyle(fontSize: 10, color: AdventureTheme.woodDark)),
                                    Text('+5 🪙', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AdventureTheme.woodDark)),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: AdventureButton(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                backgroundColor: AdventureTheme.errorCoral,
                                borderColor: const Color(0xFFB24B32),
                                onPressed: _loading ? null : () => _adicionarTalentos(10, 'Missão / Especial'),
                                child: Column(
                                  children: const [
                                    Text('Missão', style: TextStyle(fontSize: 10, color: Colors.white70)),
                                    Text('+10 🪙', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AdventureTheme.woodBrown, style: BorderStyle.solid),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.tune, size: 16, color: AdventureTheme.woodDark),
                          label: const Text(
                            'Valor Livre (+/-) ou Bonificação',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AdventureTheme.woodDark),
                          ),
                          onPressed: _loading ? null : _abrirAjusteLivre,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                // 5. Histórico de Conquistas
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AdventureTheme.woodDark,
                    side: const BorderSide(color: AdventureTheme.woodBrown),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: Icon(_exibindoHistorico ? Icons.keyboard_arrow_up : Icons.history_edu, size: 18),
                  label: Text(
                    _exibindoHistorico ? 'Ocultar Extrato' : 'Ver Últimas Conquistas',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  onPressed: () {
                    if (_exibindoHistorico) {
                      setState(() => _exibindoHistorico = false);
                    } else {
                      _carregarHistorico();
                    }
                  },
                ),

                if (_exibindoHistorico) ...[
                  const SizedBox(height: 8),
                  if (_historico == null)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(color: AdventureTheme.forestGreen),
                    )
                  else if (_historico!.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(8),
                      child: Text('Nenhuma movimentação ainda.', style: TextStyle(fontSize: 12, color: AdventureTheme.textMuted)),
                    )
                  else
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 180),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _historico!.length,
                        itemBuilder: (ctx, i) {
                          final t = _historico![i];
                          final ehEntrada = t.tipo == 'ENTRADA';
                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AdventureTheme.woodBrown.withValues(alpha: 0.2)),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  ehEntrada ? Icons.add_circle : Icons.remove_circle,
                                  size: 18,
                                  color: ehEntrada ? AdventureTheme.forestGreen : AdventureTheme.errorCoral,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    t.motivo,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AdventureTheme.textDark),
                                  ),
                                ),
                                Text(
                                  '${ehEntrada ? '+' : '-'}${t.quantidade} 🪙',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                    color: ehEntrada ? AdventureTheme.forestGreen : AdventureTheme.errorCoral,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),

        // Presilha Virtual do Crachá no topo
        Positioned(
          top: -34,
          child: Column(
            children: [
              // Fita verde floresta com listras douradas
              Container(
                width: 64,
                height: 24,
                decoration: BoxDecoration(
                  color: AdventureTheme.forestGreen,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                  border: Border.all(color: AdventureTheme.forestGreenDark, width: 2),
                  boxShadow: const [
                    BoxShadow(color: AdventureTheme.woodDark, offset: Offset(0, 2), blurRadius: 0),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Container(width: 4, height: double.infinity, color: AdventureTheme.goldCoin),
                    Container(width: 4, height: double.infinity, color: AdventureTheme.goldCoin),
                  ],
                ),
              ),
              // Clipe metálico dourado
              Container(
                width: 44,
                height: 12,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFE898), AdventureTheme.goldCoin],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AdventureTheme.woodBrown, width: 1.5),
                ),
              ),
              // Furo do crachá
              Container(
                width: 24,
                height: 4,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  color: AdventureTheme.woodDark.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
