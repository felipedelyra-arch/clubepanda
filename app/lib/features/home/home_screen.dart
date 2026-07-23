import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/services.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/panda_logo.dart';
import '../../core/widgets/state_views.dart';
import '../../core/models/models.dart';

/// Renderiza imagem de asset local ou de URL (Firestore), com fallback.
Widget _imagemPromo(String path, {BoxFit fit = BoxFit.cover, Widget? erro}) {
  final fallback = erro ?? const SizedBox.shrink();
  if (path.startsWith('assets/')) {
    return Image.asset(path, fit: fit,
        errorBuilder: (_, _, _) => fallback);
  }
  return Image.network(path, fit: fit, errorBuilder: (_, _, _) => fallback);
}

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
                children: [
                  const PandaLogo(size: 40, showWordmark: false),
                  user.when(
                    data: (u) => PointsBadge(pontos: u?.pontos ?? 0),
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              Text('Olá, $primeiroNome',
                  style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 8),
              if (isSub)
                const _StatusSocio()
              else
                Text('Que tal um japa hoje?',
                    style: const TextStyle(
                        color: PandaColors.cinzaTexto, fontSize: 15)),
              const SizedBox(height: 24),
              if (!isSub) ...[
                const _AssineBanner(),
                const SizedBox(height: 28),
              ],
              _AtalhosRow(),
              const SizedBox(height: 32),
              const SectionLabel('Promoções'),
              const SizedBox(height: 16),
              promos.when(
                loading: () => const Padding(
                    padding: EdgeInsets.only(top: 24), child: LoadingView()),
                error: (e, _) => ErrorView(
                    mensagem: 'Não deu pra carregar as promoções.',
                    onRetry: () => ref.invalidate(promotionsProvider)),
                data: (list) {
                  final visiveis =
                      list.where((p) => !p.apenasAssinantes || isSub).toList();
                  if (visiveis.isEmpty) {
                    return const EmptyView(
                      mensagem:
                          'Nenhuma promoção agora.\nVolte logo — tem novidade toda semana.',
                      icone: Icons.local_offer_outlined,
                    );
                  }
                  return Column(
                    children: [
                      _PromoHero(promo: visiveis.first),
                      for (final p in visiveis.skip(1)) ...[
                        const SizedBox(height: 14),
                        _PromoCard(promo: p),
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

/// Chip de status de sócio ativo.
class _StatusSocio extends StatelessWidget {
  const _StatusSocio();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: PandaColors.verdeSucesso.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_rounded, color: PandaColors.verdeSucesso, size: 16),
          SizedBox(width: 6),
          Text('Sócio do Clube',
              style: TextStyle(
                  color: PandaColors.verdeSucesso,
                  fontWeight: FontWeight.w600,
                  fontSize: 13)),
        ],
      ),
    );
  }
}

/// Linha de atalhos rápidos.
class _AtalhosRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Atalho(
          icone: Icons.card_giftcard_outlined,
          label: 'Prêmios',
          onTap: () => context.go('/premiacoes'),
        ),
        const SizedBox(width: 12),
        _Atalho(
          icone: Icons.workspace_premium_outlined,
          label: 'Meu plano',
          onTap: () => context.go('/planos'),
        ),
        const SizedBox(width: 12),
        _Atalho(
          icone: Icons.restaurant_menu_outlined,
          label: 'Cardápio',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Cardápio em breve 🍣')),
            );
          },
        ),
      ],
    );
  }
}

class _Atalho extends StatelessWidget {
  const _Atalho({required this.icone, required this.label, required this.onTap});
  final IconData icone;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Material(
        color: isDark ? PandaColors.cardDark : PandaColors.branco,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color:
                      isDark ? PandaColors.hairlineDark : PandaColors.hairline),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              children: [
                Icon(icone, color: PandaColors.laranja, size: 24),
                const SizedBox(height: 8),
                Text(label,
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ),
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
          const Text('Rodízios, prêmios e promoções exclusivas todo mês.',
              style: TextStyle(color: PandaColors.preto, height: 1.4)),
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: () => context.go('/planos'),
            style:
                ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            child: const Text('Ver planos'),
          ),
        ],
      ),
    );
  }
}

/// Promoção em destaque. Com imagem: foto + gradiente + texto branco.
/// Sem imagem: card suave (laranja claro), texto escuro, acento discreto.
class _PromoHero extends StatelessWidget {
  const _PromoHero({required this.promo});
  final Promotion promo;

  @override
  Widget build(BuildContext context) {
    return promo.imagem != null ? _comImagem(context) : _suave(context);
  }

  Widget _badge(Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
        child: Text('EXCLUSIVO CLUBE',
            style: TextStyle(
                color: fg,
                fontSize: 10,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w700)),
      );

  Widget _comImagem(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Stack(
        children: [
          SizedBox(
            height: 210,
            width: double.infinity,
            child: _imagemPromo(promo.imagem!,
                erro: Container(color: PandaColors.laranjaSuave)),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.72)],
                  stops: const [0.35, 1],
                ),
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (promo.apenasAssinantes) ...[
                  _badge(PandaColors.laranja, Colors.white),
                  const SizedBox(height: 8),
                ],
                Text(promo.titulo,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(color: Colors.white)),
                const SizedBox(height: 4),
                Text(promo.descricao,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85), height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _suave(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: PandaColors.laranjaSuave,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: PandaColors.laranja,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.local_fire_department_rounded,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              if (promo.apenasAssinantes)
                _badge(PandaColors.laranja, Colors.white)
              else
                const Text('EM DESTAQUE',
                    style: TextStyle(
                        color: PandaColors.laranjaEscuro,
                        fontSize: 11,
                        letterSpacing: 1,
                        fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 16),
          Text(promo.titulo,
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(promo.descricao,
              style: const TextStyle(color: PandaColors.preto, height: 1.4)),
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
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: isDark ? PandaColors.hairlineDark : PandaColors.hairline),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: PandaColors.laranjaSuave,
              borderRadius: BorderRadius.circular(14),
            ),
            clipBehavior: Clip.antiAlias,
            child: promo.imagem != null
                ? _imagemPromo(promo.imagem!,
                    erro: const Icon(Icons.local_offer,
                        color: PandaColors.laranja))
                : const Icon(Icons.local_offer, color: PandaColors.laranja),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(promo.titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 2),
                Text(promo.descricao,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: PandaColors.cinzaTexto, fontSize: 13, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
