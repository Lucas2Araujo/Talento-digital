import 'package:flutter/services.dart';

typedef OnNfcTagScanned = void Function(String uid);

/// Serviço minimalista para capturar eventos de hardware do leitor USB NFC (HID).
/// Não depende de TextField nem abre teclado virtual no Android.
class NfcUsbListener {
  final OnNfcTagScanned onTagScanned;
  final StringBuffer _buffer = StringBuffer();

  bool _isActive = true;

  NfcUsbListener({required this.onTagScanned});

  void start() {
    _isActive = true;
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  void stop() {
    _isActive = false;
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _buffer.clear();
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (!_isActive || event is! KeyDownEvent) return false;

    // Se detectou Enter (fim da leitura da tag HID)
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      final code = _buffer.toString().trim();
      _buffer.clear();

      if (code.isNotEmpty && _isValidHexUid(code)) {
        onTagScanned(code.toUpperCase());
        return true;
      }
      return false;
    }

    // Extrai o caractere digitado (ou converte de teclas numéricas/letras caso event.character seja nulo no Linux)
    String? char = event.character;
    if (char == null || char.isEmpty) {
      char = _resolveCharacterFromKey(event.logicalKey);
    }

    // Se for hexadecimal (0-9, A-F)
    if (char != null && char.length == 1 && RegExp(r'[0-9a-fA-F]').hasMatch(char)) {
      _buffer.write(char);
      return false;
    }

    // Se qualquer caractere não-hexadecimal for digitado (espaço, etc.), limpa o buffer
    if (char != null && char.isNotEmpty && !char.contains(RegExp(r'[\r\n]'))) {
      _buffer.clear();
    }

    return false;
  }

  String? _resolveCharacterFromKey(LogicalKeyboardKey key) {
    // Teclas 0 a 9 do teclado principal
    if (key == LogicalKeyboardKey.digit0) return '0';
    if (key == LogicalKeyboardKey.digit1) return '1';
    if (key == LogicalKeyboardKey.digit2) return '2';
    if (key == LogicalKeyboardKey.digit3) return '3';
    if (key == LogicalKeyboardKey.digit4) return '4';
    if (key == LogicalKeyboardKey.digit5) return '5';
    if (key == LogicalKeyboardKey.digit6) return '6';
    if (key == LogicalKeyboardKey.digit7) return '7';
    if (key == LogicalKeyboardKey.digit8) return '8';
    if (key == LogicalKeyboardKey.digit9) return '9';

    // Teclas do teclado numérico (Numpad)
    if (key == LogicalKeyboardKey.numpad0) return '0';
    if (key == LogicalKeyboardKey.numpad1) return '1';
    if (key == LogicalKeyboardKey.numpad2) return '2';
    if (key == LogicalKeyboardKey.numpad3) return '3';
    if (key == LogicalKeyboardKey.numpad4) return '4';
    if (key == LogicalKeyboardKey.numpad5) return '5';
    if (key == LogicalKeyboardKey.numpad6) return '6';
    if (key == LogicalKeyboardKey.numpad7) return '7';
    if (key == LogicalKeyboardKey.numpad8) return '8';
    if (key == LogicalKeyboardKey.numpad9) return '9';

    // Letras hexadecimais A a F
    if (key == LogicalKeyboardKey.keyA) return 'A';
    if (key == LogicalKeyboardKey.keyB) return 'B';
    if (key == LogicalKeyboardKey.keyC) return 'C';
    if (key == LogicalKeyboardKey.keyD) return 'D';
    if (key == LogicalKeyboardKey.keyE) return 'E';
    if (key == LogicalKeyboardKey.keyF) return 'F';

    return null;
  }

  bool _isValidHexUid(String code) {
    return RegExp(r'^[0-9a-fA-F]{8,20}$').hasMatch(code);
  }

  /// Método para simulação em ambiente de desenvolvimento sem leitor físico
  void simulateScan(String uid) {
    onTagScanned(uid.trim().toUpperCase());
  }
}
