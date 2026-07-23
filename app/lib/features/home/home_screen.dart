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

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(promotionsProvider);
          },
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const PandaLogo(size: 40),
                  user.when(
                    data: (u) => PointsBadge(pontos: u?.pontos ?? 0),
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              user.when(
                data: (u) => Text(
                  'Olá, ${u?.nome.split(' ').first ?? 'panda'} 👋',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 16),
              if (!isSub) _AssineBanner(),
              const SizedBox(height: 24),
              Text('Promoções', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              promos.when(
                loading: () => const Padding(
                    padding: EdgeInsets.all(32), child: LoadingView()),
                error: (e, _) => ErrorView(
                    mensagem: 'Erro ao carregar promoções.',
                    onRetry: () => ref.invalidate(promotionsProvider)),
                data: (list) {
                  final visiveis =
                      list.where((p) => !p.apenasAssinantes || isSub).toList();
                  if (visiveis.isEmpty) {
                    return const EmptyView(
                      mensagem: 'Nenhuma promoção agora. Volte logo! 🍣',
                      icone: Icons.local_offer_outlined,
                    );
                  }
                  return Column(
                    children:
                        visiveis.map((p) => _PromoCard(promo: p)).toList(),
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

class _AssineBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [PandaColors.laranja, PandaColors.laranjaEscuro],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Vire assinante do Clube Panda',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('Rodízios, prêmios e promoções exclusivas 🐼',
              style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: PandaColors.laranja,
              minimumSize: const Size(140, 44),
            ),
            onPressed: () => context.go('/planos'),
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
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (promo.imagem != null)
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.network(
                promo.imagem!,
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  height: 160,
                  color: PandaColors.cinzaClaro,
                  child: const Icon(Icons.image_not_supported_outlined,
                      color: PandaColors.cinzaTexto),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(promo.titulo,
                          style: Theme.of(context).textTheme.titleMedium),
                    ),
                    if (promo.apenasAssinantes)
                      const Chip(
                        label: Text('Assinante',
                            style: TextStyle(fontSize: 11)),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(promo.descricao,
                    style: const TextStyle(color: PandaColors.cinzaTexto)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
