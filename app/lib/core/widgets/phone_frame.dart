import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Mostra o app dentro de um "celular" quando roda em tela larga no navegador
/// (só demonstração web). Em janela estreita ou app nativo, renderiza direto.
class PhoneFrame extends StatelessWidget {
  const PhoneFrame({super.key, required this.child});

  final Widget child;

  // Dimensões aproximadas de um celular moderno (lógicas).
  static const _w = 390.0;
  static const _h = 844.0;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final ehTelaLarga = kIsWeb && size.width > 600 && size.height > 400;

    if (!ehTelaLarga) return child;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    // MediaQuery do conteúdo passa a valer o tamanho do "celular".
    final conteudo = MediaQuery(
      data: MediaQuery.of(context).copyWith(
        size: const Size(_w, _h),
        padding: const EdgeInsets.only(top: 44, bottom: 24), // notch + home bar
        viewPadding: const EdgeInsets.only(top: 44, bottom: 24),
      ),
      child: child,
    );

    return Container(
      color: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFE8E8E8),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: _w + 16,
            height: _h + 16,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A), // moldura preta
              borderRadius: BorderRadius.circular(52),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 40,
                  spreadRadius: 4,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(44),
              child: SizedBox(
                width: _w,
                height: _h,
                child: Stack(
                  children: [
                    Positioned.fill(child: conteudo),
                    // Notch (ilha).
                    Positioned(
                      top: 10,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          width: 120,
                          height: 30,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A1A),
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Clube Panda — pré-visualização (demo web)',
            style: TextStyle(
              color: isDark ? Colors.white54 : Colors.black45,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
