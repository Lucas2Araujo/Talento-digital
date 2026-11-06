import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talento_digital/database/models.dart';
import 'package:talento_digital/database/talentos_repository.dart';
import 'package:talento_digital/widgets/aluno_detalhes_modal.dart';

class FakeTalentosRepository extends TalentosRepository {
  final List<AlunoModel> alunos;
  FakeTalentosRepository(this.alunos);

  @override
  Future<int> adicionarTalentos({
    required String alunoUid,
    required int quantidade,
    required String motivo,
    String operador = 'Professor',
  }) async {
    final aluno = alunos.firstWhere((a) => a.uid == alunoUid);
    return aluno.saldoTalentos + quantidade;
  }

  @override
  Future<List<TransacaoSaldoModel>> listarTransacoesDoAluno(String alunoUid, {int limit = 20}) async {
    return [
      TransacaoSaldoModel(
        id: '1',
        alunoUid: alunoUid,
        tipo: 'ENTRADA',
        quantidade: 1,
        motivo: 'Presença na Escola Sabatina',
        createdAt: '2026-11-06T10:00:00',
      ),
    ];
  }
}

void main() {
  testWidgets('AlunoDetalhesModal exibe dados e botões de lançamento', (tester) async {
    final aluno = AlunoModel(
      uid: '041693AB8A2681',
      nome: 'Lucas Gabriel',
      turma: 'Primários',
      saldoTalentos: 12,
      updatedAt: '2026-11-06T10:00:00',
    );
    final repo = FakeTalentosRepository([aluno]);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AlunoDetalhesModal(
          alunoInicial: aluno,
          repository: repo,
          onDataChanged: () {},
        ),
      ),
    ));

    expect(find.text('Lucas Gabriel'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('+1 Presença'), findsOneWidget);
    expect(find.text('+2 Lição Feita'), findsOneWidget);
    expect(find.text('+5 Verso Bíblico'), findsOneWidget);
    expect(find.text('+3 Ação Especial'), findsOneWidget);
  });
}
