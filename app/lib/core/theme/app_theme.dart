import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';

/// Tema claro/escuro do Clube Panda. Cantos arredondados, sombras suaves,
/// muito espaço em branco. Tipografia Poppins.
abstract class AppTheme {
  static const _radius = 16.0;

  static ThemeData get light => _base(Brightness.light);
  static ThemeData get dark => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final scheme = ColorScheme.fromSeed(
      seedColor: PandaColors.laranja,
      brightness: brightness,
      primary: PandaColors.laranja,
      secondary: PandaColors.vermelhoAcento,
      error: PandaColors.vermelhoAcento,
      surface: isDark ? PandaColors.superficieDark : PandaColors.branco,
    );

    final scaffoldBg = isDark ? PandaColors.fundoDark : PandaColors.branco;
    final cardBg = isDark ? PandaColors.cardDark : PandaColors.cinzaClaro;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffoldBg,
      textTheme: GoogleFonts.poppinsTextTheme(
        ThemeData(brightness: brightness).textTheme,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBg,
        foregroundColor: isDark ? PandaColors.branco : PandaColors.preto,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: isDark ? PandaColors.branco : PandaColors.preto,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: PandaColors.laranja,
          foregroundColor: PandaColors.branco,
          disabledBackgroundColor: PandaColors.cinzaTexto,
          minimumSize: const Size.fromHeight(52),
          elevation: 0,
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: PandaColors.laranja,
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: PandaColors.laranja, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardBg,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: PandaColors.laranja, width: 1.5),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: cardBg,
        selectedColor: PandaColors.laranja,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: scaffoldBg,
        selectedItemColor: PandaColors.laranja,
        unselectedItemColor: PandaColors.cinzaTexto,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }
}
