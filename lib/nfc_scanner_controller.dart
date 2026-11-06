import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'local_repository.dart';

class NfcScannerController extends ChangeNotifier {
  final LocalRepository _repo;
  final StringBuffer _buffer = StringBuffer();
  DateTime _lastCharTime = DateTime.fromMillisecondsSinceEpoch(0);

  /// Leitores USB HID digitam caracteres muito rapidamente (rajada de 5ms a 30ms por tecla).
  /// Se passar de 150ms entre caracteres, consideramos que foi digitação humana lenta no teclado e descartamos.
  static const int _maxInterKeyDelayMs = 150;

  String? _lastUid;
  String _status = 'Aguardando tag...';
  Aluno? _currentAluno;
  final List<String> _history = [];

  NfcScannerController(this._repo);

  String? get lastUid => _lastUid;
  String get status => _status;
  Aluno? get currentAluno => _currentAluno;
  List<String> get history => List.unmodifiable(_history);

  /// Trata teclas do teclado físico / leitor HID globalmente
  bool handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    final now = DateTime.now();

    // Se detectou Enter (fim da leitura da tag)
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      final code = _buffer.toString().trim();
      final bufferAge = now.difference(_lastCharTime).inMilliseconds;
      _buffer.clear();

      // Validação: UID deve ter tamanho típico (ex: 8 a 20 chars hexadecimais)
      // e o último caractere recebido deve ter ocorrido na rajada do leitor
      if (code.isNotEmpty && bufferAge < 500 && _isValidHexUid(code)) {
        _onTagScanned(code.toUpperCase());
        // Consome o evento para não acionar formulários nem submit acidental
        return true;
      }
      return false;
    }

    final char = event.character;
    // Só acumula caracteres se forem hexadecimais válidos (0-9, A-F, a-f)
    if (char != null && char.length == 1 && RegExp(r'[0-9a-fA-F]').hasMatch(char)) {
      final elapsed = now.difference(_lastCharTime).inMilliseconds;

      // Se passou muito tempo desde o caractere anterior, não é rajada de leitor HID: reinicia o buffer
      if (elapsed > _maxInterKeyDelayMs && _buffer.isNotEmpty) {
        _buffer.clear();
      }

      _buffer.write(char);
      _lastCharTime = now;

      // NÃO retornamos true aqui! Permitimos que o evento continue fluindo
      // caso o usuário esteja digitando em um TextField focado.
      return false;
    }

    // Se qualquer tecla não-hexadecimal for pressionada (ex: espaço, letras G-Z, etc.),
    // limpa o buffer pois com certeza é digitação humana normal
    if (char != null && char.isNotEmpty && !char.contains(RegExp(r'[\r\n]'))) {
      _buffer.clear();
    }

    return false;
  }

  /// Valida se é um UID hexadecimal com tamanho plausível (7 bytes = 14 chars, 4 bytes = 8 chars, etc.)
  bool _isValidHexUid(String code) {
    final hexRegex = RegExp(r'^[0-9a-fA-F]{8,20}$');
    return hexRegex.hasMatch(code);
  }

  Future<void> _onTagScanned(String uid) async {
    _lastUid = uid;
    _status = 'Tag lida com sucesso!';

    // Feedback sonoro/tátil padrão do sistema
    SystemSound.play(SystemSoundType.click);
    HapticFeedback.lightImpact();

    // Histórico de UIDs (máximo 5)
    _history.remove(uid);
    _history.insert(0, uid);
    if (_history.length > 5) {
      _history.removeLast();
    }

    // Consulta ou cadastra no banco
    _currentAluno = await _repo.getOrCreate(uid);
    notifyListeners();
  }

  Future<void> updateNome(String novoNome) async {
    if (_currentAluno == null) return;
    final trimmed = novoNome.trim();
    if (trimmed.isEmpty || trimmed == _currentAluno!.nome) return;

    _currentAluno!.nome = trimmed;
    await _repo.save(_currentAluno!);
    _status = 'Nome atualizado!';
    notifyListeners();
  }

  Future<void> adjustSaldo(int delta) async {
    if (_currentAluno == null) return;
    _currentAluno!.saldo += delta;
    if (_currentAluno!.saldo < 0) _currentAluno!.saldo = 0;

    await _repo.save(_currentAluno!);
    _status = 'Saldo atualizado (${delta > 0 ? "+$delta" : "$delta"})';
    HapticFeedback.selectionClick();
    notifyListeners();
  }

  /// Para fins de teste/simulação manual caso não haja leitor conectado no momento
  void simulateScan(String uid) {
    _onTagScanned(uid);
  }
}
