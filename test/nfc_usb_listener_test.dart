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
      if (ch == '0') key = LogicalKeyboardKey.digit0;
      else if (ch == '1') key = LogicalKeyboardKey.digit1;
      else if (ch == '2') key = LogicalKeyboardKey.digit2;
      else if (ch == '4') key = LogicalKeyboardKey.digit4;
      else if (ch == '6') key = LogicalKeyboardKey.digit6;
      else if (ch == '8') key = LogicalKeyboardKey.digit8;
      else if (ch == '9') key = LogicalKeyboardKey.digit9;
      else if (ch == 'A') key = LogicalKeyboardKey.keyA;
      else if (ch == 'E') key = LogicalKeyboardKey.keyE;
      else key = LogicalKeyboardKey.keyF;

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

  test('NfcUsbListener ignora modifiers como Shift sem limpar o buffer', () {
    String? scannedUid;
    final listener = NfcUsbListener(onTagScanned: (uid) {
      scannedUid = uid;
    });
    listener.start();

    // Envia '0'
    HardwareKeyboard.instance.handleKeyEvent(
      const KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.digit0,
        logicalKey: LogicalKeyboardKey.digit0,
        character: '0',
        timeStamp: Duration(milliseconds: 10),
      ),
    );

    // Envia ShiftLeft (modifier comum enviado por leitores antes de letras)
    HardwareKeyboard.instance.handleKeyEvent(
      const KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.shiftLeft,
        logicalKey: LogicalKeyboardKey.shiftLeft,
        character: null,
        timeStamp: Duration(milliseconds: 20),
      ),
    );

    // Envia 'A' sem character (testa resolução via logicalKey)
    HardwareKeyboard.instance.handleKeyEvent(
      const KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.keyA,
        logicalKey: LogicalKeyboardKey.keyA,
        character: null,
        timeStamp: Duration(milliseconds: 30),
      ),
    );

    // Envia '1'
    HardwareKeyboard.instance.handleKeyEvent(
      const KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.digit1,
        logicalKey: LogicalKeyboardKey.digit1,
        character: '1',
        timeStamp: Duration(milliseconds: 40),
      ),
    );

    // Envia '2'
    HardwareKeyboard.instance.handleKeyEvent(
      const KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.digit2,
        logicalKey: LogicalKeyboardKey.digit2,
        character: '2',
        timeStamp: Duration(milliseconds: 50),
      ),
    );

    // Envia Enter
    HardwareKeyboard.instance.handleKeyEvent(
      const KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.enter,
        logicalKey: LogicalKeyboardKey.enter,
        character: null,
        timeStamp: Duration(milliseconds: 60),
      ),
    );

    expect(scannedUid, equals('0A12'));
    listener.stop();
  });
}
