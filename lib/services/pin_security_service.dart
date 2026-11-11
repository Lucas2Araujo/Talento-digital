import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PinSecurityService {
  static const String _pinKey = 'admin_pin_code';
  static const String pinPadrao = '1234';

  final SharedPreferences _prefs;

  /// Estado global reativo de sessão (Modo Consulta vs Modo Professor/Admin)
  static final ValueNotifier<bool> isModoProfessorAtivo = ValueNotifier<bool>(false);

  PinSecurityService(this._prefs);

  static Future<PinSecurityService> getInstance() async {
    final prefs = await SharedPreferences.getInstance();
    return PinSecurityService(prefs);
  }

  /// Retorna o PIN cadastrado ou o padrão '1234'
  String get pinAtual {
    return _prefs.getString(_pinKey) ?? pinPadrao;
  }

  /// Verifica se o PIN informado confere com o PIN armazenado
  bool verificarPin(String pinDigitado) {
    return pinDigitado.trim() == pinAtual;
  }

  /// Altera o PIN exigindo a validação prévia do PIN atual
  Future<bool> alterarPin({
    required String pinAtualDigitado,
    required String novoPin,
  }) async {
    if (!verificarPin(pinAtualDigitado)) {
      return false;
    }

    final trimmedNovo = novoPin.trim();
    if (trimmedNovo.length != 4 || !RegExp(r'^\d{4}$').hasMatch(trimmedNovo)) {
      throw ArgumentError('O novo PIN deve conter exatamente 4 dígitos numéricos.');
    }

    return await _prefs.setString(_pinKey, trimmedNovo);
  }

  /// Reseta o PIN para o padrão '1234'
  Future<bool> resetarParaPadrao() async {
    return await _prefs.setString(_pinKey, pinPadrao);
  }
}
