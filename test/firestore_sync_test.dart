import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talento_digital/services/firestore_sync_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('SyncResult estrutura e contabiliza totais enviados', () {
    const result = SyncResult(
      sucesso: true,
      mensagem: 'Sucesso',
      alunosEnviados: 2,
      produtosEnviados: 3,
      transacoesEnviadas: 5,
      vendasEnviadas: 1,
      registrosRecebidos: 4,
    );

    expect(result.totalEnviados, 11);
    expect(result.registrosRecebidos, 4);
    expect(result.sucesso, isTrue);
    expect(result.offline, isFalse);
  });

  test('FirestoreSyncService inicializa e respeita plataforma', () async {
    final prefs = await SharedPreferences.getInstance();
    final service = FirestoreSyncService(prefs);

    expect(service.ultimaSincronizacao, isNull);
  });
}
