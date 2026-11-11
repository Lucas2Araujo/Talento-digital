import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';

class ImageHelperService {
  static const Map<String, ({String nome, String emoji, Color corFundo})> avatares = {
    'leao': (nome: 'Leão Corajoso', emoji: '🦁', corFundo: Color(0xFFFFE0B2)),
    'ovelha': (nome: 'Ovelhinha Mansa', emoji: '🐑', corFundo: Color(0xFFE1F5FE)),
    'aguia': (nome: 'Águia Veloz', emoji: '🦅', corFundo: Color(0xFFE8F5E9)),
    'urso': (nome: 'Urso Forte', emoji: '🐻', corFundo: Color(0xFFD7CCC8)),
    'panda': (nome: 'Panda Amigo', emoji: '🐼', corFundo: Color(0xFFF5F5F5)),
    'raposa': (nome: 'Raposa Esperta', emoji: '🦊', corFundo: Color(0xFFFFCCBC)),
  };

  static const Map<String, ({String nome, String emoji, Color corFundo})> iconesProduto = {
    'brinquedo': (nome: 'Brinquedo', emoji: '🧸', corFundo: Color(0xFFFFECB3)),
    'lanche': (nome: 'Lanchinho', emoji: '🥪', corFundo: Color(0xFFFFCCBC)),
    'material': (nome: 'Material Escolar', emoji: '✏️', corFundo: Color(0xFFC8E6C9)),
    'biblia': (nome: 'Bíblia / Livro', emoji: '📖', corFundo: Color(0xFFBBDEFB)),
    'doce': (nome: 'Guloseima', emoji: '🍬', corFundo: Color(0xFFF8BBD0)),
    'adesivo': (nome: 'Adesivo / Brinde', emoji: '⭐', corFundo: Color(0xFFFFF9C4)),
  };

  static final Random _random = Random();

  static String sortearAvatar() {
    final keys = avatares.keys.toList();
    return keys[_random.nextInt(keys.length)];
  }

  static String sortearIconeProduto() {
    final keys = iconesProduto.keys.toList();
    return keys[_random.nextInt(keys.length)];
  }

  /// Retorna o widget do avatar (foto Base64 se presente, avatar de animal ou inicial do nome)
  static Widget buildAvatarWidget({
    String? fotoBase64,
    String? avatarId,
    required String nome,
    double size = 80,
    double borderWidth = 3,
    Color borderColor = const Color(0xFFFFB703),
  }) {
    // 1. Foto Base64
    if (fotoBase64 != null && fotoBase64.isNotEmpty) {
      try {
        final bytes = base64Decode(fotoBase64);
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: borderColor, width: borderWidth),
          ),
          child: ClipOval(
            child: Image.memory(
              bytes,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => _buildFallbackEmoji(avatarId, nome, size, borderWidth, borderColor),
            ),
          ),
        );
      } catch (_) {
        // Fallback para avatar
      }
    }

    return _buildFallbackEmoji(avatarId, nome, size, borderWidth, borderColor);
  }

  static Widget _buildFallbackEmoji(
    String? avatarId,
    String nome,
    double size,
    double borderWidth,
    Color borderColor,
  ) {
    final avatarData = avatarId != null ? avatares[avatarId] : null;
    final bg = avatarData?.corFundo ?? const Color(0xFFE0E0E0);
    final emoji = avatarData?.emoji;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      alignment: Alignment.center,
      child: emoji != null
          ? Text(
              emoji,
              style: TextStyle(fontSize: size * 0.52),
            )
          : Text(
              nome.isNotEmpty ? nome[0].toUpperCase() : '?',
              style: TextStyle(
                fontSize: size * 0.44,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF5E3B1B),
              ),
            ),
    );
  }

  /// Retorna o widget do produto (foto Base64 ou emoji temático)
  static Widget buildProdutoIconWidget({
    String? fotoBase64,
    String? iconeId,
    required String nome,
    double size = 56,
  }) {
    if (fotoBase64 != null && fotoBase64.isNotEmpty) {
      try {
        final bytes = base64Decode(fotoBase64);
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(
            bytes,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildFallbackProdutoIcon(iconeId, nome, size),
          ),
        );
      } catch (_) {}
    }

    return _buildFallbackProdutoIcon(iconeId, nome, size);
  }

  static Widget _buildFallbackProdutoIcon(String? iconeId, String nome, double size) {
    final iconeData = iconeId != null ? iconesProduto[iconeId] : null;
    final emoji = iconeData?.emoji ?? '🎁';

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: iconeData?.corFundo ?? const Color(0xFFFFF9E6),
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Text(
        emoji,
        style: TextStyle(fontSize: size * 0.55),
      ),
    );
  }
}
