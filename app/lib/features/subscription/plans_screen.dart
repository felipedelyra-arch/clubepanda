import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

import '../../core/services/services.dart';
import '../../core/demo.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/dimens.dart';
import '../../core/widgets/state_views.dart';
import '../../core/widgets/entrada.dart';
import '../../core/widgets/skeleton.dart';
import '../../core/models/models.dart';

final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

class PlansScreen extends ConsumerWidget {
  const PlansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plans = ref.watch(plansProvider);
    final sub = ref.watch(subscriptionProvider);

    return Scaffold(
      body: SafeArea(
        child: sub.value?.ativa == true
            ? _AssinaturaAtiva(sub: sub.value!)
            : plans.when(
                loading: () => const SkeletonList(itens: 2),
                error: (e, _) => ErrorView(
                    mensagem: 'Não deu pra carregar os planos.',
                    onRetry: () => ref.invalidate(plansProvider)),
                data: (list) {
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                    children: escalonar([
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Seja sócio',
                              style:
                                  Theme.of(context).textTheme.headlineMedium),
                          const SizedBox(height: 6),
                          const Text(
                            'Um valor que cabe no bolso — menos que um cafezinho por mês. Cancele quando quiser.',
                            style: TextStyle(
                                color: PandaColors.cinzaTexto,
                                fontSize: 15,
                                height: 1.4),
                          ),
                        ],
                      ),
                      if (list.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 28),
                          child: EmptyView(
                            mensagem: 'Nenhum plano disponível.',
                            icone: Icons.workspace_premium_outlined,
                          ),
                        )
                      else
                        for (final p in list)
                          Padding(
                            padding: const EdgeInsets.only(top: 28),
                            child: _PlanCard(plan: p),
                          ),
                    ]),
                  );
                },
              ),
      ),
    );
  }
}

class _PlanCard extends ConsumerStatefulWidget {
  const _PlanCard({required this.plan});
  final Plan plan;

  @override
  ConsumerState<_PlanCard> createState() => _PlanCardState();
}

class _PlanCardState extends ConsumerState<_PlanCard> {
  bool _loading = false;

  Future<void> _assinar() async {
    // No demo o checkout roda inteiro: simula o processamento, ativa a
    // assinatura e abre a tela de boas-vindas. É o momento-chave da
    // apresentação — não pode terminar num aviso de "desativado".
    if (kDemo) {
      setState(() => _loading = true);
      await Future<void>.delayed(const Duration(milliseconds: 1400));
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      ref.read(demoIsSubscriber.notifier).state = true;
      setState(() => _loading = false);
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _BoasVindasSocio(plano: widget.plan),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final callable =
          ref.read(functionsProvider).httpsCallable('createCheckoutSession');
      final res = await callable.call({'planId': widget.plan.id});
      final url = res.data['url'] as String?;
      if (url != null && await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Erro ao iniciar checkout.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.plan;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final destaque = p.recomendado;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? PandaColors.cardDark : PandaColors.branco,
        borderRadius: PandaRadius.blg,
        border: Border.all(
          color: destaque
              ? PandaColors.laranja
              : (isDark ? PandaColors.hairlineDark : PandaColors.hairline),
          width: destaque ? 1.6 : 1,
        ),
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (destaque) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: PandaColors.laranja,
                borderRadius: PandaRadius.bxs,
              ),
              child: const Text('PLANO ÚNICO',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 10.5,
                      letterSpacing: 1,
                      fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 14),
          ],
          Text(p.nome,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(height: 1.25)),
          const SizedBox(height: 12),
          // Preço e período em baseline, com folga explícita — antes o
          // espaçamento vinha de espaços dentro da string e colava.
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 8,
            children: [
              Text(_moeda.format(p.preco),
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: PandaColors.laranja,
                        height: 1.05,
                      )),
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text('/ ${p.intervalo}',
                    style: const TextStyle(
                        color: PandaColors.cinzaTexto,
                        fontSize: 14,
                        height: 1.2)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Menos de R\$ 0,17 por dia',
              style: TextStyle(
                  color: PandaColors.cinzaTexto.withValues(alpha: 0.9),
                  fontSize: 13,
                  height: 1.3)),
          const SizedBox(height: 22),
          for (final b in p.beneficios)
            Padding(
              padding: const EdgeInsets.only(bottom: 13),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(Icons.check_circle,
                        color: PandaColors.verdeSucesso, size: 19),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                      child: Text(b,
                          style: const TextStyle(height: 1.4, fontSize: 14.5))),
                ],
              ),
            ),
          const SizedBox(height: 12),
          destaque
              ? ElevatedButton(
                  onPressed: _loading ? null : _assinar,
                  child: _loading
                      ? const _BtnSpinner()
                      : const Text('Assinar agora'),
                )
              : OutlinedButton(
                  onPressed: _loading ? null : _assinar,
                  child: _loading ? const _BtnSpinner() : const Text('Assinar'),
                ),
        ],
      ),
    );
  }
}

/// Boas-vindas depois de assinar. Selo cresce, texto entra em seguida —
/// fecha o fluxo com uma sensação de conquista em vez de um snackbar.
class _BoasVindasSocio extends StatefulWidget {
  const _BoasVindasSocio({required this.plano});
  final Plan plano;

  @override
  State<_BoasVindasSocio> createState() => _BoasVindasSocioState();
}

class _BoasVindasSocioState extends State<_BoasVindasSocio>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..forward();

  late final Animation<double> _selo = CurvedAnimation(
    parent: _c,
    curve: const Interval(0, 0.6, curve: Curves.elasticOut),
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: RoundedRectangleBorder(borderRadius: PandaRadius.blg),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 34, 28, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: _selo,
              child: Container(
                width: 88,
                height: 88,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [PandaColors.laranja, PandaColors.laranjaEscuro],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded,
                    color: Colors.white, size: 48),
              ),
            ),
            const SizedBox(height: 22),
            FadeSlideIn(
              delay: const Duration(milliseconds: 260),
              child: Column(
                children: [
                  Text('Bem-vindo ao Clube!',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  const Text(
                    'Sua assinatura está ativa. Os prêmios já estão liberados.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: PandaColors.cinzaTexto, height: 1.4, fontSize: 14.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            FadeSlideIn(
              delay: const Duration(milliseconds: 400),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark ? PandaColors.cardDark : PandaColors.cinzaClaro,
                  borderRadius: PandaRadius.bmd,
                  border: Border.all(
                      color: isDark
                          ? PandaColors.hairlineDark
                          : PandaColors.hairline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final b in widget.plano.beneficios.take(3))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Icon(Icons.check_circle,
                                  color: PandaColors.verdeSucesso, size: 17),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(b,
                                  style: const TextStyle(
                                      fontSize: 13.5, height: 1.35)),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                context.go('/premiacoes');
              },
              child: const Text('Ver meus prêmios'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Depois'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BtnSpinner extends StatelessWidget {
  const _BtnSpinner();
  @override
  Widget build(BuildContext context) => const SizedBox(
        height: 22,
        width: 22,
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
      );
}

class _AssinaturaAtiva extends ConsumerWidget {
  const _AssinaturaAtiva({required this.sub});
  final Subscription sub;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plans = ref.watch(plansProvider).value ?? const [];
    Plan? plano;
    for (final p in plans) {
      if (p.id == sub.planId) plano = p;
    }
    final metodo = sub.formaPagamento == 'pix' ? 'Pix' : 'Cartão de crédito';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hairline =
        isDark ? PandaColors.hairlineDark : PandaColors.hairline;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      children: [
        Text('Sua assinatura',
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 20),
        // Card principal do plano — mesma superfície dos outros cards do app
        // (creme claro / carvão no escuro), com a borda laranja marcando que
        // está ativo. Antes era um bloco creme fixo que virava mancha branca
        // no tema escuro.
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: isDark ? PandaColors.cardDark : PandaColors.branco,
            borderRadius: PandaRadius.blg,
            border: Border.all(color: PandaColors.laranja, width: 1.6),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      plano != null ? 'Plano ${plano.nome}' : 'Plano ativo',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(height: 1.25),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: PandaColors.verdeSucesso,
                      borderRadius: PandaRadius.bxs,
                    ),
                    child: const Text('ATIVO',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            letterSpacing: 0.8,
                            height: 1.25,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              if (plano != null) ...[
                const SizedBox(height: 12),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.end,
                  spacing: 8,
                  children: [
                    Text(_moeda.format(plano.preco),
                        style: Theme.of(context)
                            .textTheme
                            .displaySmall
                            ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: PandaColors.laranja,
                                height: 1.05)),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Text('/ ${plano.intervalo}',
                          style: const TextStyle(
                              color: PandaColors.cinzaTexto,
                              fontSize: 14,
                              height: 1.2)),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              Container(height: 1, color: hairline),
              const SizedBox(height: 18),
              if (sub.proximaCobranca != null) ...[
                _linhaInfo(
                  context,
                  Icons.event_outlined,
                  'Próxima cobrança',
                  DateFormat("dd 'de' MMMM", 'pt_BR').format(sub.proximaCobranca!),
                ),
                const SizedBox(height: 14),
              ],
              _linhaInfo(
                  context, Icons.credit_card_outlined, 'Pagamento', metodo),
            ],
          ),
        ),
        if (plano != null && plano.beneficios.isNotEmpty) ...[
          const SizedBox(height: 28),
          const SectionLabel('Seus benefícios'),
          const SizedBox(height: 14),
          for (final b in plano.beneficios)
            Padding(
              padding: const EdgeInsets.only(bottom: 13),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(Icons.check_circle,
                        color: PandaColors.verdeSucesso, size: 19),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                      child: Text(b,
                          style: const TextStyle(height: 1.4, fontSize: 14.5))),
                ],
              ),
            ),
        ],
        const SizedBox(height: 24),
        const SectionLabel('Gerenciar'),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () => _confirmarCancelamento(context, ref),
          style: OutlinedButton.styleFrom(
            foregroundColor: PandaColors.vermelhoAcento,
            side: const BorderSide(color: PandaColors.vermelhoAcento),
          ),
          child: const Text('Cancelar assinatura'),
        ),
      ],
    );
  }

  /// Label em cima, valor embaixo. Lado a lado, "Próxima cobrança / 18 de
  /// agosto" quebrava em duas linhas torta quando a letra está em Grande.
  Widget _linhaInfo(
      BuildContext context, IconData icone, String label, String valor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icone, size: 18, color: PandaColors.laranja),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label.toUpperCase(),
                  style: const TextStyle(
                      color: PandaColors.cinzaTexto,
                      fontSize: 10.5,
                      letterSpacing: 1,
                      height: 1.3,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(valor,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14.5,
                      height: 1.3,
                      // Cor do tema — antes era preto fixo e sumia no escuro.
                      color: isDark ? PandaColors.branco : PandaColors.preto)),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _confirmarCancelamento(
      BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      // Usa o context do próprio diálogo: com o context de fora, o pop
      // atinge o Navigator do GoRouter e derruba a página inteira.
      builder: (ctxDialogo) => AlertDialog(
        title: const Text('Cancelar assinatura?'),
        content: const Text(
            'Você mantém os benefícios até o fim do período já pago.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctxDialogo, false),
              child: const Text('Voltar')),
          TextButton(
              onPressed: () => Navigator.pop(ctxDialogo, true),
              child: const Text('Cancelar assinatura')),
        ],
      ),
    );
    if (ok != true) return;
    // No demo o cancelamento também vale: volta pra visitante e libera
    // demonstrar o fluxo de assinatura do começo, ao vivo.
    if (kDemo) {
      ref.read(demoIsSubscriber.notifier).state = false;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Assinatura cancelada. Benefícios ativos até o fim do período pago.')),
        );
      }
      return;
    }
    try {
      await ref
          .read(functionsProvider)
          .httpsCallable('cancelSubscription')
          .call();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Assinatura cancelada.')),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Erro ao cancelar.')),
        );
      }
    }
  }
}
