import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talento_digital/services/nfc_usb_listener.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('NfcUsbListener captura sequencia hex de 14 digitos e dispara no Enter', () {
    String? scannedUid;
    final listener = NfcUsbListener(onTagScanned: (uid) {
      scannedUid = uid;
    });
    listener.start();

    // Simula a digitação de 044EE8A8892681 seguida de Enter
    const tag = '044EE8A8892681';
    for (int i = 0; i < tag.length; i++) {
      final ch = tag[i];
      LogicalKeyboardKey key;
      if (ch == '0') {
        key = LogicalKeyboardKey.digit0;
      } else if (ch == '1') {
        key = LogicalKeyboardKey.digit1;
      } else if (ch == '2') {
        key = LogicalKeyboardKey.digit2;
      } else if (ch == '4') {
        key = LogicalKeyboardKey.digit4;
      } else if (ch == '6') {
        key = LogicalKeyboardKey.digit6;
      } else if (ch == '8') {
        key = LogicalKeyboardKey.digit8;
      } else if (ch == '9') {
        key = LogicalKeyboardKey.digit9;
      } else if (ch == 'A') {
        key = LogicalKeyboardKey.keyA;
      } else if (ch == 'E') {
        key = LogicalKeyboardKey.keyE;
      } else {
        key = LogicalKeyboardKey.keyF;
      }

      HardwareKeyboard.instance.handleKeyEvent(
        KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.keyA,
          logicalKey: key,
          character: ch,
          timeStamp: Duration(milliseconds: i * 10),
        ),
      );
    }

    // Tecla Enter final
    HardwareKeyboard.instance.handleKeyEvent(
      const KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.enter,
        logicalKey: LogicalKeyboardKey.enter,
        character: null,
        timeStamp: Duration(milliseconds: 200),
      ),
    );

    expect(scannedUid, equals('044EE8A8892681'));
    listener.stop();
  });

  test('NfcUsbListener pilha LIFO: apenas o listener do topo recebe o scan', () {
    String? scanTelaInicial;
    String? scanModalOuCheckout;

    final listenerTelaInicial = NfcUsbListener(onTagScanned: (uid) {
      scanTelaInicial = uid;
    });
    final listenerModal = NfcUsbListener(onTagScanned: (uid) {
      scanModalOuCheckout = uid;
    });

    // 1. Tela inicial aberta
    listenerTelaInicial.start();

    // 2. Modal/Checkout abre por cima
    listenerModal.start();

    // Simula escaneamento de tag
    listenerModal.simulateScan('041693AB8A2681');

    // Apenas o modal/checkout deve receber! A tela inicial NÃO deve receber!
    expect(scanModalOuCheckout, equals('041693AB8A2681'));
    expect(scanTelaInicial, isNull);

    // 3. Modal/Checkout fecha
    listenerModal.stop();
    scanModalOuCheckout = null;

    // Agora novo scan deve ir para a tela inicial
    listenerTelaInicial.simulateScan('044EE8A8892681');
    expect(scanTelaInicial, equals('044EE8A8892681'));
    expect(scanModalOuCheckout, isNull);

    listenerTelaInicial.stop();
  });
}
