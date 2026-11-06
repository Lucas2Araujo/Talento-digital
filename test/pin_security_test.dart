import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talento_digital/services/pin_security_service.dart';
import 'package:talento_digital/widgets/pin_auth_dialog.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('PinSecurityService inicia com PIN padrão 1234 e permite alteração', () async {
    final prefs = await SharedPreferences.getInstance();
    final service = PinSecurityService(prefs);

    expect(service.pinAtual, '1234');
    expect(service.verificarPin('1234'), isTrue);
    expect(service.verificarPin('0000'), isFalse);

    // Altera com PIN atual errado -> falha
    final falha = await service.alterarPin(pinAtualDigitado: '9999', novoPin: '4321');
    expect(falha, isFalse);
    expect(service.pinAtual, '1234');

    // Altera com PIN atual correto -> sucesso
    final sucesso = await service.alterarPin(pinAtualDigitado: '1234', novoPin: '4321');
    expect(sucesso, isTrue);
    expect(service.pinAtual, '4321');
    expect(service.verificarPin('4321'), isTrue);
  });

  testWidgets('PinAuthDialog valida PIN digitado via teclado na tela', (tester) async {
    bool? autenticado;

    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.dark(),
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            autenticado = await PinAuthDialog.solicitarPin(context);
          },
          child: const Text('Abrir'),
        ),
      ),
    ));

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    expect(find.text('Acesso Administrativo'), findsOneWidget);

    // Digita PIN padrão 1, 2, 3, 4
    await tester.tap(find.text('1'));
    await tester.pump();
    await tester.tap(find.text('2'));
    await tester.pump();
    await tester.tap(find.text('3'));
    await tester.pump();
    await tester.tap(find.text('4'));
    await tester.pumpAndSettle();

    // Dialog deve ter fechado com sucesso (true)
    expect(autenticado, isTrue);
  });
}
