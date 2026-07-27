import 'package:flutter/material.dart';
import 'colors.dart';
import 'dimens.dart';

/// Tema Clube Panda — minimalista, quente, laranja sóbrio como acento.
/// Corpo sempre em Inter. Títulos dependem de [usarSerifa]:
/// Fraunces (serifa, ar de restaurante) ou Inter com tracking negativo
/// (ar de produto de tecnologia).
/// Fontes empacotadas localmente (ver pubspec) — sem download em runtime.
abstract class AppTheme {
  /// Chave única pra comparar as duas identidades tipográficas.
  ///
  /// `false` (atual): títulos em Inter apertado — visual mais tecnológico.
  /// `true`: volta tudo pra Fraunces, exatamente como era antes.
  ///
  /// Independente do valor, a saudação da Home continua em serifa
  /// (ver [assinatura]) — é o meio-termo: a serifa vira assinatura da
  /// marca num ponto só, em vez de tema de todas as telas.
  static const bool usarSerifa = false;

  static const _corpo = 'Inter';

  /// Família serifada, exposta pros pontos que a usam à parte do tema.
  static const serifa = 'Fraunces';

  static String get _titulo => usarSerifa ? serifa : _corpo;

  /// Tracking negativo proporcional ao tamanho. É o que separa "Inter tight"
  /// (produto de tecnologia) de "Inter padrão" (dashboard genérico).
  /// Em Fraunces fica zero — serifa apertada fica ilegível.
  static double _tracking(double? tamanho) {
    if (usarSerifa) return 0;
    final s = tamanho ?? 20;
    if (s >= 32) return -s * 0.032;
    if (s >= 24) return -s * 0.026;
    return -s * 0.018;
  }

  /// Força a serifa num estilo específico, seja qual for [usarSerifa].
  /// Usado na saudação da Home.
  static TextStyle assinatura(TextStyle? base) =>
      (base ?? const TextStyle()).copyWith(
        fontFamily: serifa,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        height: 1.15,
      );

  static ThemeData get light => _base(Brightness.light);
  static ThemeData get dark => _base(Brightness.dark);

  static TextTheme _textTheme(Brightness b) {
    final corpo = ThemeData(brightness: b).textTheme.apply(fontFamily: _corpo);
    final cor = b == Brightness.dark ? PandaColors.branco : PandaColors.preto;

    TextStyle titulo(TextStyle? base) => (base ?? const TextStyle()).copyWith(
          fontFamily: _titulo,
          // Inter precisa de mais peso que Fraunces pra manter presença.
          fontWeight: usarSerifa ? FontWeight.w600 : FontWeight.w700,
          letterSpacing: _tracking(base?.fontSize),
          height: usarSerifa ? null : 1.12,
          color: cor,
        );

    return corpo.copyWith(
      displayLarge: titulo(corpo.displayLarge),
      displayMedium: titulo(corpo.displayMedium),
      headlineLarge: titulo(corpo.headlineLarge),
      headlineMedium: titulo(corpo.headlineMedium),
      headlineSmall: titulo(corpo.headlineSmall),
      titleLarge: titulo(corpo.titleLarge),
    ).apply(bodyColor: cor, displayColor: cor);
  }

  static ThemeData _base(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final scheme = ColorScheme.fromSeed(
      seedColor: PandaColors.laranja,
      brightness: brightness,
      primary: PandaColors.laranja,
      onPrimary: Colors.white,
      secondary: PandaColors.laranja,
      surface: isDark ? PandaColors.superficieDark : PandaColors.branco,
    );

    final scaffoldBg = isDark ? PandaColors.fundoDark : PandaColors.fundo;
    final cardBg = isDark ? PandaColors.cardDark : PandaColors.branco;
    final hairline = isDark ? PandaColors.hairlineDark : PandaColors.hairline;
    final textoPrincipal = isDark ? PandaColors.branco : PandaColors.preto;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: _corpo,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffoldBg,
      textTheme: _textTheme(brightness),
      dividerTheme: DividerThemeData(color: hairline, thickness: 1, space: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBg,
        surfaceTintColor: Colors.transparent,
        foregroundColor: textoPrincipal,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: _titulo,
          fontSize: 22,
          fontWeight: usarSerifa ? FontWeight.w600 : FontWeight.w700,
          letterSpacing: _tracking(22),
          color: textoPrincipal,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardBg,
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: 0.04),
        shape: RoundedRectangleBorder(
          borderRadius: PandaRadius.bmd,
          side: BorderSide(color: hairline),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: PandaColors.laranja,
          foregroundColor: Colors.white,
          disabledBackgroundColor: PandaColors.cinzaTexto.withValues(alpha: 0.3),
          minimumSize: const Size.fromHeight(54),
          elevation: 0,
          textStyle: const TextStyle(
              fontFamily: _corpo, fontSize: 15, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: PandaRadius.bmd),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textoPrincipal,
          minimumSize: const Size.fromHeight(54),
          side: BorderSide(color: hairline, width: 1.4),
          textStyle: const TextStyle(
              fontFamily: _corpo, fontSize: 15, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: PandaRadius.bmd),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: PandaColors.laranja,
          textStyle: const TextStyle(
              fontFamily: _corpo, fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? PandaColors.cardDark : PandaColors.cinzaClaro,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        hintStyle: const TextStyle(color: PandaColors.cinzaTexto),
        labelStyle: const TextStyle(color: PandaColors.cinzaTexto),
        border: OutlineInputBorder(
          borderRadius: PandaRadius.bmd,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: PandaRadius.bmd,
          borderSide: BorderSide(color: hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: PandaRadius.bmd,
          borderSide: const BorderSide(color: PandaColors.laranja, width: 1.6),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? PandaColors.cardDark : PandaColors.cinzaClaro,
        side: BorderSide(color: hairline),
        labelStyle: const TextStyle(
            fontFamily: _corpo, fontSize: 12, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: PandaRadius.bsm),
      ),
      // Barra inferior Material 3 — indicador em pill, sem o visual datado
      // do BottomNavigationBar (M2).
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: cardBg,
        surfaceTintColor: Colors.transparent,
        indicatorColor:
            PandaColors.laranja.withValues(alpha: isDark ? 0.24 : 0.13),
        indicatorShape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 0,
        height: 70,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (estados) => IconThemeData(
            size: 24,
            color: estados.contains(WidgetState.selected)
                ? PandaColors.laranja
                : PandaColors.cinzaTexto,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (estados) => TextStyle(
            fontFamily: _corpo,
            fontSize: 11.5,
            fontWeight: estados.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: estados.contains(WidgetState.selected)
                ? PandaColors.laranja
                : PandaColors.cinzaTexto,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: PandaColors.preto,
        contentTextStyle:
            const TextStyle(fontFamily: _corpo, color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: PandaRadius.bsm),
      ),
    );
  }
}
