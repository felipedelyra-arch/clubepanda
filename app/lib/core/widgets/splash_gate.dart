import 'package:flutter/material.dart';

import '../theme/colors.dart';
import 'panda_logo.dart';

/// Continua a splash nativa dentro do Flutter e sai dela com animação.
///
/// A splash do Android some no primeiro frame do Flutter. Sem isto, o app
/// saltava do laranja direto pra tela de login — funcional, mas seco. Aqui a
/// logo cresce, respira e a camada se abre revelando a tela que o router já
/// montou por baixo.
///
/// Fica **por cima** de tudo em vez de ser uma rota: o router decide sozinho
/// entre onboarding, login e home enquanto a animação roda, e quando a camada
/// abre a tela certa já está pronta. Como rota, daria pra ver a tela errada
/// por um frame antes do redirect acontecer.
class SplashGate extends StatefulWidget {
  const SplashGate({super.key, required this.child});

  final Widget child;

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate>
    with SingleTickerProviderStateMixin {
  static const _duracao = Duration(milliseconds: 1250);

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: _duracao,
  );

  /// Entrada da logo: 0 → 360ms.
  late final Animation<double> _logoOpacidade = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.0, 0.29, curve: Curves.easeOut),
  );

  /// Escala da logo em três tempos: entra pequena, assenta, e no fim cresce
  /// um tico junto com a abertura — dá a sensação de que a tela se abre a
  /// partir dela, em vez de a logo simplesmente desaparecer.
  late final Animation<double> _logoEscala = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(begin: 0.86, end: 1.0)
          .chain(CurveTween(curve: Curves.easeOutBack)),
      weight: 34,
    ),
    TweenSequenceItem(tween: ConstantTween(1.0), weight: 34),
    TweenSequenceItem(
      tween: Tween(begin: 1.0, end: 1.12)
          .chain(CurveTween(curve: Curves.easeIn)),
      weight: 32,
    ),
  ]).animate(_c);

  /// Abertura da camada laranja: só nos últimos 32% do tempo.
  late final Animation<double> _camadaOpacidade = Tween<double>(
    begin: 1.0,
    end: 0.0,
  ).animate(CurvedAnimation(
    parent: _c,
    curve: const Interval(0.68, 1.0, curve: Curves.easeInOut),
  ));

  bool _pronto = false;
  bool _iniciado = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_iniciado) return;
    _iniciado = true;

    // Acessibilidade: com "reduzir animações" ligado no sistema, a camada
    // simplesmente sai. Animação de abertura é enfeite, não informação.
    if (MediaQuery.disableAnimationsOf(context)) {
      setState(() => _pronto = true);
      return;
    }

    _c.forward().whenComplete(() {
      if (mounted) setState(() => _pronto = true);
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Terminou: para de construir a camada e de pintar por cima do app.
    if (_pronto) return widget.child;

    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              // IgnorePointer: enquanto a camada abre ela já está
              // semitransparente, e sem isso um toque apressado do sócio
              // "atravessaria" pra tela de baixo sem ele ver o que apertou.
              return IgnorePointer(
                child: Opacity(
                  opacity: _camadaOpacidade.value,
                  child: ColoredBox(
                    // Exatamente o mesmo laranja de `panda_laranja` no
                    // colors.xml do Android. Qualquer diferença aqui vira uma
                    // emenda visível quando a splash nativa dá lugar a esta.
                    color: PandaColors.laranja,
                    child: Center(
                      child: Opacity(
                        opacity: _logoOpacidade.value,
                        child: Transform.scale(
                          scale: _logoEscala.value,
                          child: const PandaLogo(size: 132),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
