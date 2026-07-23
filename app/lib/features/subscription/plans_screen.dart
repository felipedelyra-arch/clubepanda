import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

import '../../core/services/services.dart';
import '../../core/demo.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/state_views.dart';
import '../../core/widgets/demo_toggle.dart';
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
                loading: () => const LoadingView(),
                error: (e, _) => ErrorView(
                    mensagem: 'Não deu pra carregar os planos.',
                    onRetry: () => ref.invalidate(plansProvider)),
                data: (list) {
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                    children: [
                      const DemoToggle(),
                      Text('Seja sócio',
                          style: Theme.of(context).textTheme.headlineMedium),
                      const SizedBox(height: 6),
                      const Text(
                        'Um valor que cabe no bolso — menos que um cafezinho por mês. Cancele quando quiser.',
                        style: TextStyle(
                            color: PandaColors.cinzaTexto, fontSize: 15, height: 1.4),
                      ),
                      const SizedBox(height: 28),
                      if (list.isEmpty)
                        const EmptyView(
                          mensagem: 'Nenhum plano disponível.',
                          icone: Icons.workspace_premium_outlined,
                        )
                      else
                        for (final p in list) ...[
                          _PlanCard(plan: p),
                          const SizedBox(height: 16),
                        ],
                    ],
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
    if (kDemo) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Checkout desativado no modo demo')),
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
        borderRadius: BorderRadius.circular(22),
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
                borderRadius: BorderRadius.circular(8),
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
          Text(p.nome, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(_moeda.format(p.preco),
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: PandaColors.laranja,
                      )),
              Text('  / ${p.intervalo}',
                  style: const TextStyle(color: PandaColors.cinzaTexto)),
            ],
          ),
          const SizedBox(height: 4),
          Text('Menos de R\$ 0,17 por dia',
              style: TextStyle(
                  color: PandaColors.cinzaTexto.withValues(alpha: 0.9),
                  fontSize: 13)),
          const SizedBox(height: 18),
          for (final b in p.beneficios)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(Icons.check_circle,
                        color: PandaColors.verdeSucesso, size: 19),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(b, style: const TextStyle(height: 1.35))),
                ],
              ),
            ),
          const SizedBox(height: 10),
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

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      children: [
        const DemoToggle(),
        Text('Sua assinatura',
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 20),
        // Card principal do plano
        Container(
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
                  Expanded(
                    child: Text(
                      plano != null ? 'Plano ${plano.nome}' : 'Plano ativo',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(color: PandaColors.laranjaEscuro),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: PandaColors.verdeSucesso,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('ATIVO',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            letterSpacing: 0.8,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              if (plano != null) ...[
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(_moeda.format(plano.preco),
                        style: Theme.of(context)
                            .textTheme
                            .displaySmall
                            ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: PandaColors.laranjaEscuro)),
                    Text('  / ${plano.intervalo}',
                        style: const TextStyle(color: PandaColors.cinzaTexto)),
                  ],
                ),
              ],
              const SizedBox(height: 18),
              Container(height: 1, color: PandaColors.laranja.withValues(alpha: 0.2)),
              const SizedBox(height: 16),
              if (sub.proximaCobranca != null)
                _linhaInfo(
                  Icons.event_outlined,
                  'Próxima cobrança',
                  DateFormat("dd 'de' MMMM", 'pt_BR').format(sub.proximaCobranca!),
                ),
              const SizedBox(height: 12),
              _linhaInfo(Icons.credit_card_outlined, 'Pagamento', metodo),
            ],
          ),
        ),
        if (plano != null && plano.beneficios.isNotEmpty) ...[
          const SizedBox(height: 28),
          const SectionLabel('Seus benefícios'),
          const SizedBox(height: 12),
          for (final b in plano.beneficios)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(Icons.check_circle,
                        color: PandaColors.verdeSucesso, size: 19),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(b, style: const TextStyle(height: 1.35))),
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

  Widget _linhaInfo(IconData icone, String label, String valor) {
    return Row(
      children: [
        Icon(icone, size: 18, color: PandaColors.laranjaEscuro),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(color: PandaColors.cinzaTexto)),
        const Spacer(),
        Text(valor,
            style: const TextStyle(
                fontWeight: FontWeight.w600, color: PandaColors.preto)),
      ],
    );
  }

  Future<void> _confirmarCancelamento(
      BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancelar assinatura?'),
        content: const Text(
            'Você mantém os benefícios até o fim do período já pago.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Voltar')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Cancelar assinatura')),
        ],
      ),
    );
    if (ok != true) return;
    if (kDemo) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cancelamento desativado no modo demo')),
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
