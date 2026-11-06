import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class Aluno {
  final String uid;
  String nome;
  int saldo;

  Aluno({
    required this.uid,
    required this.nome,
    required this.saldo,
  });

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'nome': nome,
        'saldo': saldo,
      };

  factory Aluno.fromMap(Map<String, dynamic> map) => Aluno(
        uid: map['uid'] as String,
        nome: map['nome'] as String? ?? 'Novo Aluno',
        saldo: (map['saldo'] as num?)?.toInt() ?? 0,
      );

  String toJson() => jsonEncode(toMap());

  factory Aluno.fromJson(String source) =>
      Aluno.fromMap(jsonDecode(source) as Map<String, dynamic>);
}

class LocalRepository {
  static const String _prefix = 'aluno_';
  final SharedPreferences _prefs;

  LocalRepository(this._prefs);

  static Future<LocalRepository> init() async {
    final prefs = await SharedPreferences.getInstance();
    return LocalRepository(prefs);
  }

  /// Retorna o aluno com o UID ou cria um novo com saldo 0 caso não exista.
  Future<Aluno> getOrCreate(String uid) async {
    final key = '$_prefix$uid';
    final raw = _prefs.getString(key);
    if (raw != null) {
      try {
        return Aluno.fromJson(raw);
      } catch (_) {
        // Fallback em caso de dados corrompidos
      }
    }

    final novo = Aluno(uid: uid, nome: 'Novo Aluno', saldo: 0);
    await save(novo);
    return novo;
  }

  Future<void> save(Aluno aluno) async {
    await _prefs.setString('$_prefix${aluno.uid}', aluno.toJson());
  }
}
