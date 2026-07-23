import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// Estado de carregamento centralizado (spinner laranja).
class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: PandaColors.laranja),
    );
  }
}

/// Estado vazio com ícone, mensagem e ação opcional.
class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.mensagem,
    this.icone = Icons.inbox_outlined,
    this.acao,
  });

  final String mensagem;
  final IconData icone;
  final Widget? acao;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, size: 64, color: PandaColors.cinzaTexto),
            const SizedBox(height: 16),
            Text(
              mensagem,
              textAlign: TextAlign.center,
              style: const TextStyle(color: PandaColors.cinzaTexto, fontSize: 16),
            ),
            if (acao != null) ...[const SizedBox(height: 24), acao!],
          ],
        ),
      ),
    );
  }
}

/// Estado de erro com botão de tentar de novo.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.mensagem, this.onRetry});

  final String mensagem;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                size: 64, color: PandaColors.vermelhoAcento),
            const SizedBox(height: 16),
            Text(mensagem,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16)),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              OutlinedButton(onPressed: onRetry, child: const Text('Tentar de novo')),
            ],
          ],
        ),
      ),
    );
  }
}

/// Rótulo de seção (eyebrow) — maiúsculas espaçadas com traço laranja.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.texto, {super.key});
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 20, height: 2, color: PandaColors.laranja),
        const SizedBox(width: 10),
        Text(texto.toUpperCase(),
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
                color: PandaColors.cinzaTexto)),
      ],
    );
  }
}

/// Badge de pontos (gamificação).
class PointsBadge extends StatelessWidget {
  const PointsBadge({super.key, required this.pontos});

  final int pontos;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: PandaColors.laranjaSuave,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, color: PandaColors.laranja, size: 17),
          const SizedBox(width: 5),
          Text(
            '$pontos',
            style: const TextStyle(
              color: PandaColors.laranjaEscuro,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 3),
          const Text('pts',
              style: TextStyle(
                color: PandaColors.laranjaEscuro,
                fontWeight: FontWeight.w500,
                fontSize: 12,
              )),
        ],
      ),
    );
  }
}
