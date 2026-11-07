import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';
import 'web_nfc_helper.dart';

typedef OnNfcTagScanned = void Function(String uid);

/// Serviço híbrido para capturar eventos de NFC:
/// 1. Hardware HID USB (Web, Desktop e Android com adaptador USB-OTG ou Hub).
/// 2. Antena NFC interna nativa do celular (Android via nfc_manager lendo o hardware UID).
class NfcUsbListener {
  final OnNfcTagScanned onTagScanned;
  final StringBuffer _buffer = StringBuffer();
  DateTime? _lastCharTime;

  bool _isActive = true;

  NfcUsbListener({required this.onTagScanned});

  void start() {
    _isActive = true;
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);

    if (kIsWeb) {
      registerWebNfcCallback((uid) {
        if (_isActive) {
          onTagScanned(uid);
        }
      });
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      _startNativeAndroidNfc();
    }
  }

  void stop() {
    _isActive = false;
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _buffer.clear();

    if (kIsWeb) {
      registerWebNfcCallback(null);
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      NfcManager.instance.stopSession().catchError((_) {});
    }
  }

  Future<void> _startNativeAndroidNfc() async {
    try {
      final availability = await NfcManager.instance.checkAvailability();
      if (availability != NfcAvailability.enabled) return;

      await NfcManager.instance.startSession(
        pollingOptions: {NfcPollingOption.iso14443, NfcPollingOption.iso15693},
        onDiscovered: (NfcTag tag) async {
          if (!_isActive) return;

          // Extrai o identificador de hardware (UID) diretamente do chip
          final tagAndroid = NfcTagAndroid.from(tag);
          if (tagAndroid != null && tagAndroid.id.isNotEmpty) {
            final uid = tagAndroid.id
                .map((e) => e.toRadixString(16).padLeft(2, '0'))
                .join()
                .toUpperCase();
            if (uid.isNotEmpty) {
              onTagScanned(uid);
            }
          }
        },
      );
    } catch (e) {
      debugPrint('Erro ao iniciar NFC nativo Android: $e');
    }
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (!_isActive || event is! KeyDownEvent) return false;

    final now = DateTime.now();
    if (_lastCharTime != null && now.difference(_lastCharTime!) > const Duration(milliseconds: 600)) {
      _buffer.clear();
    }
    _lastCharTime = now;

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

    // Extrai o caractere digitado (ou converte de teclas numéricas/letras caso event.character seja nulo)
    String? char = event.character;
    if (char == null || char.isEmpty) {
      char = _resolveCharacterFromKey(event.logicalKey);
    }

    // Se for hexadecimal (0-9, A-F)
    if (char != null && char.length == 1 && RegExp(r'[0-9a-fA-F]').hasMatch(char)) {
      _buffer.write(char.toUpperCase());
      return false;
    }

    // Se não for tecla modificadora (Shift, Ctrl, Alt, CapsLock) e não for quebra de linha, limpa
    if (event.logicalKey != LogicalKeyboardKey.shiftLeft &&
        event.logicalKey != LogicalKeyboardKey.shiftRight &&
        event.logicalKey != LogicalKeyboardKey.capsLock &&
        event.logicalKey != LogicalKeyboardKey.numLock &&
        event.logicalKey != LogicalKeyboardKey.controlLeft &&
        event.logicalKey != LogicalKeyboardKey.controlRight) {
      if (char != null && char.isNotEmpty && !char.contains(RegExp(r'[\r\n]'))) {
        _buffer.clear();
      }
    }

    return false;
  }

  String? _resolveCharacterFromKey(LogicalKeyboardKey key) {
    // 1. Tenta pegar direto do label da tecla se for um único caractere hex
    final label = key.keyLabel;
    if (label.length == 1 && RegExp(r'^[0-9a-fA-F]$').hasMatch(label)) {
      return label.toUpperCase();
    }

    // 2. Mapeamento explícito de dígitos normais e do teclado numérico
    if (key == LogicalKeyboardKey.digit0 || key == LogicalKeyboardKey.numpad0) return '0';
    if (key == LogicalKeyboardKey.digit1 || key == LogicalKeyboardKey.numpad1) return '1';
    if (key == LogicalKeyboardKey.digit2 || key == LogicalKeyboardKey.numpad2) return '2';
    if (key == LogicalKeyboardKey.digit3 || key == LogicalKeyboardKey.numpad3) return '3';
    if (key == LogicalKeyboardKey.digit4 || key == LogicalKeyboardKey.numpad4) return '4';
    if (key == LogicalKeyboardKey.digit5 || key == LogicalKeyboardKey.numpad5) return '5';
    if (key == LogicalKeyboardKey.digit6 || key == LogicalKeyboardKey.numpad6) return '6';
    if (key == LogicalKeyboardKey.digit7 || key == LogicalKeyboardKey.numpad7) return '7';
    if (key == LogicalKeyboardKey.digit8 || key == LogicalKeyboardKey.numpad8) return '8';
    if (key == LogicalKeyboardKey.digit9 || key == LogicalKeyboardKey.numpad9) return '9';

    // 3. Letras hexadecimais A-F
    if (key == LogicalKeyboardKey.keyA) return 'A';
    if (key == LogicalKeyboardKey.keyB) return 'B';
    if (key == LogicalKeyboardKey.keyC) return 'C';
    if (key == LogicalKeyboardKey.keyD) return 'D';
    if (key == LogicalKeyboardKey.keyE) return 'E';
    if (key == LogicalKeyboardKey.keyF) return 'F';

    // 4. Fallback por faixa ASCII do keyId
    final id = key.keyId;
    if (id >= 0x30 && id <= 0x39) return String.fromCharCode(id);
    if (id >= 0x41 && id <= 0x46) return String.fromCharCode(id);
    if (id >= 0x61 && id <= 0x66) return String.fromCharCode(id - 0x20);

    return null;
  }

  bool _isValidHexUid(String code) {
    return RegExp(r'^[0-9a-fA-F]{4,32}$').hasMatch(code);
  }

  /// Método para simulação em ambiente de desenvolvimento sem leitor físico
  void simulateScan(String uid) {
    onTagScanned(uid.trim().toUpperCase());
  }
}
