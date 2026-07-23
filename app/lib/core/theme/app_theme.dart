import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';

/// Tema Clube Panda — minimalista, quente, laranja sóbrio como acento.
/// Títulos em Fraunces (serifa suave, ar de restaurante), corpo em Inter.
abstract class AppTheme {
  static ThemeData get light => _base(Brightness.light);
  static ThemeData get dark => _base(Brightness.dark);

  static TextTheme _textTheme(Brightness b) {
    final base = ThemeData(brightness: b).textTheme;
    final corpo = GoogleFonts.interTextTheme(base);
    final cor = b == Brightness.dark ? PandaColors.branco : PandaColors.preto;
    return corpo.copyWith(
      displayLarge: GoogleFonts.fraunces(textStyle: corpo.displayLarge, fontWeight: FontWeight.w600, color: cor),
      displayMedium: GoogleFonts.fraunces(textStyle: corpo.displayMedium, fontWeight: FontWeight.w600, color: cor),
      headlineLarge: GoogleFonts.fraunces(textStyle: corpo.headlineLarge, fontWeight: FontWeight.w600, color: cor),
      headlineMedium: GoogleFonts.fraunces(textStyle: corpo.headlineMedium, fontWeight: FontWeight.w600, color: cor),
      headlineSmall: GoogleFonts.fraunces(textStyle: corpo.headlineSmall, fontWeight: FontWeight.w600, color: cor),
      titleLarge: GoogleFonts.fraunces(textStyle: corpo.titleLarge, fontWeight: FontWeight.w600, color: cor),
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
        titleTextStyle: GoogleFonts.fraunces(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: textoPrincipal,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardBg,
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: 0.04),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
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
          textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textoPrincipal,
          minimumSize: const Size.fromHeight(54),
          side: BorderSide(color: hairline, width: 1.4),
          textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: PandaColors.laranja,
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? PandaColors.cardDark : PandaColors.cinzaClaro,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        hintStyle: const TextStyle(color: PandaColors.cinzaTexto),
        labelStyle: const TextStyle(color: PandaColors.cinzaTexto),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: PandaColors.laranja, width: 1.6),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? PandaColors.cardDark : PandaColors.cinzaClaro,
        side: BorderSide(color: hairline),
        labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: cardBg,
        selectedItemColor: PandaColors.laranja,
        unselectedItemColor: PandaColors.cinzaTexto,
        selectedLabelStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 11),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: PandaColors.preto,
        contentTextStyle: GoogleFonts.inter(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
