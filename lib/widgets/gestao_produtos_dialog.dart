import 'package:flutter/material.dart';
import '../database/models.dart';
import '../database/talentos_repository.dart';
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
            content: Text('Produto cadastrado com sucesso!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar: $e'), backgroundColor: Colors.red),
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
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                  const Icon(Icons.inventory_2_rounded, color: Colors.amber),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Gestão de Produtos da Feirinha',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Formulário de Cadastro Rápido
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Cadastrar Novo Item',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.amber),
                    ),
                    const SizedBox(height: 10),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isCompact = constraints.maxWidth < 500;
                        if (isCompact) {
                          // Layout Vertical para celular e tablet compacto
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextFormField(
                                controller: _nomeController,
                                decoration: const InputDecoration(
                                  labelText: 'Nome do Item *',
                                  isDense: true,
                                  border: OutlineInputBorder(),
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
                                      decoration: const InputDecoration(
                                        labelText: 'Preço (T) *',
                                        isDense: true,
                                        prefixText: 'T ',
                                        border: OutlineInputBorder(),
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
                                      decoration: const InputDecoration(
                                        labelText: 'Estoque Inicial',
                                        isDense: true,
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              FilledButton.icon(
                                onPressed: _salvando ? null : _salvarNovoProduto,
                                icon: _salvando
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.black,
                                        ),
                                      )
                                    : const Icon(Icons.add),
                                label: const Text('Cadastrar Item na Feirinha'),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ],
                          );
                        }

                        // Layout Horizontal para telas largas / PC
                        return Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: _nomeController,
                                decoration: const InputDecoration(
                                  labelText: 'Nome do Item *',
                                  isDense: true,
                                  border: OutlineInputBorder(),
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
                                decoration: const InputDecoration(
                                  labelText: 'Preço (T) *',
                                  isDense: true,
                                  prefixText: 'T ',
                                  border: OutlineInputBorder(),
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
                                decoration: const InputDecoration(
                                  labelText: 'Estoque',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilledButton.icon(
                              onPressed: _salvando ? null : _salvarNovoProduto,
                              icon: _salvando
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.add),
                              label: const Text('Add'),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),

              // Título da Lista
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Produtos Cadastrados',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  Text(
                    '${_produtos.length} itens',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Lista de Produtos
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _produtos.isEmpty
                        ? const Center(
                            child: Text(
                              'Nenhum produto cadastrado.',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView.separated(
                            itemCount: _produtos.length,
                            separatorBuilder: (_, _) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final p = _produtos[index];
                              return ListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                                leading: CircleAvatar(
                                  backgroundColor: p.esgotado
                                      ? Colors.grey.shade800
                                      : Colors.amber.shade900,
                                  foregroundColor: p.esgotado ? Colors.grey : Colors.amber,
                                  child: Text(
                                    '${p.valorTalentos}T',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  p.nome,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    decoration: p.esgotado ? TextDecoration.lineThrough : null,
                                    color: p.esgotado ? Colors.grey : Colors.white,
                                  ),
                                ),
                                subtitle: Text(
                                  'Estoque: ${p.estoque} | ${p.esgotado ? "Esgotado" : "Disponível"}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: p.esgotado ? Colors.redAccent : Colors.grey,
                                  ),
                                ),
                                trailing: Switch(
                                  value: !p.esgotado,
                                  activeThumbColor: Colors.greenAccent,
                                  inactiveThumbColor: Colors.redAccent,
                                  inactiveTrackColor: Colors.redAccent.withValues(alpha: 0.2),
                                  onChanged: (_) => _alternarEsgotado(p),
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
