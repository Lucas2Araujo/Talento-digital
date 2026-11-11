import 'dart:convert';

sealed class BuscaTagResult {
  const BuscaTagResult();

  const factory BuscaTagResult.encontradoAtivo(AlunoModel aluno) =
      BuscaTagResultEncontradoAtivo;
  const factory BuscaTagResult.encontradoExtraviado(
          AlunoModel antigoDono, String tagLida) =
      BuscaTagResultEncontradoExtraviado;
  const factory BuscaTagResult.naoCadastrado(String tagLida) =
      BuscaTagResultNaoCadastrado;
}

class BuscaTagResultEncontradoAtivo extends BuscaTagResult {
  final AlunoModel aluno;
  const BuscaTagResultEncontradoAtivo(this.aluno);
}

class BuscaTagResultEncontradoExtraviado extends BuscaTagResult {
  final AlunoModel antigoDono;
  final String tagLida;
  const BuscaTagResultEncontradoExtraviado(this.antigoDono, this.tagLida);
}

class BuscaTagResultNaoCadastrado extends BuscaTagResult {
  final String tagLida;
  const BuscaTagResultNaoCadastrado(this.tagLida);
}

class AlunoModel {
  final String uid;
  final String? tagAtualUid;
  final List<String> tagsAntigas;
  final String? avatarId;
  final String? fotoBase64;
  final String nome;
  final String? turma;
  final int saldoTalentos;
  final bool ativo;
  final String updatedAt;
  final bool synced;

  AlunoModel({
    required this.uid,
    String? tagAtualUid,
    List<String>? tagsAntigas,
    this.avatarId,
    this.fotoBase64,
    required this.nome,
    this.turma,
    this.saldoTalentos = 0,
    this.ativo = true,
    required this.updatedAt,
    this.synced = false,
  })  : tagAtualUid = tagAtualUid ?? uid,
        tagsAntigas = tagsAntigas ?? const [];

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'tag_atual_uid': tagAtualUid ?? uid,
        'tags_antigas': jsonEncode(tagsAntigas),
        if (avatarId != null) 'avatar_id': avatarId,
        if (fotoBase64 != null) 'foto_base64': fotoBase64,
        'nome': nome,
        'turma': turma,
        'saldo_talentos': saldoTalentos,
        'ativo': ativo ? 1 : 0,
        'updated_at': updatedAt,
        'synced': synced ? 1 : 0,
      };

  factory AlunoModel.fromMap(Map<String, dynamic> map) {
    final uidVal = (map['uid'] ?? map['id'] ?? '') as String;
    final tagsAntigasRaw = map['tags_antigas'];
    List<String> tagsAntigasParsed = const [];
    if (tagsAntigasRaw is List) {
      tagsAntigasParsed = tagsAntigasRaw.map((e) => e.toString()).toList();
    } else if (tagsAntigasRaw is String && tagsAntigasRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(tagsAntigasRaw);
        if (decoded is List) {
          tagsAntigasParsed = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {}
    }

    return AlunoModel(
      uid: uidVal,
      tagAtualUid: (map['tag_atual_uid'] as String?) ?? uidVal,
      tagsAntigas: tagsAntigasParsed,
      avatarId: map['avatar_id'] as String?,
      fotoBase64: map['foto_base64'] as String?,
      nome: (map['nome'] as String?) ?? 'Aluno',
      turma: map['turma'] as String?,
      saldoTalentos: map['saldo_talentos'] is num
          ? (map['saldo_talentos'] as num).toInt()
          : int.tryParse(map['saldo_talentos']?.toString() ?? '') ?? 0,
      ativo: map['ativo'] is bool
          ? map['ativo'] as bool
          : ((map['ativo'] as num?)?.toInt() ?? 1) != 0,
      updatedAt: (map['updated_at'] as String?) ?? DateTime.now().toIso8601String(),
      synced: map['synced'] is bool
          ? map['synced'] as bool
          : ((map['synced'] as num?)?.toInt() ?? 0) == 1,
    );
  }

  AlunoModel copyWith({
    String? uid,
    String? tagAtualUid,
    List<String>? tagsAntigas,
    String? avatarId,
    String? fotoBase64,
    String? nome,
    String? turma,
    int? saldoTalentos,
    bool? ativo,
    String? updatedAt,
    bool? synced,
  }) {
    return AlunoModel(
      uid: uid ?? this.uid,
      tagAtualUid: tagAtualUid ?? this.tagAtualUid,
      tagsAntigas: tagsAntigas ?? this.tagsAntigas,
      avatarId: avatarId ?? this.avatarId,
      fotoBase64: fotoBase64 ?? this.fotoBase64,
      nome: nome ?? this.nome,
      turma: turma ?? this.turma,
      saldoTalentos: saldoTalentos ?? this.saldoTalentos,
      ativo: ativo ?? this.ativo,
      updatedAt: updatedAt ?? this.updatedAt,
      synced: synced ?? this.synced,
    );
  }
}

class ProdutoModel {
  final int? id;
  final String? iconeId;
  final String? fotoBase64;
  final String nome;
  final int valorTalentos;
  final int estoque;
  final bool esgotado;
  final String updatedAt;
  final bool synced;

  ProdutoModel({
    this.id,
    this.iconeId,
    this.fotoBase64,
    required this.nome,
    required this.valorTalentos,
    this.estoque = 0,
    this.esgotado = false,
    required this.updatedAt,
    this.synced = false,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        if (iconeId != null) 'icone_id': iconeId,
        if (fotoBase64 != null) 'foto_base64': fotoBase64,
        'nome': nome,
        'valor_talentos': valorTalentos,
        'estoque': estoque,
        'esgotado': esgotado ? 1 : 0,
        'updated_at': updatedAt,
        'synced': synced ? 1 : 0,
      };

  factory ProdutoModel.fromMap(Map<String, dynamic> map) => ProdutoModel(
        id: map['id'] is num
            ? (map['id'] as num).toInt()
            : int.tryParse(map['id']?.toString() ?? ''),
        iconeId: map['icone_id'] as String?,
        fotoBase64: map['foto_base64'] as String?,
        nome: (map['nome'] as String?) ?? 'Produto',
        valorTalentos: (map['valor_talentos'] as num?)?.toInt() ?? 0,
        estoque: (map['estoque'] as num?)?.toInt() ?? 0,
        esgotado: map['esgotado'] is bool
            ? map['esgotado'] as bool
            : ((map['esgotado'] as num?)?.toInt() ?? 0) == 1,
        updatedAt: (map['updated_at'] as String?) ?? DateTime.now().toIso8601String(),
        synced: map['synced'] is bool
            ? map['synced'] as bool
            : ((map['synced'] as num?)?.toInt() ?? 0) == 1,
      );

  ProdutoModel copyWith({
    int? id,
    String? iconeId,
    String? fotoBase64,
    String? nome,
    int? valorTalentos,
    int? estoque,
    bool? esgotado,
    String? updatedAt,
    bool? synced,
  }) {
    return ProdutoModel(
      id: id ?? this.id,
      iconeId: iconeId ?? this.iconeId,
      fotoBase64: fotoBase64 ?? this.fotoBase64,
      nome: nome ?? this.nome,
      valorTalentos: valorTalentos ?? this.valorTalentos,
      estoque: estoque ?? this.estoque,
      esgotado: esgotado ?? this.esgotado,
      updatedAt: updatedAt ?? this.updatedAt,
      synced: synced ?? this.synced,
    );
  }
}

class TransacaoSaldoModel {
  final String id;
  final String alunoUid;
  final String tipo; // 'ENTRADA', 'SAIDA', 'AJUSTE'
  final int quantidade;
  final String motivo;
  final String operador;
  final String createdAt;
  final bool synced;

  TransacaoSaldoModel({
    required this.id,
    required this.alunoUid,
    required this.tipo,
    required this.quantidade,
    required this.motivo,
    this.operador = 'Professor',
    required this.createdAt,
    this.synced = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'aluno_uid': alunoUid,
        'tipo': tipo,
        'quantidade': quantidade,
        'motivo': motivo,
        'operador': operador,
        'created_at': createdAt,
        'synced': synced ? 1 : 0,
      };

  factory TransacaoSaldoModel.fromMap(Map<String, dynamic> map) =>
      TransacaoSaldoModel(
        id: map['id'] as String,
        alunoUid: map['aluno_uid'] as String,
        tipo: map['tipo'] as String,
        quantidade: (map['quantidade'] as num).toInt(),
        motivo: map['motivo'] as String,
        operador: map['operador'] as String? ?? 'Professor',
        createdAt: map['created_at'] as String,
        synced: (map['synced'] as int?) == 1,
      );
}

class VendaModel {
  final String id;
  final String alunoUid;
  final int totalTalentos;
  final String createdAt;
  final bool synced;

  VendaModel({
    required this.id,
    required this.alunoUid,
    required this.totalTalentos,
    required this.createdAt,
    this.synced = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'aluno_uid': alunoUid,
        'total_talentos': totalTalentos,
        'created_at': createdAt,
        'synced': synced ? 1 : 0,
      };

  factory VendaModel.fromMap(Map<String, dynamic> map) => VendaModel(
        id: map['id'] as String,
        alunoUid: map['aluno_uid'] as String,
        totalTalentos: (map['total_talentos'] as num).toInt(),
        createdAt: map['created_at'] as String,
        synced: (map['synced'] as int?) == 1,
      );
}

class ItemVendaDto {
  final int? produtoId;
  final String? descricaoLivre;
  final int quantidade;
  final int precoUnitario;

  ItemVendaDto({
    this.produtoId,
    this.descricaoLivre,
    required this.quantidade,
    required this.precoUnitario,
  }) : assert(
          produtoId != null || (descricaoLivre != null && descricaoLivre.isNotEmpty),
          'O item deve ter um produtoId ou uma descricaoLivre',
        );

  int get subtotal => quantidade * precoUnitario;

  Map<String, dynamic> toMap(String vendaId) => {
        'venda_id': vendaId,
        'produto_id': produtoId,
        'descricao_livre': descricaoLivre,
        'quantidade': quantidade,
        'preco_unitario': precoUnitario,
      };
}

class SaldoInsuficienteException implements Exception {
  final String alunoUid;
  final int saldoAtual;
  final int totalNecessario;

  SaldoInsuficienteException({
    required this.alunoUid,
    required this.saldoAtual,
    required this.totalNecessario,
  });

  @override
  String toString() =>
      'SaldoInsuficienteException: Saldo atual ($saldoAtual) insuficiente para a compra de $totalNecessario talentos.';
}
