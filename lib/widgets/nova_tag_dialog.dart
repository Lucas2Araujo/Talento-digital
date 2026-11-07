import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database/models.dart';
import '../database/talentos_repository.dart';
import '../services/nfc_usb_listener.dart';

class NovaTagDialog extends StatefulWidget {
  final String uid;
  final TalentosRepository repository;
  final void Function(AlunoModel alunoCriadoOuVinculado) onSuccess;

  const NovaTagDialog({
    super.key,
    required this.uid,
    required this.repository,
    required this.onSuccess,
  });

  static Future<void> show(
    BuildContext context, {
    required String uid,
    required TalentosRepository repository,
    required void Function(AlunoModel aluno) onSuccess,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => NovaTagDialog(
        uid: uid,
        repository: repository,
        onSuccess: onSuccess,
      ),
    );
  }

  @override
  State<NovaTagDialog> createState() => _NovaTagDialogState();
}

class _NovaTagDialogState extends State<NovaTagDialog> {
  late String _uid;
  late final NfcUsbListener _nfcListener;
  bool _abaVincular = false;
  final _nomeController = TextEditingController();
  final _turmaController = TextEditingController();

  List<AlunoModel>? _alunosSemTag;
  AlunoModel? _alunoSelecionadoParaVincular;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _uid = widget.uid;
    _nfcListener = NfcUsbListener(onTagScanned: (newUid) {
      if (mounted) {
        setState(() {
          _uid = newUid;
        });
        HapticFeedback.selectionClick();
      }
    });
    _nfcListener.start();
    _carregarAlunosSemTag();
  }

  @override
  void dispose() {
    _nfcListener.stop();
    _nomeController.dispose();
    _turmaController.dispose();
    super.dispose();
  }

  Future<void> _carregarAlunosSemTag() async {
    try {
      final list = await widget.repository
          .listarAlunosSemTag()
          .timeout(const Duration(seconds: 6));
      if (mounted) {
        setState(() => _alunosSemTag = list);
      }
    } catch (e) {
      debugPrint('Erro ao carregar alunos sem tag: $e');
      if (mounted) {
        setState(() => _alunosSemTag = []);
      }
    }
  }

  Future<void> _salvarNovoAluno() async {
    final nome = _nomeController.text.trim();
    if (nome.isEmpty) return;

    setState(() => _salvando = true);
    try {
      final novo = AlunoModel(
        uid: _uid,
        nome: nome,
        turma: _turmaController.text.trim().isEmpty ? null : _turmaController.text.trim(),
        saldoTalentos: 0,
        ativo: true,
        updatedAt: DateTime.now().toIso8601String(),
      );

      await widget.repository.cadastrarAluno(novo);

      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess(novo);
      }
    } catch (e) {
      debugPrint('Erro ao salvar aluno: $e');
      if (mounted) {
        setState(() => _salvando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar no banco: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _vincularAlunoExistente() async {
    if (_alunoSelecionadoParaVincular == null) return;
    setState(() => _salvando = true);

    try {
      await widget.repository.vincularTagAoAluno(
        uidAntigo: _alunoSelecionadoParaVincular!.uid,
        novoUidTag: _uid,
      );

      final atualizado = await widget.repository.buscarAlunoPorUid(_uid);

      if (mounted && atualizado != null) {
        Navigator.pop(context);
        widget.onSuccess(atualizado);
      }
    } catch (e) {
      debugPrint('Erro ao vincular tag: $e');
      if (mounted) {
        setState(() => _salvando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao vincular tag: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.nfc_rounded, color: Colors.amber),
          const SizedBox(width: 10),
          const Expanded(child: Text('Nova Tag Detectada')),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: SelectableText(
                'UID: $_uid',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),

            // Abas de seleção de fluxo
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  label: Text('Cadastrar Novo'),
                  icon: Icon(Icons.person_add),
                ),
                ButtonSegment(
                  value: true,
                  label: Text('Vincular a Aluno'),
                  icon: Icon(Icons.link),
                ),
              ],
              selected: {_abaVincular},
              onSelectionChanged: (val) {
                setState(() => _abaVincular = val.first);
              },
            ),
            const SizedBox(height: 16),

            if (!_abaVincular) ...[
              TextField(
                controller: _nomeController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Nome da Criança *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _turmaController,
                decoration: const InputDecoration(
                  labelText: 'Turma (ex: Primários, Juvenis)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.class_),
                ),
              ),
            ] else ...[
              if (_alunosSemTag == null)
                const Center(child: CircularProgressIndicator())
              else if (_alunosSemTag!.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: Text(
                    'Não há alunos cadastrados sem tag.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              else
                DropdownButtonFormField<AlunoModel>(
                  initialValue: _alunoSelecionadoParaVincular,
                  decoration: const InputDecoration(
                    labelText: 'Selecione o Aluno',
                    border: OutlineInputBorder(),
                  ),
                  items: _alunosSemTag!.map((a) {
                    final turmaStr = a.turma != null ? ' (${a.turma})' : '';
                    return DropdownMenuItem(
                      value: a,
                      child: Text('${a.nome}$turmaStr'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() => _alunoSelecionadoParaVincular = val);
                  },
                ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _salvando ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _salvando
              ? null
              : (_abaVincular ? _vincularAlunoExistente : _salvarNovoAluno),
          child: _salvando
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_abaVincular ? 'Vincular' : 'Cadastrar'),
        ),
      ],
    );
  }
}
