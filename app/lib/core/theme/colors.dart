import 'package:flutter/material.dart';

/// Paleta Clube Panda (Tio Panda) — laranja sóbrio e minimalista.
/// Laranja é acento (CTA, destaques), não preenchimento. Base em neutros quentes.
abstract class PandaColors {
  // Marca
  static const laranja = Color(0xFFE86A22); // primária / CTA (modesto)
  static const laranjaEscuro = Color(0xFFC9591A); // pressed
  static const laranjaSuave = Color(0xFFF6EDE4); // fundo de acento leve

  // Neutros quentes (claro)
  static const fundo = Color(0xFFFBF9F5); // papel quente
  static const branco = Color(0xFFFFFFFF); // superfície de card
  static const cinzaClaro = Color(0xFFF4EFE8); // superfície alternativa
  static const hairline = Color(0xFFEBE4D9); // divisores/bordas
  static const preto = Color(0xFF201B15); // texto principal (carvão quente)
  static const cinzaTexto = Color(0xFF8C8377); // texto secundário

  // Estados
  static const verdeSucesso = Color(0xFF2FA36B);
  static const vermelhoAcento = Color(0xFFE23B2E); // sushi da logo (raro)

  // Neutros quentes (escuro)
  static const fundoDark = Color(0xFF141210);
  static const superficieDark = Color(0xFF1E1B17);
  static const cardDark = Color(0xFF262119);
  static const hairlineDark = Color(0x14FFFFFF);
}
