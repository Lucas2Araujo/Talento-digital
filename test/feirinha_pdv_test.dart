import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talento_digital/database/models.dart';
import 'package:talento_digital/database/talentos_repository.dart';
import 'package:talento_digital/screens/feirinha_pdv_screen.dart';

class FakePdvRepository extends TalentosRepository {
  final List<ProdutoModel> produtos;
  final List<AlunoModel> alunos;

  FakePdvRepository({required this.produtos, required this.alunos});

  @override
  Future<List<ProdutoModel>> listarProdutos({bool apenasDisponiveis = true}) async {
    if (apenasDisponiveis) {
      return produtos.where((p) => !p.esgotado).toList();
    }
    return produtos;
  }

  @override
  Future<AlunoModel?> buscarAlunoPorUid(String uid) async {
    try {
      return alunos.firstWhere((a) => a.uid == uid);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String> processarVenda({
    required String alunoUid,
    required List<ItemVendaDto> itens,
    required int totalTalentos,
  }) async {
    return 'venda-teste-id';
  }
}

void main() {
  testWidgets('PDV renderiza catálogo e adiciona item ao carrinho', (tester) async {
    final produtos = [
      ProdutoModel(
        id: 1,
        nome: 'Mini Bíblia Ilustrada',
        valorTalentos: 15,
        estoque: 5,
        esgotado: false,
        updatedAt: '2026-11-06T10:00:00',
      ),
      ProdutoModel(
        id: 2,
        nome: 'Adesivos Divertidos',
        valorTalentos: 3,
        estoque: 0,
        esgotado: true,
        updatedAt: '2026-11-06T10:00:00',
      ),
    ];

    final repo = FakePdvRepository(produtos: produtos, alunos: []);

    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.dark(),
      home: FeirinhaPdvScreen(repository: repo),
    ));

    await tester.pumpAndSettle();

    // Verifica que os produtos aparecem
    expect(find.text('Mini Bíblia Ilustrada'), findsOneWidget);
    expect(find.text('15 T'), findsOneWidget);
    expect(find.text('Adesivos Divertidos'), findsOneWidget);
    expect(find.text('ESGOTADO'), findsOneWidget);

    // Clica no item disponível para adicionar ao carrinho
    await tester.tap(find.text('Mini Bíblia Ilustrada'));
    await tester.pumpAndSettle();

    // Carrinho deve atualizar com 15 Talentos
    expect(find.text('15 Talentos'), findsOneWidget);
    expect(find.text('FINALIZAR COMPRA'), findsOneWidget);
  });
}
