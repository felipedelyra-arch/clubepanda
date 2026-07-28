import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/app_prefs.dart';
import '../../core/demo.dart';
import '../../core/services/services.dart';
import '../../core/services/push_service.dart';
import '../../core/theme/colors.dart';
import '../../core/models/models.dart';
import '../../core/widgets/state_views.dart';

/// Central de notificações — lista de avisos e promoções recebidos.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // Abriu a central: zera o badge marcando as não lidas como lidas.
    WidgetsBinding.instance.addPostFrameCallback((_) => _marcarLidas());
  }

  Future<void> _marcarLidas() async {
    if (kDemo) {
      ref.read(demoNotificationsProvider.notifier).marcarTodasLidas();
      return;
    }
    final auth = ref.read(authStateProvider).value;
    if (auth == null) return;
    final col = ref
        .read(firestoreProvider)
        .collection('users')
        .doc(auth.uid)
        .collection('notifications');
    try {
      final naoLidas = await col.where('lida', isEqualTo: false).get();
      if (naoLidas.docs.isEmpty) return;
      final batch = ref.read(firestoreProvider).batch();
      for (final d in naoLidas.docs) {
        batch.update(d.reference, {'lida': true});
      }
      await batch.commit();
    } catch (_) {
      // Silencioso: marcar como lida é secundário; não atrapalha a leitura.
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifs = ref.watch(notificationsProvider);
    final ativadas = ref.watch(notificationsEnabledProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/home'),
        ),
        title: const Text('Notificações'),
      ),
      body: SafeArea(
        child: notifs.when(
          loading: () => const LoadingView(),
          error: (_, _) =>
              const ErrorView(mensagem: 'Não deu pra carregar as notificações.'),
          data: (list) {
            // Desligar o push não apaga o histórico: o que já chegou continua
            // aqui, com um aviso em cima e o atalho pra religar.
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                if (!ativadas)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: _AvisoDesligadas(),
                  ),
                if (list.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: EmptyView(
                      mensagem:
                          'Nada por aqui ainda.\nVocê será avisado das novidades.',
                      icone: Icons.notifications_none_rounded,
                    ),
                  )
                else
                  for (final n in list)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _NotifTile(n: n),
                    ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Faixa de aviso quando o push está desligado — com o botão que religa na
/// hora, em vez de mandar o usuário procurar o ajuste em outra tela.
class _AvisoDesligadas extends ConsumerWidget {
  const _AvisoDesligadas();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? PandaColors.cardDark : PandaColors.laranjaSuave,
        borderRadius: BorderRadius.circular(16),
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
              const Icon(Icons.notifications_off_rounded,
                  color: PandaColors.laranja, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Você desligou as notificações. Não vai receber avisos de promoções e prêmios novos.',
                  style: TextStyle(
                      height: 1.35,
                      fontSize: 13.5,
                      color: isDark ? PandaColors.branco : PandaColors.preto),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                await ref
                    .read(notificationsEnabledProvider.notifier)
                    .definir(true);
                if (!kDemo) {
                  await ref.read(pushServiceProvider).aplicarPreferencia(true);
                }
              },
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44)),
              child: const Text('Ativar notificações'),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotifTile extends StatelessWidget {
  const _NotifTile({required this.n});
  final AppNotification n;

  static const _icones = {
    'promo': Icons.local_offer_rounded,
    'aniversario': Icons.cake_rounded,
    'info': Icons.info_outline_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final icone = _icones[n.tipo] ?? Icons.notifications_rounded;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? PandaColors.cardDark : PandaColors.branco,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark ? PandaColors.hairlineDark : PandaColors.hairline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: PandaColors.laranjaSuave,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icone, color: PandaColors.laranja, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(n.titulo,
                          style: TextStyle(
                              fontWeight:
                                  n.lida ? FontWeight.w600 : FontWeight.w700,
                              fontSize: 15)),
                    ),
                    if (!n.lida)
                      Container(
                        width: 9,
                        height: 9,
                        margin: const EdgeInsets.only(left: 8, top: 4),
                        decoration: const BoxDecoration(
                          color: PandaColors.laranja,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(n.corpo,
                    style: const TextStyle(
                        color: PandaColors.cinzaTexto,
                        fontSize: 13.5,
                        height: 1.35)),
                const SizedBox(height: 8),
                Text(_quando(n.criadoEm),
                    style: const TextStyle(
                        color: PandaColors.cinzaTexto,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _quando(DateTime? d) {
    if (d == null) return '';
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'agora';
    if (diff.inMinutes < 60) return 'há ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'há ${diff.inHours} h';
    if (diff.inDays < 7) return 'há ${diff.inDays} d';
    return DateFormat("d 'de' MMM", 'pt_BR').format(d);
  }
}
