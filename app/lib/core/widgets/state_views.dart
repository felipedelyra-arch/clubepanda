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

/// Badge de pontos (gamificação).
class PointsBadge extends StatelessWidget {
  const PointsBadge({super.key, required this.pontos});

  final int pontos;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: PandaColors.laranja.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, color: PandaColors.laranja, size: 18),
          const SizedBox(width: 4),
          Text(
            '$pontos pts',
            style: const TextStyle(
              color: PandaColors.laranja,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
