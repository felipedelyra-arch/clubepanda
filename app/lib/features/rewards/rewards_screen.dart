import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/services/services.dart';
import '../../core/demo.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/state_views.dart';
import '../../core/widgets/app_image.dart';
import '../../core/models/models.dart';

IconData _iconeTipo(String tipo) {
  switch (tipo) {
    case 'rodizio':
      return Icons.ramen_dining;
    case 'prato':
      return Icons.set_meal_outlined;
    case 'sobremesa':
      return Icons.icecream_outlined;
    default:
      return Icons.confirmation_number_outlined;
  }
}

class RewardsScreen extends ConsumerWidget {
  const RewardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rewards = ref.watch(rewardsProvider);
    final user = ref.watch(currentUserProvider);
    final pontos = user.value?.pontos ?? 0;

    return Scaffold(
      body: SafeArea(
        child: rewards.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(
              mensagem: 'Não deu pra carregar os prêmios.',
              onRetry: () => ref.invalidate(rewardsProvider)),
          data: (list) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              children: [
                Text('Prêmios',
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 16),
                _SaldoCard(pontos: pontos),
                const SizedBox(height: 28),
                const _SectionLabel('Troque seus pontos'),
                const SizedBox(height: 14),
                if (list.isEmpty)
                  const EmptyView(
                    mensagem: 'Nenhum prêmio disponível agora.',
                    icone: Icons.card_giftcard_outlined,
                  )
                else
                  for (final r in list) ...[
                    _RewardTile(
                      reward: r,
                      podeResgatar: pontos >= r.custoPontos && r.disponivel,
                      onTap: () => _abrir(context, r),
                    ),
                    const SizedBox(height: 12),
                  ],
              ],
            );
          },
        ),
      ),
    );
  }

  void _abrir(BuildContext context, Reward reward) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (_) => _RewardSheet(reward: reward),
    );
  }
}

class _SaldoCard extends StatelessWidget {
  const _SaldoCard({required this.pontos});
  final int pontos;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: PandaColors.laranjaSuave,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Seu saldo',
                  style: TextStyle(
                      color: PandaColors.laranjaEscuro,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text('$pontos',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: PandaColors.laranjaEscuro,
                          )),
                  const SizedBox(width: 6),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Text('pontos',
                        style: TextStyle(color: PandaColors.laranjaEscuro)),
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          const Icon(Icons.stars_rounded, color: PandaColors.laranja, size: 44),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.texto);
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 20, height: 2, color: PandaColors.laranja),
        const SizedBox(width: 10),
        Text(texto.toUpperCase(),
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
                color: PandaColors.cinzaTexto)),
      ],
    );
  }
}

class _RewardTile extends StatelessWidget {
  const _RewardTile({
    required this.reward,
    required this.podeResgatar,
    required this.onTap,
  });

  final Reward reward;
  final bool podeResgatar;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final esgotado = !reward.disponivel;

    return Opacity(
      opacity: esgotado ? 0.55 : 1,
      child: Material(
        color: isDark ? PandaColors.cardDark : PandaColors.branco,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark ? PandaColors.hairlineDark : PandaColors.hairline,
              ),
            ),
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: PandaColors.laranjaSuave,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: reward.imagem != null
                      ? appImage(reward.imagem!,
                          erro: Icon(_iconeTipo(reward.tipo),
                              color: PandaColors.laranja, size: 26))
                      : Icon(_iconeTipo(reward.tipo),
                          color: PandaColors.laranja, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(reward.titulo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(
                        esgotado ? 'Esgotado' : reward.descricao,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: PandaColors.cinzaTexto, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      _custoPill(reward),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right,
                    color: PandaColors.cinzaTexto),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _custoPill(Reward reward) {
    if (reward.apenasAssinantes) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: PandaColors.laranjaSuave,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text('Exclusivo Clube',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: PandaColors.laranjaEscuro)),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star_rounded, size: 15, color: PandaColors.laranja),
        const SizedBox(width: 4),
        Text('${reward.custoPontos} pts',
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: PandaColors.laranjaEscuro)),
      ],
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
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_codigo != null) ...[
            const SizedBox(height: 8),
            Text('Prêmio resgatado!',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            const Text('Mostre este código no caixa do Tio Panda.',
                textAlign: TextAlign.center,
                style: TextStyle(color: PandaColors.cinzaTexto)),
            const SizedBox(height: 24),
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: PandaColors.hairline),
                ),
                child: QrImageView(
                    data: _codigo!, size: 190, backgroundColor: Colors.white),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: SelectableText(_codigo!,
                  style: const TextStyle(
                      fontSize: 18,
                      letterSpacing: 3,
                      fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fechar'),
            ),
          ] else ...[
            if (r.imagem != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: SizedBox(
                  height: 170,
                  width: double.infinity,
                  child: appImage(r.imagem!,
                      erro: Container(color: PandaColors.laranjaSuave)),
                ),
              ),
              const SizedBox(height: 18),
            ] else
              const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: PandaColors.laranjaSuave,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: r.imagem != null
                      ? appImage(r.imagem!,
                          erro: Icon(_iconeTipo(r.tipo),
                              color: PandaColors.laranja, size: 26))
                      : Icon(_iconeTipo(r.tipo),
                          color: PandaColors.laranja, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(r.titulo,
                      style: Theme.of(context).textTheme.titleLarge),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(r.descricao,
                style: const TextStyle(
                    color: PandaColors.cinzaTexto, height: 1.5)),
            const SizedBox(height: 20),
            Row(
              children: [
                _info(
                  context,
                  r.apenasAssinantes ? 'Acesso' : 'Custo',
                  r.apenasAssinantes ? 'Exclusivo Clube' : '${r.custoPontos} pts',
                ),
                const SizedBox(width: 12),
                _info(context, 'Estoque', '${r.estoque}'),
              ],
            ),
            if (_erro != null) ...[
              const SizedBox(height: 16),
              Text(_erro!,
                  style: const TextStyle(color: PandaColors.vermelhoAcento)),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: (_loading || !r.disponivel) ? null : _resgatar,
              child: _loading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(r.disponivel ? 'Resgatar prêmio' : 'Esgotado'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _info(BuildContext context, String label, String valor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: isDark ? PandaColors.cardDark : PandaColors.cinzaClaro,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(),
                style: const TextStyle(
                    fontSize: 10.5,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w700,
                    color: PandaColors.cinzaTexto)),
            const SizedBox(height: 4),
            Text(valor,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
