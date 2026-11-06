import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database/models.dart';
import '../database/talentos_repository.dart';
import '../services/nfc_usb_listener.dart';
import '../widgets/gestao_produtos_dialog.dart';
import '../widgets/pdv_checkout_dialog.dart';
import 'admin_painel_dialog.dart';

class CartItem {
  final ProdutoModel? produto;
  final String descricao;
  final int precoUnitario;
  int quantidade;

  CartItem({
    this.produto,
    required this.descricao,
    required this.precoUnitario,
    this.quantidade = 1,
  });

  int get total => precoUnitario * quantidade;

  ItemVendaDto toDto() => ItemVendaDto(
        produtoId: produto?.id,
        descricaoLivre: produto == null ? descricao : null,
        quantidade: quantidade,
        precoUnitario: precoUnitario,
      );
}

class FeirinhaPdvScreen extends StatefulWidget {
  final TalentosRepository repository;

  const FeirinhaPdvScreen({super.key, required this.repository});

  @override
  State<FeirinhaPdvScreen> createState() => _FeirinhaPdvScreenState();
}

class _FeirinhaPdvScreenState extends State<FeirinhaPdvScreen> {
  late final NfcUsbListener _nfcListener;

  // Lista de produtos do catálogo
  List<ProdutoModel> _produtos = [];
  bool _carregandoProdutos = true;

  // Itens no carrinho
  final List<CartItem> _carrinho = [];

  // Modo de seleção (0: Catálogo, 1: Valor Livre)
  int _modoSelecionado = 0;

  // Estado do Modo Valor Livre
  String _valorLivreDisplay = '0';
  final TextEditingController _descLivreController = TextEditingController(text: 'Compra Rápida');

  @override
  void initState() {
    super.initState();
    _carregarProdutos();

    _nfcListener = NfcUsbListener(onTagScanned: _tratarLeituraTag);
    _nfcListener.start();
  }

  @override
  void dispose() {
    _nfcListener.stop();
    _descLivreController.dispose();
    super.dispose();
  }

  Future<void> _carregarProdutos() async {
    setState(() => _carregandoProdutos = true);
    try {
      final list = await widget.repository.listarProdutos(apenasDisponiveis: false);
      if (mounted) {
        setState(() {
          _produtos = list;
          _carregandoProdutos = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _carregandoProdutos = false);
      }
    }
  }

  Future<void> _tratarLeituraTag(String uid) async {
    final aluno = await widget.repository.buscarAlunoPorUid(uid);
    if (!mounted) return;

    if (_carrinho.isEmpty) {
      // Se carrinho vazio, apenas avisa sobre o saldo da criança
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            aluno != null
                ? 'Aluno: ${aluno.nome} | Saldo: ${aluno.saldoTalentos}T (Carrinho vazio)'
                : 'Tag não cadastrada: $uid',
          ),
          backgroundColor: Colors.amber.shade900,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Se carrinho já contém itens, inicia o checkout direto com este aluno!
    _abrirCheckout(alunoPreSelecionado: aluno);
  }

  int get _totalTalentos => _carrinho.fold(0, (acc, item) => acc + item.total);

  // ----------------------------------------------------
  // GESTÃO DO CARRINHO
  // ----------------------------------------------------

  void _adicionarAoCarrinho(ProdutoModel produto) {
    if (produto.esgotado || produto.estoque <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Item esgotado no momento!'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    HapticFeedback.lightImpact();
    setState(() {
      final index = _carrinho.indexWhere((it) => it.produto?.id == produto.id);
      if (index >= 0) {
        final atual = _carrinho[index];
        if (atual.quantidade < produto.estoque) {
          atual.quantidade++;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Estoque máximo de ${produto.nome} atingido (${produto.estoque})'),
              backgroundColor: Colors.orange.shade800,
              duration: const Duration(seconds: 1),
            ),
          );
        }
      } else {
        _carrinho.add(
          CartItem(
            produto: produto,
            descricao: produto.nome,
            precoUnitario: produto.valorTalentos,
            quantidade: 1,
          ),
        );
      }
    });
  }

  void _incrementarItem(CartItem item) {
    if (item.produto != null && item.quantidade >= item.produto!.estoque) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Estoque máximo de ${item.produto!.nome} atingido'),
          backgroundColor: Colors.orange.shade800,
          duration: const Duration(seconds: 1),
        ),
      );
      return;
    }
    setState(() => item.quantidade++);
  }

  void _decrementarItem(CartItem item) {
    setState(() {
      if (item.quantidade > 1) {
        item.quantidade--;
      } else {
        _carrinho.remove(item);
      }
    });
  }

  void _removerItem(CartItem item) {
    setState(() => _carrinho.remove(item));
  }

  void _limparCarrinho() {
    if (_carrinho.isEmpty) return;
    setState(() => _carrinho.clear());
  }

  // ----------------------------------------------------
  // MODO VALOR LIVRE
  // ----------------------------------------------------

  void _teclaNumerica(String digito) {
    setState(() {
      if (_valorLivreDisplay == '0') {
        _valorLivreDisplay = digito;
      } else if (_valorLivreDisplay.length < 5) {
        _valorLivreDisplay += digito;
      }
    });
  }

  void _limparDisplayValorLivre() {
    setState(() => _valorLivreDisplay = '0');
  }

  void _apagarDigitoValorLivre() {
    setState(() {
      if (_valorLivreDisplay.length > 1) {
        _valorLivreDisplay = _valorLivreDisplay.substring(0, _valorLivreDisplay.length - 1);
      } else {
        _valorLivreDisplay = '0';
      }
    });
  }

  void _adicionarPresetValorLivre(int delta) {
    final atual = int.tryParse(_valorLivreDisplay) ?? 0;
    final novo = (atual + delta).clamp(0, 9999);
    setState(() => _valorLivreDisplay = novo.toString());
  }

  void _adicionarValorLivreAoCarrinho({bool checkoutDireto = false}) {
    final valor = int.tryParse(_valorLivreDisplay) ?? 0;
    if (valor <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Digite um valor em talentos maior que zero.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final desc = _descLivreController.text.trim().isEmpty
        ? 'Compra Rápida'
        : _descLivreController.text.trim();

    setState(() {
      _carrinho.add(
        CartItem(
          produto: null,
          descricao: desc,
          precoUnitario: valor,
          quantidade: 1,
        ),
      );
      _valorLivreDisplay = '0';
    });

    HapticFeedback.selectionClick();

    if (checkoutDireto) {
      _abrirCheckout();
    }
  }

  // ----------------------------------------------------
  // CHECKOUT (ESTILO MAQUININHA)
  // ----------------------------------------------------

  Future<void> _abrirCheckout({AlunoModel? alunoPreSelecionado}) async {
    if (_totalTalentos <= 0 || _carrinho.isEmpty) return;

    // Pausa o listener local para que o modal de checkout assuma o leitor USB
    _nfcListener.stop();

    final itensDto = _carrinho.map((e) => e.toDto()).toList();
    final total = _totalTalentos;

    await PdvCheckoutDialog.show(
      context,
      totalTalentos: total,
      itensVenda: itensDto,
      repository: widget.repository,
      alunoPreSelecionado: alunoPreSelecionado,
      onVendaConcluida: () {
        setState(() {
          _carrinho.clear();
        });
        _carregarProdutos(); // Atualiza estoque na tela
      },
    );

    // Retoma o listener da tela de PDV
    if (mounted) {
      _nfcListener.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktopOrTablet = MediaQuery.sizeOf(context).width >= 768;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.storefront_rounded, color: Colors.amber),
            SizedBox(width: 8),
            Text('PDV Feirinha de Talentos', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Sincronização & Painel Admin',
            icon: const Icon(Icons.cloud_sync_rounded),
            onPressed: () {
              AdminPainelDialog.show(
                context,
                repository: widget.repository,
                onDadosAtualizados: _carregarProdutos,
              );
            },
          ),
          IconButton(
            tooltip: 'Gestão Rápida de Produtos (Requer PIN)',
            icon: const Icon(Icons.inventory_2_outlined),
            onPressed: () {
              GestaoProdutosDialog.show(
                context,
                repository: widget.repository,
                onProdutosChanged: _carregarProdutos,
              );
            },
          ),
          IconButton(
            tooltip: 'Simular Leitura NFC no PDV',
            icon: const Icon(Icons.developer_mode),
            onPressed: () => _nfcListener.simulateScan('041693AB8A2681'),
          ),
        ],
      ),
      body: isDesktopOrTablet
          ? Row(
              children: [
                // Painel Esquerdo: Seleção (Catálogo / Valor Livre)
                Expanded(
                  flex: 3,
                  child: _buildPainelSelecao(),
                ),
                const VerticalDivider(width: 1),
                // Painel Direito: Carrinho e Checkout
                SizedBox(
                  width: 380,
                  child: _buildPainelCarrinho(),
                ),
              ],
            )
          : Column(
              children: [
                // Em telas menores: Abas ou Painel dividido
                Expanded(
                  child: _buildPainelSelecao(),
                ),
                _buildBarraCarrinhoMobile(),
              ],
            ),
    );
  }

  // ----------------------------------------------------
  // PAINEL DE SELEÇÃO (CATÁLOGO / VALOR LIVRE)
  // ----------------------------------------------------

  Widget _buildPainelSelecao() {
    return Column(
      children: [
        // Alternador de Modos (Catálogo / Valor Livre)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment<int>(
                value: 0,
                icon: Icon(Icons.grid_view_rounded),
                label: Text('Catálogo de Produtos'),
              ),
              ButtonSegment<int>(
                value: 1,
                icon: Icon(Icons.pin_outlined),
                label: Text('Valor Livre / Rápido'),
              ),
            ],
            selected: {_modoSelecionado},
            onSelectionChanged: (val) {
              setState(() => _modoSelecionado = val.first);
            },
          ),
        ),

        // Conteúdo do modo
        Expanded(
          child: _modoSelecionado == 0
              ? _buildModoCatalogo()
              : _buildModoValorLivre(),
        ),
      ],
    );
  }

  Widget _buildModoCatalogo() {
    if (_carregandoProdutos) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_produtos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade700),
            const SizedBox(height: 12),
            const Text(
              'Nenhum produto cadastrado na feirinha.',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () {
                GestaoProdutosDialog.show(
                  context,
                  repository: widget.repository,
                  onProdutosChanged: _carregarProdutos,
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Cadastrar Produtos'),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = (constraints.maxWidth / 160).floor().clamp(2, 6);
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 0.85,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: _produtos.length,
          itemBuilder: (context, index) {
            final produto = _produtos[index];
            final cartItem = _carrinho.firstWhere(
              (it) => it.produto?.id == produto.id,
              orElse: () => CartItem(descricao: '', precoUnitario: 0, quantidade: 0),
            );
            final qtdNoCarrinho = cartItem.quantidade;
            final estaEsgotado = produto.esgotado || produto.estoque <= 0;

            return Card(
              elevation: 2,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: qtdNoCarrinho > 0
                      ? Colors.amber
                      : estaEsgotado
                          ? Colors.red.withValues(alpha: 0.3)
                          : Colors.white12,
                  width: qtdNoCarrinho > 0 ? 2 : 1,
                ),
              ),
              color: estaEsgotado
                  ? const Color(0xFF181818)
                  : qtdNoCarrinho > 0
                      ? const Color(0xFF26231C)
                      : const Color(0xFF1E1E1E),
              child: InkWell(
                onTap: () => _adicionarAoCarrinho(produto),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Badge superior de status ou quantidade
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (estaEsgotado)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.redAccent, width: 0.8),
                              ),
                              child: const Text(
                                'ESGOTADO',
                                style: TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          else
                            Text(
                              'Estoque: ${produto.estoque}',
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          if (qtdNoCarrinho > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.amber,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'x$qtdNoCarrinho',
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const Spacer(),
                      // Nome do Produto
                      Text(
                        produto.nome,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: estaEsgotado ? Colors.grey : Colors.white,
                          decoration: estaEsgotado ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Preço em Talentos
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.monetization_on, color: Colors.amber, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              '${produto.valorTalentos} T',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                color: estaEsgotado ? Colors.grey : Colors.amber,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildModoValorLivre() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Display do valor atual
              Container(
                padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.5), width: 1.5),
                ),
                child: Column(
                  children: [
                    const Text(
                      'VALOR AVULSO (TALENTOS)',
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        const Icon(Icons.monetization_on, color: Colors.amber, size: 32),
                        const SizedBox(width: 6),
                        Text(
                          _valorLivreDisplay,
                          style: const TextStyle(
                            fontSize: 44,
                            fontWeight: FontWeight.w900,
                            color: Colors.amber,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'T',
                          style: TextStyle(fontSize: 20, color: Colors.amber, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Campo de descrição opcional
              TextField(
                controller: _descLivreController,
                decoration: InputDecoration(
                  labelText: 'Descrição (opcional)',
                  hintText: 'Ex: Compra Rápida, Pastel, Brinquedo',
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.edit_note),
                ),
              ),

              const SizedBox(height: 12),

              // Botões Rápidos de Acréscimo (+1, +2, +5, +10)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildPresetChip('+1 T', 1),
                  _buildPresetChip('+2 T', 2),
                  _buildPresetChip('+5 T', 5),
                  _buildPresetChip('+10 T', 10),
                ],
              ),

              const SizedBox(height: 16),

              // Teclado Numérico Físico/Touch
              _buildTecladoNumerico(),

              const SizedBox(height: 16),

              // Botões de Ação do Valor Livre
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Colors.amber),
                      ),
                      onPressed: () => _adicionarValorLivreAoCarrinho(checkoutDireto: false),
                      icon: const Icon(Icons.add_shopping_cart, color: Colors.amber),
                      label: const Text('+ Carrinho', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => _adicionarValorLivreAoCarrinho(checkoutDireto: true),
                      icon: const Icon(Icons.flash_on),
                      label: const Text('Cobrar Direto', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPresetChip(String label, int val) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amber)),
      backgroundColor: Colors.amber.withValues(alpha: 0.15),
      side: BorderSide(color: Colors.amber.withValues(alpha: 0.4)),
      onPressed: () => _adicionarPresetValorLivre(val),
    );
  }

  Widget _buildTecladoNumerico() {
    return Table(
      children: [
        TableRow(
          children: [
            _buildKeypadButton('1'),
            _buildKeypadButton('2'),
            _buildKeypadButton('3'),
          ],
        ),
        TableRow(
          children: [
            _buildKeypadButton('4'),
            _buildKeypadButton('5'),
            _buildKeypadButton('6'),
          ],
        ),
        TableRow(
          children: [
            _buildKeypadButton('7'),
            _buildKeypadButton('8'),
            _buildKeypadButton('9'),
          ],
        ),
        TableRow(
          children: [
            _buildKeypadButton('C', corTexto: Colors.redAccent, onTap: _limparDisplayValorLivre),
            _buildKeypadButton('0'),
            _buildKeypadButton('⌫', corTexto: Colors.orangeAccent, onTap: _apagarDigitoValorLivre),
          ],
        ),
      ],
    );
  }

  Widget _buildKeypadButton(String label, {Color? corTexto, VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: Material(
        color: const Color(0xFF252525),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap ?? () => _teclaNumerica(label),
          child: Container(
            height: 52,
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: corTexto ?? Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ----------------------------------------------------
  // PAINEL DO CARRINHO E CHECKOUT
  // ----------------------------------------------------

  Widget _buildPainelCarrinho() {
    return Container(
      color: const Color(0xFF181818),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cabeçalho do Carrinho
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF202020),
              border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.shopping_cart_outlined, color: Colors.amber),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Carrinho (${_carrinho.length})',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_carrinho.isNotEmpty)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.delete_sweep, size: 18),
                    label: const Text('Limpar'),
                    onPressed: _limparCarrinho,
                  ),
              ],
            ),
          ),

          // Lista de Itens do Carrinho
          Expanded(
            child: _carrinho.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.remove_shopping_cart_outlined, size: 48, color: Colors.grey.shade700),
                        const SizedBox(height: 8),
                        const Text(
                          'Carrinho vazio',
                          style: TextStyle(color: Colors.grey, fontSize: 15),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Adicione itens pelo catálogo\nou valor livre.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _carrinho.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = _carrinho[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            // Botão de remoção
                            IconButton(
                              icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                              onPressed: () => _removerItem(item),
                            ),
                            // Nome e preço unitário
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.descricao,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  Text(
                                    '${item.precoUnitario} T cada',
                                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            // Controles de Quantidade
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, size: 20),
                                  onPressed: () => _decrementarItem(item),
                                ),
                                Text(
                                  '${item.quantidade}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline, size: 20),
                                  onPressed: () => _incrementarItem(item),
                                ),
                              ],
                            ),
                            // Subtotal do Item
                            SizedBox(
                              width: 60,
                              child: Text(
                                '${item.total} T',
                                textAlign: TextAlign.end,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Rodapé: Total e Botão de Finalizar Compra
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF202020),
              border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    const Text(
                      'TOTAL DA COMPRA:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: Colors.grey,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.monetization_on, color: Colors.amber, size: 22),
                        const SizedBox(width: 4),
                        Text(
                          '$_totalTalentos Talentos',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Colors.amber,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _totalTalentos > 0 ? () => _abrirCheckout() : null,
                  icon: const Icon(Icons.check_circle_outline, size: 22),
                  label: const Text(
                    'FINALIZAR COMPRA',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarraCarrinhoMobile() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF222222),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_carrinho.length} item(ns) selecionado(s)',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                Text(
                  'Total: $_totalTalentos T',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber,
                  ),
                ),
              ],
            ),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
            ),
            onPressed: _totalTalentos > 0 ? () => _abrirCheckout() : null,
            icon: const Icon(Icons.check),
            label: const Text('Finalizar', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
