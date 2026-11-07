import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../database/models.dart';
import '../database/talentos_repository.dart';
import '../services/nfc_usb_listener.dart';
import '../widgets/aluno_detalhes_modal.dart';
import '../widgets/nova_tag_dialog.dart';
import 'admin_painel_dialog.dart';
import 'feirinha_pdv_screen.dart';

class AlunosScreen extends StatefulWidget {
  final TalentosRepository repository;

  const AlunosScreen({super.key, required this.repository});

  @override
  State<AlunosScreen> createState() => _AlunosScreenState();
}

class _AlunosScreenState extends State<AlunosScreen> {
  late final NfcUsbListener _nfcListener;
  final TextEditingController _searchController = TextEditingController();

  List<AlunoModel> _alunos = [];
  bool _loading = true;
  String _filtro = '';

  @override
  void initState() {
    super.initState();
    _carregarAlunos();

    _nfcListener = NfcUsbListener(onTagScanned: _tratarLeituraTag);
    _nfcListener.start();
  }

  @override
  void dispose() {
    _nfcListener.stop();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _carregarAlunos() async {
    setState(() => _loading = true);
    try {
      final list = await (_filtro.trim().isEmpty
              ? widget.repository.listarAlunos()
              : widget.repository.buscarAlunosPorNome(_filtro.trim()))
          .timeout(const Duration(seconds: 10));
      if (mounted) {
        setState(() {
          _alunos = list;
          _loading = false;
        });
      }
    } catch (e, stack) {
      debugPrint('Erro ao carregar alunos: $e\n$stack');
      if (mounted) {
        setState(() {
          _alunos = [];
          _loading = false;
        });
      }
    }
  }

  Future<void> _tratarLeituraTag(String uid) async {
    // Só processa a leitura se a tela inicial estiver no topo (sem diálogo ou modal aberto)
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;

    debugPrint('NFC Tag Scanned (Tela Inicial): $uid');

    // Se o campo de pesquisa acumulou caracteres da tag enquanto o leitor digitava, limpa
    if (_searchController.text.toUpperCase().contains(uid.toUpperCase())) {
      _searchController.clear();
      _filtro = '';
      _carregarAlunos();
    }

    // Busca o aluno no SQLite
    final aluno = await widget.repository.buscarAlunoPorUid(uid);

    if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;

    if (aluno != null) {
      // 1. Tag já existente -> Abre modal de Perfil com ações rápidas
      AlunoDetalhesModal.show(
        context,
        aluno: aluno,
        repository: widget.repository,
        onDataChanged: _carregarAlunos,
      );
    } else {
      // 2. Tag inédita -> Abre diálogo para Cadastrar ou Vincular
      NovaTagDialog.show(
        context,
        uid: uid,
        repository: widget.repository,
        onSuccess: (alunoCriadoOuVinculado) {
          _carregarAlunos();
          AlunoDetalhesModal.show(
            context,
            aluno: alunoCriadoOuVinculado,
            repository: widget.repository,
            onDataChanged: _carregarAlunos,
          );
        },
      );
    }
  }

  Future<void> _cadastrarAlunoManual() async {
    await showDialog(
      context: context,
      builder: (ctx) => _CadastroAlunoDialog(
        repository: widget.repository,
        onAlunoCadastrado: _carregarAlunos,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestão de Alunos & Talentos'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Sincronização & Painel Admin',
            icon: const Icon(Icons.cloud_sync_rounded),
            onPressed: () {
              AdminPainelDialog.show(
                context,
                repository: widget.repository,
                onDadosAtualizados: _carregarAlunos,
              );
            },
          ),
          IconButton(
            tooltip: 'PDV da Feirinha (Ponto de Venda)',
            icon: const Icon(Icons.storefront_rounded, color: Colors.amber),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => FeirinhaPdvScreen(repository: widget.repository),
                ),
              ).then((_) => _carregarAlunos());
            },
          ),
          IconButton(
            tooltip: 'Simular Leitura NFC (Teste)',
            icon: const Icon(Icons.developer_mode),
            onPressed: () => _nfcListener.simulateScan('041693AB8A2681'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.person_add),
        label: const Text('Novo Aluno'),
        onPressed: _cadastrarAlunoManual,
      ),
      body: Focus(
        autofocus: true,
        canRequestFocus: true,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
            children: [
              // Banner do leitor NFC USB
              _buildNfcBanner(),

              // Barra de Pesquisa e Contador
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Pesquisar por nome...',
                          prefixIcon: const Icon(Icons.search),
                          isDense: true,
                          filled: true,
                          fillColor: const Color(0xFF1E1E1E),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          suffixIcon: _filtro.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    _filtro = '';
                                    _carregarAlunos();
                                  },
                                )
                              : null,
                        ),
                        onChanged: (val) {
                          _filtro = val;
                          _carregarAlunos();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Chip(
                      avatar: const Icon(Icons.people, size: 16),
                      label: Text('${_alunos.length} alunos'),
                    ),
                  ],
                ),
              ),

              // Lista de Alunos
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _alunos.isEmpty
                        ? _buildEmptyState()
                        : RefreshIndicator(
                            onRefresh: _carregarAlunos,
                            child: ListView.builder(
                              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 88, top: 4),
                              itemCount: _alunos.length,
                              itemBuilder: (context, index) {
                                final aluno = _alunos[index];
                                return _buildAlunoCard(aluno);
                              },
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }

  Widget _buildNfcBanner() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.sensors_rounded, color: Colors.amber, size: 24),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Leitor NFC pronto',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.amber),
                ),
                Text(
                  'Aproxime um chaveiro ou cartão para pontuar ou cadastrar.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlunoCard(AlunoModel aluno) {
    final hasNfc = !aluno.uid.startsWith('MANUAL_');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () {
          AlunoDetalhesModal.show(
            context,
            aluno: aluno,
            repository: widget.repository,
            onDataChanged: _carregarAlunos,
          );
        },
        leading: CircleAvatar(
          backgroundColor: Colors.amber.shade800,
          foregroundColor: Colors.black,
          child: Text(
            aluno.nome.isNotEmpty ? aluno.nome[0].toUpperCase() : '?',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          aluno.nome,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Row(
          children: [
            if (aluno.turma != null && aluno.turma!.isNotEmpty) ...[
              Text(aluno.turma!, style: const TextStyle(color: Colors.grey)),
              const Text(' • ', style: TextStyle(color: Colors.grey)),
            ],
            Icon(
              hasNfc ? Icons.nfc : Icons.link_off,
              size: 14,
              color: hasNfc ? Colors.greenAccent : Colors.orangeAccent,
            ),
            const SizedBox(width: 4),
            Text(
              hasNfc ? 'Com Tag' : 'Sem Tag',
              style: TextStyle(
                fontSize: 12,
                color: hasNfc ? Colors.greenAccent : Colors.orangeAccent,
              ),
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black38,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.monetization_on, color: Colors.amber, size: 16),
              const SizedBox(width: 4),
              Text(
                '${aluno.saldoTalentos}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_search, size: 64, color: Colors.grey.shade700),
          const SizedBox(height: 12),
          Text(
            _filtro.isEmpty ? 'Nenhum aluno cadastrado ainda.' : 'Nenhum aluno encontrado.',
            style: const TextStyle(color: Colors.grey, fontSize: 16),
          ),
          const SizedBox(height: 8),
          const Text(
            'Bipe um chaveiro NFC ou clique em "Novo Aluno".',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _CadastroAlunoDialog extends StatefulWidget {
  final TalentosRepository repository;
  final VoidCallback onAlunoCadastrado;

  const _CadastroAlunoDialog({
    required this.repository,
    required this.onAlunoCadastrado,
  });

  @override
  State<_CadastroAlunoDialog> createState() => _CadastroAlunoDialogState();
}

class _CadastroAlunoDialogState extends State<_CadastroAlunoDialog> {
  final _nomeController = TextEditingController();
  final _turmaController = TextEditingController();
  final _uidController = TextEditingController();
  late final NfcUsbListener _nfcListener;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    // Este listener assume o topo da pilha de escuta NFC enquanto o diálogo estiver aberto
    _nfcListener = NfcUsbListener(onTagScanned: (uid) {
      if (mounted) {
        setState(() {
          _uidController.text = uid;
        });
        HapticFeedback.selectionClick();
      }
    });
    _nfcListener.start();
  }

  @override
  void dispose() {
    _nfcListener.stop();
    _nomeController.dispose();
    _turmaController.dispose();
    _uidController.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    final nome = _nomeController.text.trim();
    if (nome.isEmpty) return;

    setState(() => _salvando = true);
    try {
      final uid = _uidController.text.trim().isNotEmpty
          ? _uidController.text.trim().toUpperCase()
          : 'MANUAL_${const Uuid().v4().substring(0, 8).toUpperCase()}';

      final novo = AlunoModel(
        uid: uid,
        nome: nome,
        turma: _turmaController.text.trim().isEmpty ? null : _turmaController.text.trim(),
        saldoTalentos: 0,
        ativo: true,
        updatedAt: DateTime.now().toIso8601String(),
      );

      await widget.repository.cadastrarAluno(novo);
      widget.onAlunoCadastrado();
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _salvando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar aluno: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final temTag = _uidController.text.trim().isNotEmpty;
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.person_add, color: Colors.amber),
          SizedBox(width: 8),
          Text('Cadastrar Novo Aluno'),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nomeController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Nome do Aluno *',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _turmaController,
              decoration: const InputDecoration(
                labelText: 'Turma (ex: Primários, Juvenis)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: temTag ? Colors.green.withValues(alpha: 0.15) : Colors.black26,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: temTag ? Colors.greenAccent : Colors.white24),
              ),
              child: Row(
                children: [
                  Icon(
                    temTag ? Icons.nfc_rounded : Icons.sensors_rounded,
                    color: temTag ? Colors.greenAccent : Colors.amber,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          temTag ? 'Tag Vinculada' : 'Aproxime uma Tag / Chaveiro',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: temTag ? Colors.greenAccent : Colors.amber,
                          ),
                        ),
                        Text(
                          temTag ? _uidController.text : 'Opcional. Se passar a tag agora, ela será vinculada.',
                          style: TextStyle(
                            fontSize: 11,
                            color: temTag ? Colors.white : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (temTag)
                    IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: () => setState(() => _uidController.clear()),
                      tooltip: 'Remover tag',
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _salvando ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _salvando ? null : _salvar,
          child: _salvando
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                )
              : const Text('Salvar'),
        ),
      ],
    );
  }
}
