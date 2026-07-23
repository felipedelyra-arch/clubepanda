import 'package:flutter/material.dart';

/// Paleta Clube Panda (Tio Panda). Baseada na logo do panda com chapéu.
abstract class PandaColors {
  static const laranja = Color(0xFFF47A20); // primária / CTA
  static const laranjaEscuro = Color(0xFFD9631A); // hover / pressed
  static const preto = Color(0xFF1A1A1A); // texto / topbar
  static const branco = Color(0xFFFFFFFF); // fundo
  static const cinzaClaro = Color(0xFFF5F5F5); // cards / superfícies
  static const cinzaTexto = Color(0xFF8A8A8A); // texto secundário
  static const verdeSucesso = Color(0xFF2FBF71); // pagamento OK
  static const vermelhoAcento = Color(0xFFE23B2E); // sushi da logo

  // Superfícies do tema escuro
  static const fundoDark = Color(0xFF121212);
  static const superficieDark = Color(0xFF1E1E1E);
  static const cardDark = Color(0xFF262626);
}
