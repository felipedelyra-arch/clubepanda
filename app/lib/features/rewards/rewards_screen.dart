import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/services/services.dart';
import '../../core/demo.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/state_views.dart';
import '../../core/models/models.dart';

class RewardsScreen extends ConsumerWidget {
  const RewardsScreen({super.key});

  IconData _iconeTipo(String tipo) {
    switch (tipo) {
      case 'rodizio':
        return Icons.ramen_dining;
      case 'prato':
        return Icons.restaurant;
      case 'sobremesa':
        return Icons.icecream;
      default:
        return Icons.confirmation_number;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rewards = ref.watch(rewardsProvider);
    final user = ref.watch(currentUserProvider);
    final pontos = user.value?.pontos ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Premiações'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(child: PointsBadge(pontos: pontos)),
          ),
        ],
      ),
      body: rewards.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
            mensagem: 'Erro ao carregar prêmios.',
            onRetry: () => ref.invalidate(rewardsProvider)),
        data: (list) {
          if (list.isEmpty) {
            return const EmptyView(
              mensagem: 'Nenhum prêmio disponível agora.',
              icone: Icons.card_giftcard_outlined,
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.72,
            ),
            itemCount: list.length,
            itemBuilder: (_, i) => _RewardCard(
              reward: list[i],
              icone: _iconeTipo(list[i].tipo),
              podeResgatar: pontos >= list[i].custoPontos && list[i].disponivel,
              onTap: () => _abrirDetalhe(context, ref, list[i]),
            ),
          );
        },
      ),
    );
  }

  void _abrirDetalhe(BuildContext context, WidgetRef ref, Reward reward) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _RewardSheet(reward: reward),
    );
  }
}

class _RewardCard extends StatelessWidget {
  const _RewardCard({
    required this.reward,
    required this.icone,
    required this.podeResgatar,
    required this.onTap,
  });

  final Reward reward;
  final IconData icone;
  final bool podeResgatar;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: PandaColors.laranja.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icone, color: PandaColors.laranja, size: 28),
              ),
              const SizedBox(height: 12),
              Text(reward.titulo,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(reward.descricao,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: PandaColors.cinzaTexto, fontSize: 12)),
              const Spacer(),
              Row(
                children: [
                  if (reward.apenasAssinantes)
                    const Text('Exclusivo',
                        style: TextStyle(
                            color: PandaColors.vermelhoAcento,
                            fontWeight: FontWeight.w600,
                            fontSize: 12))
                  else
                    Text('${reward.custoPontos} pts',
                        style: const TextStyle(
                            color: PandaColors.laranja,
                            fontWeight: FontWeight.w700)),
                  const Spacer(),
                  if (!reward.disponivel)
                    const Text('Esgotado',
                        style: TextStyle(
                            color: PandaColors.cinzaTexto, fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RewardSheet extends ConsumerStatefulWidget {
  const _RewardSheet({required this.reward});
  final Reward reward;

  @override
  ConsumerState<_RewardSheet> createState() => _RewardSheetState();
}

class _RewardSheetState extends ConsumerState<_RewardSheet> {
  bool _loading = false;
  String? _codigo;
  String? _erro;

  Future<void> _resgatar() async {
    setState(() {
      _loading = true;
      _erro = null;
    });
    // Demo: simula resgate com código fake (não chama backend).
    if (kDemo) {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (mounted) {
        setState(() {
          _codigo = 'DEMO${DateTime.now().millisecondsSinceEpoch % 100000000}';
          _loading = false;
        });
      }
      return;
    }
    try {
      final callable =
          ref.read(functionsProvider).httpsCallable('redeemReward');
      final res = await callable.call({'rewardId': widget.reward.id});
      setState(() => _codigo = res.data['codigo'] as String);
    } on FirebaseFunctionsException catch (e) {
      setState(() => _erro = e.message ?? 'Não foi possível resgatar.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.reward;
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_codigo != null) ...[
            const Text('Prêmio resgatado! 🎉',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text('Mostre este QR no caixa do Tio Panda:',
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            Center(
              child: QrImageView(
                data: _codigo!,
                size: 200,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            SelectableText(_codigo!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 18,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fechar'),
            ),
          ] else ...[
            Text(r.titulo,
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(r.descricao,
                style: const TextStyle(color: PandaColors.cinzaTexto)),
            const SizedBox(height: 16),
            Row(
              children: [
                if (r.apenasAssinantes)
                  const Text('Exclusivo assinante',
                      style: TextStyle(
                          color: PandaColors.vermelhoAcento,
                          fontWeight: FontWeight.w600))
                else
                  Text('Custo: ${r.custoPontos} pontos',
                      style: const TextStyle(
                          color: PandaColors.laranja,
                          fontWeight: FontWeight.w700)),
                const Spacer(),
                Text('Estoque: ${r.estoque}',
                    style: const TextStyle(color: PandaColors.cinzaTexto)),
              ],
            ),
            if (_erro != null) ...[
              const SizedBox(height: 12),
              Text(_erro!,
                  style: const TextStyle(color: PandaColors.vermelhoAcento)),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: (_loading || !r.disponivel) ? null : _resgatar,
              child: _loading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(r.disponivel ? 'Resgatar' : 'Esgotado'),
            ),
          ],
        ],
      ),
    );
  }
}
