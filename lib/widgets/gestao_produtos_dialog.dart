import 'package:flutter/material.dart';
import '../database/models.dart';
import '../database/talentos_repository.dart';
import '../services/image_helper_service.dart';
import '../theme/adventure_theme.dart';
import 'pin_auth_dialog.dart';

class GestaoProdutosDialog extends StatefulWidget {
  final TalentosRepository repository;
  final VoidCallback onProdutosChanged;

  const GestaoProdutosDialog({
    super.key,
    required this.repository,
    required this.onProdutosChanged,
  });

  static Future<void> show(
    BuildContext context, {
    required TalentosRepository repository,
    required VoidCallback onProdutosChanged,
  }) async {
    final autorizado = await PinAuthDialog.solicitarPin(
      context,
      titulo: 'Gestão de Produtos',
      subtitulo: 'Digite o PIN para cadastrar e gerenciar produtos',
    );
    if (!autorizado || !context.mounted) return;

    return showDialog(
      context: context,
      builder: (_) => GestaoProdutosDialog(
        repository: repository,
        onProdutosChanged: onProdutosChanged,
      ),
    );
  }

  @override
  State<GestaoProdutosDialog> createState() => _GestaoProdutosDialogState();
}

class _GestaoProdutosDialogState extends State<GestaoProdutosDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _valorController = TextEditingController();
  final _estoqueController = TextEditingController(text: '10');
  String _iconeIdSelecionado = 'lanche';

  List<ProdutoModel> _produtos = [];
  bool _loading = true;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _carregarProdutos();
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _valorController.dispose();
    _estoqueController.dispose();
    super.dispose();
  }

  Future<void> _carregarProdutos() async {
    setState(() => _loading = true);
    final lista = await widget.repository.listarProdutos(apenasDisponiveis: false);
    if (mounted) {
      setState(() {
        _produtos = lista;
        _loading = false;
      });
    }
  }

  Future<void> _salvarNovoProduto() async {
    if (!_formKey.currentState!.validate()) return;

    final nome = _nomeController.text.trim();
    final valor = int.tryParse(_valorController.text.trim()) ?? 0;
    final estoque = int.tryParse(_estoqueController.text.trim()) ?? 0;

    setState(() => _salvando = true);
    try {
      final novo = ProdutoModel(
        nome: nome,
        valorTalentos: valor,
        estoque: estoque,
        esgotado: estoque <= 0,
        iconeId: _iconeIdSelecionado,
        updatedAt: DateTime.now().toIso8601String(),
      );

      await widget.repository.criarProduto(novo);

      _nomeController.clear();
      _valorController.clear();
      _estoqueController.text = '10';

      widget.onProdutosChanged();
      await _carregarProdutos();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Produto cadastrado na Feirinha com sucesso!'),
            backgroundColor: AdventureTheme.forestGreen,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar: $e'), backgroundColor: AdventureTheme.errorCoral),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _salvando = false);
      }
    }
  }

  Future<void> _alternarEsgotado(ProdutoModel produto) async {
    if (produto.id == null) return;
    final novoStatus = !produto.esgotado;
    await widget.repository.alternarStatusEsgotado(produto.id!, novoStatus);
    widget.onProdutosChanged();
    await _carregarProdutos();
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
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: bgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: borderColor, width: 2.5),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 720),
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
                      color: AdventureTheme.goldCoin,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AdventureTheme.goldDark, width: 2),
                    ),
                    child: const Icon(Icons.storefront_rounded, color: AdventureTheme.woodDark, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Gestão de Produtos',
                          style: AdventureTheme.titleFredoka.copyWith(
                            fontSize: 18,
                            color: textColor,
                          ),
                        ),
                        Text(
                          'Vitrine & Estoque da Feirinha',
                          style: AdventureTheme.bodyNunito.copyWith(
                            fontSize: 12,
                            color: textMuted,
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

              // Formulário de Cadastro Rápido
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor.withValues(alpha: 0.4)),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Cadastrar Novo Item',
                            style: AdventureTheme.titleFredoka.copyWith(
                              fontSize: 14,
                              color: AdventureTheme.goldDark,
                            ),
                          ),
                          const Spacer(),
                          // Seletor de Ícone
                          DropdownButton<String>(
                            value: _iconeIdSelecionado,
                            underline: const SizedBox(),
                            isDense: true,
                            dropdownColor: cardBg,
                            items: ImageHelperService.iconesProduto.entries.map((e) {
                              return DropdownMenuItem<String>(
                                value: e.key,
                                child: Text('${e.value.emoji} ${e.value.nome}', style: TextStyle(color: textColor, fontSize: 13)),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _iconeIdSelecionado = val);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isCompact = constraints.maxWidth < 500;
                          if (isCompact) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TextFormField(
                                  controller: _nomeController,
                                  style: TextStyle(color: textColor),
                                  decoration: InputDecoration(
                                    labelText: 'Nome do Item *',
                                    isDense: true,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  validator: (v) =>
                                      (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _valorController,
                                        keyboardType: TextInputType.number,
                                        style: TextStyle(color: textColor),
                                        decoration: InputDecoration(
                                          labelText: 'Preço (T) *',
                                          isDense: true,
                                          prefixText: '🪙 ',
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                        validator: (v) {
                                          final val = int.tryParse(v ?? '');
                                          if (val == null || val <= 0) return 'Valor > 0';
                                          return null;
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _estoqueController,
                                        keyboardType: TextInputType.number,
                                        style: TextStyle(color: textColor),
                                        decoration: InputDecoration(
                                          labelText: 'Estoque Inicial',
                                          isDense: true,
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                AdventureButton(
                                  onPressed: _salvando ? null : _salvarNovoProduto,
                                  backgroundColor: AdventureTheme.forestGreen,
                                  borderColor: AdventureTheme.forestGreenDark,
                                  shadowColor: isDark ? Colors.black54 : AdventureTheme.woodDark,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _salvando
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                            )
                                          : const Icon(Icons.add, color: Colors.white, size: 18),
                                      const SizedBox(width: 6),
                                      const Text(
                                        'Cadastrar Item na Feirinha',
                                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }

                          return Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  controller: _nomeController,
                                  style: TextStyle(color: textColor),
                                  decoration: InputDecoration(
                                    labelText: 'Nome do Item *',
                                    isDense: true,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  validator: (v) =>
                                      (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: _valorController,
                                  keyboardType: TextInputType.number,
                                  style: TextStyle(color: textColor),
                                  decoration: InputDecoration(
                                    labelText: 'Preço (T) *',
                                    isDense: true,
                                    prefixText: '🪙 ',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  validator: (v) {
                                    final val = int.tryParse(v ?? '');
                                    if (val == null || val <= 0) return 'Valor > 0';
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: _estoqueController,
                                  keyboardType: TextInputType.number,
                                  style: TextStyle(color: textColor),
                                  decoration: InputDecoration(
                                    labelText: 'Estoque',
                                    isDense: true,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              AdventureButton(
                                onPressed: _salvando ? null : _salvarNovoProduto,
                                backgroundColor: AdventureTheme.forestGreen,
                                borderColor: AdventureTheme.forestGreenDark,
                                shadowColor: isDark ? Colors.black54 : AdventureTheme.woodDark,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                borderRadius: 12,
                                child: _salvando
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Icon(Icons.add, color: Colors.white, size: 20),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
              Divider(color: borderColor.withValues(alpha: 0.3)),
              const SizedBox(height: 8),

              // Título da Lista
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Produtos no Catálogo',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor),
                  ),
                  Text(
                    '${_produtos.length} itens cadastrados',
                    style: TextStyle(color: textMuted, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Lista de Produtos
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _produtos.isEmpty
                        ? Center(
                            child: Text(
                              'Nenhum produto cadastrado na feirinha.',
                              style: TextStyle(color: textMuted),
                            ),
                          )
                        : ListView.separated(
                            itemCount: _produtos.length,
                            separatorBuilder: (_, _) => Divider(color: borderColor.withValues(alpha: 0.2), height: 1),
                            itemBuilder: (context, index) {
                              final p = _produtos[index];
                              return Container(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                decoration: BoxDecoration(
                                  color: cardBg,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: borderColor.withValues(alpha: 0.25)),
                                ),
                                child: ListTile(
                                  dense: true,
                                  leading: CircleAvatar(
                                    backgroundColor: p.esgotado
                                        ? Colors.grey.shade400
                                        : AdventureTheme.goldCoin.withValues(alpha: 0.2),
                                    foregroundColor: AdventureTheme.goldDark,
                                    child: Text(
                                      ImageHelperService.iconesProduto[p.iconeId]?.emoji ?? '🎁',
                                      style: const TextStyle(fontSize: 18),
                                    ),
                                  ),
                                  title: Text(
                                    p.nome,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      decoration: p.esgotado ? TextDecoration.lineThrough : null,
                                      color: p.esgotado ? textMuted : textColor,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Preço: ${p.valorTalentos}🪙 | Estoque: ${p.estoque} | ${p.esgotado ? "Esgotado" : "Disponível"}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: p.esgotado ? AdventureTheme.errorCoral : textMuted,
                                    ),
                                  ),
                                  trailing: Switch(
                                    value: !p.esgotado,
                                    activeTrackColor: AdventureTheme.forestGreen,
                                    inactiveTrackColor: AdventureTheme.errorCoral.withValues(alpha: 0.3),
                                    onChanged: (_) => _alternarEsgotado(p),
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
