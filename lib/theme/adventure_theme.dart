import 'package:flutter/material.dart';

class AdventureTheme {
  // Paleta de Cores Stitch (Claro / Padrão)
  static const Color surface = Color(0xFFFAF3E0);
  static const Color surfaceVariant = Color(0xFFF3EAD3);
  static const Color forestGreen = Color(0xFF2A9D8F);
  static const Color forestGreenDark = Color(0xFF1F756B);
  static const Color skyBlue = Color(0xFF219EBC);
  static const Color skyBlueDark = Color(0xFF166B80);
  static const Color goldCoin = Color(0xFFFFB703);
  static const Color goldDark = Color(0xFFD48B00);
  static const Color woodBrown = Color(0xFF8B5A2B);
  static const Color woodDark = Color(0xFF5E3B1B);
  static const Color errorCoral = Color(0xFFE76F51);
  static const Color textDark = Color(0xFF2D261E);
  static const Color textMuted = Color(0xFF6B5E50);

  // Paleta de Cores Stitch (Escuro / Dark Mode)
  static const Color darkSurface = Color(0xFF221C16);
  static const Color darkSurfaceVariant = Color(0xFF322921);
  static const Color darkOutline = Color(0xFFD4A373);
  static const Color darkTextLight = Color(0xFFF7EDE2);
  static const Color darkTextMuted = Color(0xFFC4B5A5);

  // Controle Global Reativo do Modo de Tema (Claro, Escuro ou Automático com o Sistema)
  static final ValueNotifier<ThemeMode> themeModeNotifier =
      ValueNotifier<ThemeMode>(ThemeMode.system);

  /// Alterna ciclicamente: Sistema -> Claro -> Escuro -> Sistema
  static void alternarTemaRapido() {
    switch (themeModeNotifier.value) {
      case ThemeMode.system:
        themeModeNotifier.value = ThemeMode.light;
        break;
      case ThemeMode.light:
        themeModeNotifier.value = ThemeMode.dark;
        break;
      case ThemeMode.dark:
        themeModeNotifier.value = ThemeMode.system;
        break;
    }
  }

  // Estilos de Texto (Fredoka / Nunito)
  static const TextStyle titleFredoka = TextStyle(
    fontFamily: 'Fredoka',
    fontWeight: FontWeight.w700,
  );

  static const TextStyle bodyNunito = TextStyle(
    fontFamily: 'Nunito',
    fontWeight: FontWeight.w600,
  );

  /// Tema Claro ("Exploradores / Parchment")
  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: surface,
        dialogTheme: const DialogThemeData(
          backgroundColor: surface,
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: forestGreen,
          brightness: Brightness.light,
          surface: surface,
          primary: forestGreen,
          secondary: goldCoin,
          tertiary: skyBlue,
          error: errorCoral,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: surface,
          foregroundColor: textDark,
          elevation: 0,
        ),
      );

  /// Tema Escuro ("Exploradores Noturnos / Stitch Dark")
  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: darkSurface,
        dialogTheme: const DialogThemeData(
          backgroundColor: darkSurfaceVariant,
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF48CAE4),
          brightness: Brightness.dark,
          surface: darkSurface,
          primary: const Color(0xFF48CAE4),
          secondary: const Color(0xFFFFD166),
          tertiary: const Color(0xFF52B788),
          error: errorCoral,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: darkSurface,
          foregroundColor: darkTextLight,
          elevation: 0,
        ),
      );

  static ThemeData get themeData => lightTheme;
}

/// Card tátil 3D com borda sólida e sombra de bloco dura (sem blur)
class AdventureCard extends StatelessWidget {
  final Widget child;
  final Color? backgroundColor;
  final Color? borderColor;
  final Color? shadowColor;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const AdventureCard({
    super.key,
    required this.child,
    this.backgroundColor,
    this.borderColor,
    this.shadowColor,
    this.borderRadius = 20,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = backgroundColor ?? (isDark ? AdventureTheme.darkSurfaceVariant : Colors.white);
    final border = borderColor ?? (isDark ? AdventureTheme.darkOutline : AdventureTheme.woodBrown);
    final shadow = shadowColor ?? (isDark ? Colors.black45 : AdventureTheme.woodDark);

    final cardContent = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: border, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: shadow,
            offset: const Offset(0, 5),
            blurRadius: 0,
          ),
        ],
      ),
      child: child,
    );

    if (onTap == null) return cardContent;

    return GestureDetector(
      onTap: onTap,
      child: cardContent,
    );
  }
}

/// Botão tátil 3D com deslocamento de compressão em 100ms
class AdventureButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? borderColor;
  final Color? shadowColor;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  const AdventureButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.backgroundColor,
    this.borderColor,
    this.shadowColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    this.borderRadius = 16,
  });

  @override
  State<AdventureButton> createState() => _AdventureButtonState();
}

class _AdventureButtonState extends State<AdventureButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg = widget.backgroundColor ??
        (isDark ? const Color(0xFF1E6B60) : AdventureTheme.forestGreen);
    final border = widget.borderColor ??
        (isDark ? const Color(0xFF165048) : AdventureTheme.forestGreenDark);
    final shadow = widget.shadowColor ??
        (isDark ? Colors.black54 : AdventureTheme.woodDark);

    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _isPressed = true) : null,
      onTapUp: enabled ? (_) => setState(() => _isPressed = false) : null,
      onTapCancel: enabled ? () => setState(() => _isPressed = false) : null,
      onTap: widget.onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        transform: Matrix4.translationValues(0, _isPressed ? 3 : 0, 0),
        padding: widget.padding,
        decoration: BoxDecoration(
          color: enabled ? bg : Colors.grey.shade600,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: Border.all(
            color: enabled ? border : Colors.grey.shade700,
            width: 2.2,
          ),
          boxShadow: [
            BoxShadow(
              color: enabled ? shadow : Colors.transparent,
              offset: Offset(0, _isPressed ? 2 : 5),
              blurRadius: 0,
            ),
          ],
        ),
        child: widget.child,
      ),
    );
  }
}
