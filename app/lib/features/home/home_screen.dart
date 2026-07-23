import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/services.dart';
import '../../core/demo.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/panda_logo.dart';
import '../../core/widgets/state_views.dart';
import '../../core/models/models.dart';

// Contato do restaurante. TODO: trocar pelos dados reais do Tio Panda.
const String _kTelefone = '551430000000'; // fixo, formato tel:
const String _kWhatsapp = '5514990000000'; // com DDI 55 + DDD
const String _kEndereco = 'Tio Panda restaurante';

Future<void> _abrirUrl(String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

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
              const _CarteirinhaCard(),
              const SizedBox(height: 16),
              _AtalhosRow(),
              const SizedBox(height: 32),
              const SectionLabel('Destaques do cardápio'),
              const SizedBox(height: 16),
              const _DestaquesRow(),
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
              const SizedBox(height: 34),
              const SectionLabel('Como funciona'),
              const SizedBox(height: 16),
              const _ComoFunciona(),
              const SizedBox(height: 34),
              const SectionLabel('Fale com a gente'),
              const SizedBox(height: 16),
              const _FaleConosco(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Passo a passo simples — pra quem tem pouca prática com app.
class _ComoFunciona extends StatelessWidget {
  const _ComoFunciona();

  @override
  Widget build(BuildContext context) {
    const passos = [
      (Icons.qr_code_2_rounded, 'Mostre o app', 'Ao pagar, mostre seu app no caixa.'),
      (Icons.star_rounded, 'Junte pontos', 'Cada visita soma pontos na sua conta.'),
      (Icons.card_giftcard_rounded, 'Troque por prêmios', 'Use os pontos em comidas e brindes.'),
    ];
    return Column(
      children: [
        for (var i = 0; i < passos.length; i++) ...[
          _PassoLinha(
            numero: i + 1,
            icone: passos[i].$1,
            titulo: passos[i].$2,
            texto: passos[i].$3,
          ),
          if (i < passos.length - 1) const SizedBox(height: 14),
        ],
      ],
    );
  }
}

class _PassoLinha extends StatelessWidget {
  const _PassoLinha(
      {required this.numero,
      required this.icone,
      required this.titulo,
      required this.texto});
  final int numero;
  final IconData icone;
  final String titulo;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: PandaColors.laranjaSuave,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icone, color: PandaColors.laranja, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$numero. $titulo',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15.5)),
              const SizedBox(height: 2),
              Text(texto,
                  style: const TextStyle(
                      color: PandaColors.cinzaTexto, fontSize: 13.5, height: 1.3)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Botões grandes de contato — fáceis pra qualquer idade.
class _FaleConosco extends StatelessWidget {
  const _FaleConosco();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ContatoBtn(
            icone: Icons.phone_rounded,
            label: 'Ligar',
            onTap: () => _abrirUrl('tel:$_kTelefone'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ContatoBtn(
            icone: Icons.chat_rounded,
            label: 'WhatsApp',
            onTap: () => _abrirUrl('https://wa.me/$_kWhatsapp'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ContatoBtn(
            icone: Icons.location_on_rounded,
            label: 'Como chegar',
            onTap: () => _abrirUrl(
                'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(_kEndereco)}'),
          ),
        ),
      ],
    );
  }
}

class _ContatoBtn extends StatelessWidget {
  const _ContatoBtn(
      {required this.icone, required this.label, required this.onTap});
  final IconData icone;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? PandaColors.cardDark : PandaColors.branco,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: isDark ? PandaColors.hairlineDark : PandaColors.hairline),
          ),
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Column(
            children: [
              Icon(icone, color: PandaColors.laranja, size: 26),
              const SizedBox(height: 8),
              Text(label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w600)),
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

/// Cartão de acesso rápido à carteirinha digital (mostrar no caixa).
class _CarteirinhaCard extends StatelessWidget {
  const _CarteirinhaCard();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () => context.go('/carteirinha'),
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [PandaColors.laranja, PandaColors.laranjaEscuro],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: PandaColors.laranja.withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(Icons.qr_code_2_rounded,
                    color: Colors.white, size: 30),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Minha carteirinha',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800)),
                    SizedBox(height: 2),
                    Text('Mostre no caixa e junte pontos',
                        style: TextStyle(color: Colors.white, fontSize: 13)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white),
            ],
          ),
        ),
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
          onTap: () => context.go('/cardapio'),
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

/// Vitrine horizontal de pratos (fotos reais) — só no modo demo.
class _DestaquesRow extends StatelessWidget {
  const _DestaquesRow();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: demoDestaques.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (_, i) => _DestaqueCard(prato: demoDestaques[i]),
      ),
    );
  }
}

class _DestaqueCard extends StatelessWidget {
  const _DestaqueCard({required this.prato});
  final DishHighlight prato;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: 158,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              height: 132,
              width: double.infinity,
              child: _imagemPromo(prato.imagem,
                  erro: Container(color: PandaColors.laranjaSuave)),
            ),
          ),
          const SizedBox(height: 10),
          Text(prato.nome,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 14.5)),
          const SizedBox(height: 2),
          Text(prato.preco,
              style: TextStyle(
                  color: isDark
                      ? PandaColors.laranja
                      : PandaColors.laranjaEscuro,
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5)),
        ],
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
