class AlunoModel {
  final String uid;
  final String nome;
  final String? turma;
  final int saldoTalentos;
  final bool ativo;
  final String updatedAt;
  final bool synced;

  AlunoModel({
    required this.uid,
    required this.nome,
    this.turma,
    this.saldoTalentos = 0,
    this.ativo = true,
    required this.updatedAt,
    this.synced = false,
  });

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'nome': nome,
        'turma': turma,
        'saldo_talentos': saldoTalentos,
        'ativo': ativo ? 1 : 0,
        'updated_at': updatedAt,
        'synced': synced ? 1 : 0,
      };

  factory AlunoModel.fromMap(Map<String, dynamic> map) => AlunoModel(
        uid: map['uid'] as String,
        nome: map['nome'] as String,
        turma: map['turma'] as String?,
        saldoTalentos: (map['saldo_talentos'] as num?)?.toInt() ?? 0,
        ativo: (map['ativo'] as int?) != 0,
        updatedAt: map['updated_at'] as String,
        synced: (map['synced'] as int?) == 1,
      );
}

class ProdutoModel {
  final int? id;
  final String nome;
  final int valorTalentos;
  final int estoque;
  final bool esgotado;
  final String updatedAt;
  final bool synced;

  ProdutoModel({
    this.id,
    required this.nome,
    required this.valorTalentos,
    this.estoque = 0,
    this.esgotado = false,
    required this.updatedAt,
    this.synced = false,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'nome': nome,
        'valor_talentos': valorTalentos,
        'estoque': estoque,
        'esgotado': esgotado ? 1 : 0,
        'updated_at': updatedAt,
        'synced': synced ? 1 : 0,
      };

  factory ProdutoModel.fromMap(Map<String, dynamic> map) => ProdutoModel(
        id: map['id'] as int?,
        nome: map['nome'] as String,
        valorTalentos: (map['valor_talentos'] as num).toInt(),
        estoque: (map['estoque'] as num?)?.toInt() ?? 0,
        esgotado: (map['esgotado'] as int?) == 1,
        updatedAt: map['updated_at'] as String,
        synced: (map['synced'] as int?) == 1,
      );
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
