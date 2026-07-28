import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/services/services.dart';
import '../../core/analytics.dart';
import '../../core/demo.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/dimens.dart';
import '../../core/widgets/state_views.dart';
import '../../core/widgets/entrada.dart';
import '../../core/widgets/skeleton.dart';
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

/// Formata o prazo de resgate pra exibição curta.
String _fmtPrazo(DateTime d) {
  final agora = DateTime.now();
  final hoje = DateTime(agora.year, agora.month, agora.day);
  final dia = DateTime(d.year, d.month, d.day);
  final hora = DateFormat('HH:mm').format(d);
  if (dia == hoje) return 'hoje às $hora';
  if (dia == hoje.add(const Duration(days: 1))) return 'amanhã às $hora';
  return '${DateFormat('dd/MM').format(d)} às $hora';
}

class RewardsScreen extends ConsumerWidget {
  const RewardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rewards = ref.watch(rewardsProvider);
    final isSub = ref.watch(isSubscriberProvider);
    final redemptions = ref.watch(redemptionsProvider).value ?? const [];
    // Prêmios que este usuário já resgatou (limite 1 por pessoa).
    final resgatados = redemptions.map((r) => r.rewardId).toSet();

    return Scaffold(
      body: SafeArea(
        child: rewards.when(
          loading: () => const SkeletonList(),
          error: (e, _) => ErrorView(
              mensagem: 'Não deu pra carregar os prêmios.',
              onRetry: () => ref.invalidate(rewardsProvider)),
          data: (list) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              children: escalonar([
                Text('Prêmios',
                    style: Theme.of(context).textTheme.headlineMedium),
                if (!isSub)
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: _SocioBanner(),
                  ),
                const Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: _SectionLabel('Liberados pelo restaurante'),
                ),
                if (list.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 14),
                    child: EmptyView(
                      mensagem: 'Nenhum prêmio disponível agora.',
                      icone: Icons.card_giftcard_outlined,
                    ),
                  )
                else
                  for (final r in list)
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: _RewardTile(
                        reward: r,
                        jaResgatou: resgatados.contains(r.id),
                        onTap: () => _abrir(
                          context,
                          r,
                          isSub: isSub,
                          jaResgatou: resgatados.contains(r.id),
                        ),
                      ),
                    ),
              ]),
            );
          },
        ),
      ),
    );
  }

  void _abrir(BuildContext context, Reward reward,
      {required bool isSub, required bool jaResgatou}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (_) =>
          _RewardSheet(reward: reward, isSub: isSub, jaResgatou: jaResgatou),
    );
  }
}

/// Aviso pra quem não é sócio — prêmios são exclusivos do Clube.
class _SocioBanner extends StatelessWidget {
  const _SocioBanner();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final acento = isDark ? PandaColors.laranja : PandaColors.laranjaEscuro;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? PandaColors.cardDark : PandaColors.laranjaSuave,
        borderRadius: PandaRadius.bmd,
        border: Border.all(
            color: isDark
                ? PandaColors.laranja.withValues(alpha: 0.35)
                : Colors.transparent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lock_outline, color: acento),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Exclusivo pra sócios',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: acento,
                        height: 1.25,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
              'Entre pro Clube pra resgatar os prêmios que o Tio Panda libera.',
              style: TextStyle(
                  color: isDark ? PandaColors.branco : PandaColors.preto,
                  height: 1.4)),
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: () => context.go('/planos'),
            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
            child: const Text('Ver planos'),
          ),
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
    required this.jaResgatou,
    required this.onTap,
  });

  final Reward reward;
  final bool jaResgatou;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Apagado quando não dá mais pra resgatar.
    final inativo = jaResgatou || !reward.disponivel;

    return Opacity(
      opacity: inativo ? 0.6 : 1,
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
                    borderRadius: PandaRadius.bsm,
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
                        reward.descricao,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: PandaColors.cinzaTexto, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      _statusPill(reward, jaResgatou),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: PandaColors.cinzaTexto),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pill(String texto, Color fg, IconData icone) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: fg.withValues(alpha: 0.12),
        borderRadius: PandaRadius.bxs,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 13, color: fg),
          const SizedBox(width: 4),
          Text(texto,
              style: TextStyle(
                  fontSize: 11.5, fontWeight: FontWeight.w700, color: fg)),
        ],
      ),
    );
  }

  Widget _statusPill(Reward reward, bool jaResgatou) {
    if (jaResgatou) {
      return _pill('Já resgatado', PandaColors.verdeSucesso, Icons.check_rounded);
    }
    if (!reward.noPrazo) {
      return _pill('Prazo encerrado', PandaColors.cinzaTexto,
          Icons.timer_off_outlined);
    }
    if (reward.estoque <= 0) {
      return _pill('Esgotado', PandaColors.cinzaTexto, Icons.inventory_2_outlined);
    }
    if (reward.resgatavelAte != null) {
      return _pill('Até ${_fmtPrazo(reward.resgatavelAte!)}',
          PandaColors.laranjaEscuro, Icons.schedule_rounded);
    }
    return _pill('Disponível', PandaColors.laranjaEscuro, Icons.card_giftcard);
  }
}

class _RewardSheet extends ConsumerStatefulWidget {
  const _RewardSheet(
      {required this.reward, required this.isSub, required this.jaResgatou});
  final Reward reward;
  final bool isSub;
  final bool jaResgatou;

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
      final agora = DateTime.now();
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      final codigo = 'DEMO${agora.millisecondsSinceEpoch % 100000000}';
      // O resgate entra na lista de verdade: vira cupom no perfil, soma no
      // "você já economizou" e trava o prêmio como "já resgatado". Antes só
      // aparecia o QR e o resto do app seguia como se nada tivesse ocorrido.
      ref.read(demoRedemptionsProvider.notifier).adicionar(
            Redemption(
              id: 'rd_${widget.reward.id}_${agora.millisecondsSinceEpoch}',
              userId: 'u_demo',
              rewardId: widget.reward.id,
              rewardTitulo: widget.reward.titulo,
              codigo: codigo,
              status: 'disponivel',
              criadoEm: agora,
              valor: widget.reward.valor,
            ),
          );
      setState(() {
        _codigo = codigo;
        _loading = false;
      });
      return;
    }
    try {
      final callable =
          ref.read(functionsProvider).httpsCallable('redeemReward');
      final res = await callable.call({'rewardId': widget.reward.id});
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      logEventoUi(ref, 'reward_redeemed',
          params: {'reward_id': widget.reward.id});
      setState(() => _codigo = res.data['codigo'] as String);
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        setState(() => _erro = e.message ?? 'Não foi possível resgatar.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _erro = 'Não foi possível resgatar. Tente de novo.');
      }
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
            const Text('Mostre este QR ao atendente pra receber.',
                textAlign: TextAlign.center,
                style: TextStyle(color: PandaColors.cinzaTexto)),
            const SizedBox(height: 24),
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: PandaRadius.blg,
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
                borderRadius: PandaRadius.bmd,
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
                    borderRadius: PandaRadius.bsm,
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
                  'Resgatar até',
                  r.resgatavelAte != null
                      ? _fmtPrazo(r.resgatavelAte!)
                      : 'Sem prazo',
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
            _acao(context, r),
          ],
        ],
      ),
    );
  }

  /// Botão de ação conforme o estado (sócio, prazo, estoque, já resgatado).
  Widget _acao(BuildContext context, Reward r) {
    if (!widget.isSub) {
      return ElevatedButton(
        onPressed: () {
          Navigator.pop(context);
          context.go('/planos');
        },
        child: const Text('Seja sócio pra resgatar'),
      );
    }
    if (widget.jaResgatou) {
      return const _BotaoBloqueado(texto: 'Você já resgatou este prêmio');
    }
    if (!r.noPrazo) {
      return const _BotaoBloqueado(texto: 'Prazo encerrado');
    }
    if (r.estoque <= 0) {
      return const _BotaoBloqueado(texto: 'Esgotado');
    }
    return ElevatedButton(
      onPressed: _loading ? null : _resgatar,
      child: _loading
          ? const SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white))
          : const Text('Resgatar prêmio'),
    );
  }

  Widget _info(BuildContext context, String label, String valor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: isDark ? PandaColors.cardDark : PandaColors.cinzaClaro,
          borderRadius: PandaRadius.bsm,
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

/// Botão desabilitado com texto explicativo (prazo/estoque/já resgatado).
class _BotaoBloqueado extends StatelessWidget {
  const _BotaoBloqueado({required this.texto});
  final String texto;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: null,
      child: Text(texto),
    );
  }
}
