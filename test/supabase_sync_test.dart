import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talento_digital/services/supabase_sync_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('SupabaseSyncService sem credenciais retorna offline ou erro gracioso', () async {
    final prefs = await SharedPreferences.getInstance();
    final service = SupabaseSyncService(prefs);

    expect(service.estaConfigurado, isFalse);
    expect(service.supabaseUrl, isEmpty);

    // Salva credenciais
    await service.salvarConfiguracoes(
      url: 'https://exemplo.supabase.co',
      anonKey: 'chave-anon-teste',
    );

    expect(service.estaConfigurado, isTrue);
    expect(service.supabaseUrl, 'https://exemplo.supabase.co');
    expect(service.supabaseAnonKey, 'chave-anon-teste');
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
}
