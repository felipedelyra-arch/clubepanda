import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/services.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/panda_logo.dart';
import '../../core/widgets/state_views.dart';
import '../../core/models/models.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final promos = ref.watch(promotionsProvider);
    final isSub = ref.watch(isSubscriberProvider);
    final primeiroNome = user.value?.nome.split(' ').first ?? 'panda';

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: PandaColors.laranja,
          onRefresh: () async => ref.invalidate(promotionsProvider),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const PandaLogo(size: 40, showWordmark: false),
                  user.when(
                    data: (u) => PointsBadge(pontos: u?.pontos ?? 0),
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Text('Olá, $primeiroNome',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 4),
              Text(
                isSub ? 'Bom te ver de novo por aqui.' : 'Que tal um japa hoje?',
                style: const TextStyle(color: PandaColors.cinzaTexto, fontSize: 15),
              ),
              const SizedBox(height: 24),
              if (!isSub) const _AssineBanner(),
              const SizedBox(height: 32),
              const _SectionLabel('Promoções'),
              const SizedBox(height: 14),
              promos.when(
                loading: () => const Padding(
                    padding: EdgeInsets.only(top: 32), child: LoadingView()),
                error: (e, _) => ErrorView(
                    mensagem: 'Não deu pra carregar as promoções.',
                    onRetry: () => ref.invalidate(promotionsProvider)),
                data: (list) {
                  final visiveis =
                      list.where((p) => !p.apenasAssinantes || isSub).toList();
                  if (visiveis.isEmpty) {
                    return const EmptyView(
                      mensagem: 'Nenhuma promoção agora.\nVolte logo — tem novidade toda semana.',
                      icone: Icons.local_offer_outlined,
                    );
                  }
                  return Column(
                    children: [
                      for (final p in visiveis) ...[
                        _PromoCard(promo: p),
                        const SizedBox(height: 16),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rótulo de seção (eyebrow) — maiúsculas, espaçado, com traço laranja.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.texto);
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 20, height: 2, color: PandaColors.laranja),
        const SizedBox(width: 10),
        Text(
          texto.toUpperCase(),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
            color: PandaColors.cinzaTexto,
          ),
        ),
      ],
    );
  }
}

class _AssineBanner extends StatelessWidget {
  const _AssineBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: PandaColors.laranjaSuave,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Entre pro Clube',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(color: PandaColors.laranjaEscuro)),
          const SizedBox(height: 6),
          const Text(
            'Rodízios, prêmios e promoções exclusivas todo mês.',
            style: TextStyle(color: PandaColors.preto, height: 1.4),
          ),
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: () => context.go('/planos'),
            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            child: const Text('Ver planos'),
          ),
        ],
      ),
    );
  }
}

class _PromoCard extends StatelessWidget {
  const _PromoCard({required this.promo});
  final Promotion promo;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? PandaColors.cardDark : PandaColors.branco,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? PandaColors.hairlineDark : PandaColors.hairline,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (promo.imagem != null)
            Image.network(
              promo.imagem!,
              height: 150,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _fallback(),
            )
          else
            _fallback(),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(promo.titulo,
                          style: Theme.of(context).textTheme.titleLarge),
                    ),
                    if (promo.apenasAssinantes)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: PandaColors.laranjaSuave,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('Clube',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: PandaColors.laranjaEscuro)),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(promo.descricao,
                    style: const TextStyle(
                        color: PandaColors.cinzaTexto, height: 1.45)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallback() {
    return Container(
      height: 150,
      width: double.infinity,
      color: PandaColors.laranjaSuave,
      child: const Center(
        child: Icon(Icons.ramen_dining, size: 40, color: PandaColors.laranja),
      ),
    );
  }
}
