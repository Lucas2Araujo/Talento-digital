import 'package:flutter/material.dart';
import '../database/models.dart';
import '../database/talentos_repository.dart';
import '../services/image_helper_service.dart';
import '../services/nfc_usb_listener.dart';
import '../services/pin_security_service.dart';
import '../theme/adventure_theme.dart';
import '../widgets/aluno_detalhes_modal.dart';
import '../widgets/nova_tag_dialog.dart';
import '../widgets/pin_auth_dialog.dart';
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
  String? _turmaFiltro;

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
          : widget.repository.buscarAlunosPorNome(_filtro.trim()));
      if (mounted) {
        setState(() {
          _alunos = list;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _tratarLeituraTag(String uid) async {
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;

    if (_searchController.text.toUpperCase().contains(uid.toUpperCase())) {
      _searchController.clear();
      _filtro = '';
      _carregarAlunos();
    }

    final buscaResult = await widget.repository.buscarAlunoPorTag(uid);
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;

    if (buscaResult is BuscaTagResultEncontradoAtivo) {
      AlunoDetalhesModal.show(
        context,
        aluno: buscaResult.aluno,
        repository: widget.repository,
        onDataChanged: _carregarAlunos,
      );
    } else if (buscaResult is BuscaTagResultEncontradoExtraviado) {
      _exibirModalTagExtraviada(buscaResult.antigoDono, buscaResult.tagLida);
    } else {
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

  Future<void> _exibirModalTagExtraviada(
      AlunoModel antigoDono, String tagLida) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AdventureTheme.woodBrown, width: 2.5),
        ),
        backgroundColor: AdventureTheme.surface,
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Cartão Antigo / Extraviado',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Opa! Este cartão pertencia a ${antigoDono.nome} e foi substituído anteriormente.',
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Text(
                'Tag NFC: $tagLida\nDono anterior: ${antigoDono.nome} (${antigoDono.turma ?? "Sem turma"})',
                style: TextStyle(
                    fontSize: 13,
                    fontFamily: 'monospace',
                    color: Colors.amber.shade900),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'O que deseja fazer?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AdventureTheme.forestGreen,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final autorizado = await PinAuthDialog.solicitarPin(
                context,
                titulo: 'Autorização do Professor',
                subtitulo: 'Digite o PIN para reativar cartão para ${antigoDono.nome}',
              );
              if (autorizado) {
                await widget.repository.reativarTagAntiga(
                  alunoUid: antigoDono.uid,
                  tagUid: tagLida,
                );
                _carregarAlunos();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Cartão $tagLida reativado com sucesso para ${antigoDono.nome}!'),
                      backgroundColor: AdventureTheme.forestGreen,
                    ),
                  );
                }
              }
            },
            child: Text('Reativar para ${antigoDono.nome}'),
          ),
          OutlinedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final autorizado = await PinAuthDialog.solicitarPin(
                context,
                titulo: 'Autorização do Professor',
                subtitulo: 'Digite o PIN para vincular este cartão a outro aluno',
              );
              if (autorizado && mounted) {
                NovaTagDialog.show(
                  context,
                  uid: tagLida,
                  repository: widget.repository,
                  onSuccess: (aluno) {
                    _carregarAlunos();
                  },
                );
              }
            },
            child: const Text('Vincular a outro aluno'),
          ),
        ],
      ),
    );
  }

  Future<void> _cadastrarAlunoManual() async {
    final nomeCtrl = TextEditingController();
    final turmaCtrl = TextEditingController();
    String avatarSorteado = ImageHelperService.sortearAvatar();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AdventureTheme.woodBrown, width: 2.5),
          ),
          backgroundColor: AdventureTheme.surface,
          title: Text('Novo Explorador', style: AdventureTheme.titleFredoka.copyWith(fontSize: 18)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () => setDlg(() => avatarSorteado = ImageHelperService.sortearAvatar()),
                child: Column(
                  children: [
                    ImageHelperService.buildAvatarWidget(
                      avatarId: avatarSorteado,
                      nome: nomeCtrl.text,
                      size: 72,
                    ),
                    const SizedBox(height: 4),
                    const Text('Toque para trocar animal', style: TextStyle(fontSize: 11, color: AdventureTheme.woodBrown)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nomeCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Nome Completo',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: turmaCtrl,
                decoration: InputDecoration(
                  labelText: 'Turma (ex: Primários, Juvenis)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                final nome = nomeCtrl.text.trim();
                if (nome.isEmpty) return;
                Navigator.pop(ctx);
                final manualUid = 'MANUAL_${DateTime.now().millisecondsSinceEpoch}';
                await widget.repository.cadastrarAluno(
                  AlunoModel(
                    uid: manualUid,
                    tagAtualUid: manualUid,
                    nome: nome,
                    turma: turmaCtrl.text.trim().isEmpty ? null : turmaCtrl.text.trim(),
                    avatarId: avatarSorteado,
                    updatedAt: DateTime.now().toIso8601String(),
                  ),
                );
                _carregarAlunos();
              },
              child: const Text('Cadastrar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final turmas = _alunos.map((a) => a.turma).where((t) => t != null && t.isNotEmpty).toSet().toList();
    final alunosFiltrados = _turmaFiltro == null
        ? _alunos
        : _alunos.where((a) => a.turma == _turmaFiltro).toList();

    return Scaffold(
      backgroundColor: AdventureTheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Banner Sandbox
            if (widget.repository.isSandboxMode)
              Container(
                width: double.infinity,
                color: Colors.orange.shade800,
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.science, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text(
                      '🧪 MODO DEMONSTRAÇÃO / TESTES ATIVO (Dados em memória)',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ],
                ),
              ),

            // 1. Header Unificado Stitch
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                color: AdventureTheme.surface,
                border: Border(bottom: BorderSide(color: AdventureTheme.woodBrown, width: 2.5)),
              ),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  // Logo + Título
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AdventureTheme.goldCoin,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AdventureTheme.goldDark, width: 2),
                          boxShadow: const [
                            BoxShadow(color: AdventureTheme.woodDark, offset: Offset(0, 2), blurRadius: 0),
                          ],
                        ),
                        child: const Icon(Icons.monetization_on, color: AdventureTheme.woodDark, size: 26),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Talento Digital', style: AdventureTheme.titleFredoka.copyWith(fontSize: 18)),
                          const Text('Aventureiros & Exploradores', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AdventureTheme.woodBrown)),
                        ],
                      ),
                    ],
                  ),

                  // Chave Central Estilo Pílula
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFE3C3),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: AdventureTheme.woodBrown, width: 1.8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: AdventureTheme.forestGreen,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AdventureTheme.forestGreenDark, width: 1),
                          ),
                          child: Row(
                            children: const [
                              Icon(Icons.groups, size: 16, color: Colors.white),
                              SizedBox(width: 4),
                              Text('Exploradores', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => FeirinhaPdvScreen(repository: widget.repository),
                              ),
                            ).then((_) => _carregarAlunos());
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            child: Row(
                              children: const [
                                Icon(Icons.storefront, size: 16, color: AdventureTheme.woodDark),
                                SizedBox(width: 4),
                                Text('Vitrine Feirinha', style: TextStyle(color: AdventureTheme.woodDark, fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Modo Professor / Admin e Botão Painel
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ValueListenableBuilder<bool>(
                        valueListenable: PinSecurityService.isModoProfessorAtivo,
                        builder: (context, isProfessor, _) {
                          return AdventureButton(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            backgroundColor: isProfessor ? AdventureTheme.forestGreen : Colors.white,
                            borderColor: isProfessor ? AdventureTheme.forestGreenDark : AdventureTheme.woodBrown,
                            shadowColor: AdventureTheme.woodDark,
                            borderRadius: 20,
                            onPressed: () async {
                              if (isProfessor) {
                                PinSecurityService.isModoProfessorAtivo.value = false;
                              } else {
                                final autorizado = await PinAuthDialog.solicitarPin(
                                  context,
                                  titulo: 'Acesso do Professor',
                                  subtitulo: 'Digite o PIN para liberar edições',
                                );
                                if (autorizado) PinSecurityService.isModoProfessorAtivo.value = true;
                              }
                            },
                            child: Row(
                              children: [
                                Icon(
                                  isProfessor ? Icons.lock_open_rounded : Icons.lock_rounded,
                                  size: 16,
                                  color: isProfessor ? Colors.white : AdventureTheme.woodDark,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  isProfessor ? 'Professor 🔓' : 'Consulta 🔒',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isProfessor ? Colors.white : AdventureTheme.woodDark,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Painel Admin',
                        icon: const Icon(Icons.settings, color: AdventureTheme.woodDark),
                        onPressed: () {
                          AdminPainelDialog.show(
                            context,
                            repository: widget.repository,
                            onDadosAtualizados: _carregarAlunos,
                          );
                        },
                      ),
                      // Toggle de Tema (Claro / Escuro / Sistema)
                      ValueListenableBuilder<ThemeMode>(
                        valueListenable: AdventureTheme.themeModeNotifier,
                        builder: (context, mode, _) {
                          IconData icone;
                          String tooltip;
                          switch (mode) {
                            case ThemeMode.system:
                              icone = Icons.brightness_auto_rounded;
                              tooltip = 'Tema: Automático (Sistema)';
                              break;
                            case ThemeMode.light:
                              icone = Icons.light_mode_rounded;
                              tooltip = 'Tema: Claro';
                              break;
                            case ThemeMode.dark:
                              icone = Icons.dark_mode_rounded;
                              tooltip = 'Tema: Escuro';
                              break;
                          }
                          return IconButton(
                            tooltip: tooltip,
                            icon: Icon(icone, color: AdventureTheme.woodDark),
                            onPressed: () {
                              AdventureTheme.alternarTemaRapido();
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Corpo Scrollável
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 2. Hero Banner ("Cartão Mágico NFC")
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AdventureTheme.forestGreen, AdventureTheme.skyBlue],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AdventureTheme.woodBrown, width: 3),
                        boxShadow: const [
                          BoxShadow(color: AdventureTheme.woodDark, offset: Offset(0, 6), blurRadius: 0),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Disco Pulsante NFC
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: AdventureTheme.goldCoin, width: 3.5),
                              boxShadow: const [
                                BoxShadow(color: Colors.black26, blurRadius: 8),
                              ],
                            ),
                            child: const Icon(Icons.contactless, color: AdventureTheme.forestGreenDark, size: 34),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Aproxime seu Cartão Mágico NFC!',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Encoste no leitor para abrir seu crachá e ver seus talentos.',
                                  style: TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          if (widget.repository.isSandboxMode)
                            AdventureButton(
                              backgroundColor: AdventureTheme.goldCoin,
                              borderColor: AdventureTheme.goldDark,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              onPressed: () => _nfcListener.simulateScan('DEMO_1'),
                              child: const Text('Simular Toque', style: TextStyle(color: AdventureTheme.woodDark, fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 3. Barra de Pesquisa e Filtros por Turma
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            onChanged: (val) {
                              _filtro = val;
                              _carregarAlunos();
                            },
                            decoration: InputDecoration(
                              hintText: 'Buscar explorador pelo nome...',
                              prefixIcon: const Icon(Icons.search, color: AdventureTheme.woodBrown),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30),
                                borderSide: const BorderSide(color: AdventureTheme.woodBrown, width: 2),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30),
                                borderSide: const BorderSide(color: AdventureTheme.woodBrown, width: 1.8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Chips de Turmas
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ChoiceChip(
                            label: Text('Todos (${_alunos.length})'),
                            selected: _turmaFiltro == null,
                            selectedColor: AdventureTheme.woodBrown,
                            labelStyle: TextStyle(
                              color: _turmaFiltro == null ? Colors.white : AdventureTheme.woodDark,
                              fontWeight: FontWeight.bold,
                            ),
                            onSelected: (_) => setState(() => _turmaFiltro = null),
                          ),
                          const SizedBox(width: 6),
                          for (final t in turmas)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: Text(t!),
                                selected: _turmaFiltro == t,
                                selectedColor: AdventureTheme.skyBlue,
                                labelStyle: TextStyle(
                                  color: _turmaFiltro == t ? Colors.white : AdventureTheme.woodDark,
                                  fontWeight: FontWeight.bold,
                                ),
                                onSelected: (_) => setState(() => _turmaFiltro = t),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 4. Grid de Crachás de Explorador
                    if (_loading)
                      const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: AdventureTheme.forestGreen)))
                    else
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 220,
                          mainAxisExtent: 240,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                        ),
                        itemCount: alunosFiltrados.length + 1, // +1 para o card tracejado de novo aluno
                        itemBuilder: (ctx, i) {
                          if (i == alunosFiltrados.length) {
                            // Card Tracejado Novo Explorador
                            return GestureDetector(
                              onTap: _cadastrarAlunoManual,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: AdventureTheme.woodBrown, width: 2, style: BorderStyle.solid),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(Icons.add_circle_outline, size: 40, color: AdventureTheme.forestGreen),
                                    SizedBox(height: 8),
                                    Text('Novo Explorador', style: TextStyle(fontWeight: FontWeight.bold, color: AdventureTheme.woodDark)),
                                  ],
                                ),
                              ),
                            );
                          }

                          final a = alunosFiltrados[i];
                          final nivel = (a.saldoTalentos ~/ 20) + 1;

                          return AdventureCard(
                            onTap: () {
                              AlunoDetalhesModal.show(
                                context,
                                aluno: a,
                                repository: widget.repository,
                                onDataChanged: _carregarAlunos,
                              );
                            },
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Avatar com badge de nível
                                Stack(
                                  alignment: Alignment.bottomRight,
                                  children: [
                                    ImageHelperService.buildAvatarWidget(
                                      fotoBase64: a.fotoBase64,
                                      avatarId: a.avatarId,
                                      nome: a.nome,
                                      size: 72,
                                      borderWidth: 3.5,
                                      borderColor: AdventureTheme.goldCoin,
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AdventureTheme.goldCoin,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: AdventureTheme.woodBrown, width: 1.5),
                                      ),
                                      child: Text(
                                        'Lvl $nivel',
                                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AdventureTheme.woodDark),
                                      ),
                                    ),
                                  ],
                                ),
                                // Nome
                                Text(
                                  a.nome,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: AdventureTheme.titleFredoka.copyWith(fontSize: 15),
                                ),
                                // Badge Turma
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AdventureTheme.skyBlue.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AdventureTheme.skyBlueDark.withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    a.turma ?? 'Sem turma',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AdventureTheme.skyBlueDark),
                                  ),
                                ),
                                // Pílula Dourada de Talentos
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF9E6),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: AdventureTheme.goldCoin, width: 1.5),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.monetization_on, color: AdventureTheme.goldDark, size: 16),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${a.saldoTalentos} Talentos',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 12,
                                          color: AdventureTheme.woodDark,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),

            // Footer de Status Marrom
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AdventureTheme.woodBrown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.nfc, size: 16, color: Colors.white70),
                      SizedBox(width: 6),
                      Text('Leitor NFC Ativo • 13.56 MHz', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Text(
                    'Total: ${_alunos.fold<int>(0, (acc, a) => acc + a.saldoTalentos)} 🪙 em circulação',
                    style: const TextStyle(color: AdventureTheme.goldCoin, fontSize: 11, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
