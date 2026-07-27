import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/app_prefs.dart';
import '../../core/demo.dart';
import '../../core/services/services.dart';
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
    if (kDemo) return;
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
            if (!ativadas) {
              return const _NotificacoesDesligadas();
            }
            if (list.isEmpty) {
              return const EmptyView(
                mensagem:
                    'Nada por aqui ainda.\nVocê será avisado das novidades.',
                icone: Icons.notifications_none_rounded,
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _NotifTile(n: list[i]),
            );
          },
        ),
      ),
    );
  }
}

class _NotificacoesDesligadas extends StatelessWidget {
  const _NotificacoesDesligadas();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.notifications_off_rounded,
              size: 56, color: PandaColors.cinzaTexto),
          const SizedBox(height: 16),
          Text('Notificações desligadas',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text(
            'Ative em Perfil → Notificações para receber promoções e avisos.',
            textAlign: TextAlign.center,
            style: TextStyle(color: PandaColors.cinzaTexto, height: 1.4),
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
