import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

import '../../core/services/services.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/state_views.dart';
import '../../core/models/models.dart';

final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

class PlansScreen extends ConsumerWidget {
  const PlansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plans = ref.watch(plansProvider);
    final sub = ref.watch(subscriptionProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Planos')),
      body: sub.value?.ativa == true
          ? _AssinaturaAtiva(sub: sub.value!)
          : plans.when(
              loading: () => const LoadingView(),
              error: (e, _) => ErrorView(
                  mensagem: 'Erro ao carregar planos.',
                  onRetry: () => ref.invalidate(plansProvider)),
              data: (list) {
                if (list.isEmpty) {
                  return const EmptyView(
                    mensagem: 'Nenhum plano disponível.',
                    icone: Icons.workspace_premium_outlined,
                  );
                }
                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text('Escolha seu plano 🐼',
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    const Text('Cancele quando quiser.'),
                    const SizedBox(height: 20),
                    ...list.map((p) => _PlanCard(plan: p)),
                  ],
                );
              },
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
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: p.recomendado ? PandaColors.laranja : Colors.transparent,
          width: 2,
        ),
        color: Theme.of(context).cardColor,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(p.nome,
                    style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                if (p.recomendado)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: PandaColors.laranja,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('Recomendado',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(_moeda.format(p.preco),
                    style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: PandaColors.laranja)),
                Text(' / ${p.intervalo}',
                    style: const TextStyle(color: PandaColors.cinzaTexto)),
              ],
            ),
            const SizedBox(height: 16),
            ...p.beneficios.map((b) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle,
                          color: PandaColors.verdeSucesso, size: 20),
                      const SizedBox(width: 8),
                      Expanded(child: Text(b)),
                    ],
                  ),
                )),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loading ? null : _assinar,
              child: _loading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Assinar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssinaturaAtiva extends ConsumerWidget {
  const _AssinaturaAtiva({required this.sub});
  final Subscription sub;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: PandaColors.verdeSucesso.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              const Icon(Icons.verified, color: PandaColors.verdeSucesso),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Assinatura ativa',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    if (sub.proximaCobranca != null)
                      Text(
                        'Próxima cobrança: ${DateFormat('dd/MM/yyyy').format(sub.proximaCobranca!)}',
                        style:
                            const TextStyle(color: PandaColors.cinzaTexto),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
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
