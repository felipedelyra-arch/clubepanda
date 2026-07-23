import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// Logo reutilizável do Clube Panda. Troque o asset em
/// `assets/logo/panda_logo.png` — enquanto não existir, cai num fallback
/// desenhado (emoji + wordmark) pra UI nunca quebrar.
class PandaLogo extends StatelessWidget {
  const PandaLogo({
    super.key,
    this.size = 48,
    this.showWordmark = true,
    this.useAsset = true,
  });

  final double size;
  final bool showWordmark;

  /// Liga quando o asset real estiver adicionado ao pubspec.
  final bool useAsset;

  @override
  Widget build(BuildContext context) {
    if (useAsset) {
      return Image.asset('assets/logo/panda_logo.png', height: size);
    }

    final mark = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: PandaColors.laranja,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      alignment: Alignment.center,
      child: Text('🐼', style: TextStyle(fontSize: size * 0.55)),
    );

    if (!showWordmark) return mark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        SizedBox(width: size * 0.28),
        DefaultTextStyle(
          style: const TextStyle(height: 1.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Clube Panda',
                style: TextStyle(
                  fontSize: size * 0.42,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).textTheme.titleLarge?.color,
                ),
              ),
              Text(
                'Tio Panda',
                style: TextStyle(
                  fontSize: size * 0.26,
                  fontWeight: FontWeight.w500,
                  color: PandaColors.cinzaTexto,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
