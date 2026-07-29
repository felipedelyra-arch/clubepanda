import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/services/services.dart';
import '../../core/demo.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/dimens.dart';
import '../../core/widgets/panda_logo.dart';
import '../../core/widgets/state_views.dart';
import '../../core/widgets/entrada.dart';
import '../../core/models/models.dart';

final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

/// Saudação conforme a hora — detalhe pequeno que faz o app parecer atento.
String _saudacao() {
  final h = DateTime.now().hour;
  if (h < 12) return 'Bom dia';
  if (h < 18) return 'Boa tarde';
  return 'Boa noite';
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
    final promos = ref.watch(promocoesVigentesProvider);
    final isSub = ref.watch(isSubscriberProvider);
    final primeiroNome = user.value?.nome.split(' ').first ?? 'panda';

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: PandaColors.laranja,
          onRefresh: () async => ref.invalidate(promotionsProvider),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            children: escalonar([
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const PandaLogo(size: 40, showWordmark: false),
                  const _SinoNotificacoes(),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(top: 26),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Único ponto em serifa: vira assinatura da marca em vez
                    // de tema geral do app.
                    Text('${_saudacao()}, $primeiroNome',
                        style: AppTheme.assinatura(
                            Theme.of(context).textTheme.headlineLarge)),
                    const SizedBox(height: 8),
                    if (isSub)
                      const _StatusSocio()
                    else
                      const Text('Que tal um japa hoje?',
                          style: TextStyle(
                              color: PandaColors.cinzaTexto, fontSize: 15)),
                  ],
                ),
              ),
              if (isSub)
                const Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: _EconomiaCard(),
                )
              else
                const Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: _AssineBanner(),
                ),
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: _CarteirinhaCard(),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: _AtalhosRow(),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    SectionLabel('Destaques do cardápio'),
                    SizedBox(height: 16),
                    _DestaquesRow(),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionLabel('Promoções'),
                    const SizedBox(height: 16),
                    promos.when(
                      loading: () => const Padding(
                          padding: EdgeInsets.only(top: 24),
                          child: LoadingView()),
                      error: (e, _) => ErrorView(
                          mensagem: 'Não deu pra carregar as promoções.',
                          onRetry: () => ref.invalidate(promotionsProvider)),
                      data: (list) {
                        final visiveis = list
                            .where((p) => !p.apenasAssinantes || isSub)
                            .toList();
                        if (visiveis.isEmpty) {
                          return const EmptyView(
                            mensagem:
                                'Nenhuma promoção no ar agora.\nVolte logo — tem novidade toda semana.',
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
              const Padding(
                padding: EdgeInsets.only(top: 34),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionLabel('Como funciona'),
                    SizedBox(height: 16),
                    _ComoFunciona(),
                  ],
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Sino de notificações com badge de não lidas — abre a central.
class _SinoNotificacoes extends ConsumerWidget {
  const _SinoNotificacoes();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final naoLidas = ref.watch(unreadCountProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: () => context.go('/notificacoes'),
      borderRadius: PandaRadius.bsm,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: isDark ? PandaColors.cardDark : PandaColors.branco,
          borderRadius: PandaRadius.bsm,
          border: Border.all(
              color: isDark ? PandaColors.hairlineDark : PandaColors.hairline),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Icon(Icons.notifications_none_rounded,
                size: 22, color: PandaColors.laranja),
            if (naoLidas > 0)
              Positioned(
                top: 8,
                right: 9,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  constraints:
                      const BoxConstraints(minWidth: 15, minHeight: 15),
                  decoration: BoxDecoration(
                    color: PandaColors.vermelhoAcento,
                    borderRadius: PandaRadius.bxs,
                    border: Border.all(
                        color: isDark
                            ? PandaColors.fundoDark
                            : PandaColors.fundo,
                        width: 1.5),
                  ),
                  child: Text(
                    naoLidas > 9 ? '9+' : '$naoLidas',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        height: 1),
                  ),
                ),
              ),
          ],
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
      (Icons.workspace_premium_outlined, 'Seja sócio', 'Entre no Clube e libere os prêmios.'),
      (Icons.card_giftcard_rounded, 'O restaurante libera prêmios', 'Pratos e brindes com prazo pra resgatar.'),
      (Icons.qr_code_2_rounded, 'Mostre o QR no caixa', 'O atendente confirma e você recebe na hora.'),
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
            borderRadius: PandaRadius.bsm,
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

/// Chip de status de sócio ativo.
class _StatusSocio extends StatelessWidget {
  const _StatusSocio();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: PandaColors.verdeSucesso.withValues(alpha: 0.12),
        borderRadius: PandaRadius.bsm,
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

/// O número que vende o Clube: quanto o sócio já economizou em prêmios.
/// Card escuro pra contrastar com o papel quente — é o destaque da tela.
class _EconomiaCard extends ConsumerWidget {
  const _EconomiaCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final economia = ref.watch(economiaProvider);
    if (economia.total <= 0) return const SizedBox.shrink();

    // No claro o card escuro salta do papel quente. No escuro ele sumiria
    // no fundo, então sobe pra superfície de card e ganha borda laranja.
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
      decoration: BoxDecoration(
        color: isDark ? PandaColors.cardDark : PandaColors.preto,
        borderRadius: PandaRadius.blg,
        border: isDark
            ? Border.all(color: PandaColors.laranja.withValues(alpha: 0.35))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 2,
                color: PandaColors.laranja,
              ),
              const SizedBox(width: 10),
              Text('VOCÊ JÁ ECONOMIZOU',
                  style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.55))),
            ],
          ),
          const SizedBox(height: 14),
          // Contador sobe do zero — dá vida ao número sem parecer enfeite.
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: economia.total),
            duration: const Duration(milliseconds: 1100),
            curve: Curves.easeOutCubic,
            builder: (_, valor, _) => Text(
              _moeda.format(valor),
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: PandaColors.laranja,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.card_giftcard_rounded,
                  size: 15, color: Colors.white.withValues(alpha: 0.6)),
              const SizedBox(width: 6),
              Text(
                '${economia.resgates} ${economia.resgates == 1 ? 'prêmio resgatado' : 'prêmios resgatados'}',
                style: TextStyle(
                    fontSize: 13, color: Colors.white.withValues(alpha: 0.75)),
              ),
            ],
          ),
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
    // A sombra fica FORA do Material. Antes ela vinha junto do `Ink`, com
    // offset de 10px pra baixo e sem spread negativo: escapava por trás dos
    // cantos de baixo e desenhava um degrau reto na base do card.
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: PandaRadius.blg,
        boxShadow: [
          BoxShadow(
            color: PandaColors.laranja.withValues(alpha: 0.30),
            blurRadius: 22,
            // spread negativo encolhe a sombra: ela nunca ultrapassa a
            // silhueta arredondada do card.
            spreadRadius: -6,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: PandaRadius.blg,
        // Clipa o gradiente e o splash exatamente na curva.
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.go('/carteirinha'),
          child: Ink(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [PandaColors.laranja, PandaColors.laranjaEscuro],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: PandaRadius.blg,
            ),
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: PandaRadius.bsm,
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
                              height: 1.25,
                              fontWeight: FontWeight.w800)),
                      SizedBox(height: 4),
                      Text('Mostre no caixa pra se identificar',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              height: 1.3)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.white),
              ],
            ),
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
        borderRadius: PandaRadius.bmd,
        child: InkWell(
          onTap: onTap,
          borderRadius: PandaRadius.bmd,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: PandaRadius.bmd,
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
            borderRadius: PandaRadius.bmd,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        // Superfície do tema, não creme fixo: no escuro virava mancha clara.
        color: isDark ? PandaColors.cardDark : PandaColors.laranjaSuave,
        borderRadius: PandaRadius.blg,
        border: Border.all(
            color: isDark
                ? PandaColors.laranja.withValues(alpha: 0.35)
                : Colors.transparent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Entre pro Clube',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color:
                      isDark ? PandaColors.laranja : PandaColors.laranjaEscuro,
                  height: 1.25)),
          const SizedBox(height: 8),
          Text('Rodízios, prêmios e promoções exclusivas todo mês.',
              style: TextStyle(
                  color: isDark ? PandaColors.branco : PandaColors.preto,
                  height: 1.4)),
          const SizedBox(height: 20),
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
/// Rótulo curto do prazo da oferta. Nulo quando não tem fim marcado.
String? _rotuloPrazo(DateTime? fim) {
  if (fim == null) return null;
  final agora = DateTime.now();
  final hoje = DateTime(agora.year, agora.month, agora.day);
  final diaFim = DateTime(fim.year, fim.month, fim.day);
  final dias = diaFim.difference(hoje).inDays;
  final hora = fim.minute == 0
      ? '${fim.hour}h'
      : '${fim.hour}h${fim.minute.toString().padLeft(2, '0')}';
  if (dias == 0) return 'Termina hoje às $hora';
  if (dias == 1) return 'Termina amanhã às $hora';
  final d = fim.day.toString().padLeft(2, '0');
  final m = fim.month.toString().padLeft(2, '0');
  return 'Até $d/$m às $hora';
}

/// Selo de prazo. Fica vermelho no último dia pra dar urgência.
class _PrazoPill extends StatelessWidget {
  const _PrazoPill({required this.fim, this.sobreImagem = false});
  final DateTime fim;
  final bool sobreImagem;

  @override
  Widget build(BuildContext context) {
    final rotulo = _rotuloPrazo(fim);
    if (rotulo == null) return const SizedBox.shrink();
    final ultimoDia = fim.difference(DateTime.now()).inHours < 24;
    final cor =
        ultimoDia ? PandaColors.vermelhoAcento : PandaColors.laranjaEscuro;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: sobreImagem
            ? Colors.black.withValues(alpha: 0.45)
            : cor.withValues(alpha: 0.12),
        borderRadius: PandaRadius.bxs,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule_rounded,
              size: 13, color: sobreImagem ? Colors.white : cor),
          const SizedBox(width: 4),
          Flexible(
            child: Text(rotulo,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: sobreImagem ? Colors.white : cor)),
          ),
        ],
      ),
    );
  }
}

class _PromoHero extends StatelessWidget {
  const _PromoHero({required this.promo});
  final Promotion promo;

  @override
  Widget build(BuildContext context) {
    return promo.imagem != null ? _comImagem(context) : _suave(context);
  }

  Widget _badge(Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: PandaRadius.bxs),
        child: Text('EXCLUSIVO CLUBE',
            style: TextStyle(
                color: fg,
                fontSize: 10,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w700)),
      );

  Widget _comImagem(BuildContext context) {
    return ClipRRect(
      borderRadius: PandaRadius.blg,
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
                if (promo.validadeFim != null) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _PrazoPill(
                        fim: promo.validadeFim!, sobreImagem: true),
                  ),
                ],
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
        borderRadius: PandaRadius.blg,
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
                  borderRadius: PandaRadius.bsm,
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
          if (promo.validadeFim != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: _PrazoPill(fim: promo.validadeFim!),
            ),
          ],
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
        borderRadius: PandaRadius.bmd,
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
              borderRadius: PandaRadius.bsm,
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
                if (promo.validadeFim != null) ...[
                  const SizedBox(height: 6),
                  _PrazoPill(fim: promo.validadeFim!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
