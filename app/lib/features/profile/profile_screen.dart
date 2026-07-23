import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/services.dart';
import '../../core/demo.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/state_views.dart';
import '../../core/models/models.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final redemptions = ref.watch(redemptionsProvider);

    return Scaffold(
      body: SafeArea(
        child: user.when(
          loading: () => const LoadingView(),
          error: (e, _) => const ErrorView(mensagem: 'Erro ao carregar perfil.'),
          data: (u) {
            if (u == null) return const EmptyView(mensagem: 'Sem dados.');
            return ListView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              children: [
                Text('Perfil',
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 20),
                _Header(user: u),
                const SizedBox(height: 32),
                const SectionLabel('Meus cupons'),
                const SizedBox(height: 12),
                redemptions.when(
                  loading: () => const Padding(
                      padding: EdgeInsets.only(top: 16), child: LoadingView()),
                  error: (_, _) => const Text('Erro ao carregar cupons.'),
                  data: (list) {
                    if (list.isEmpty) {
                      return _VazioLinha(
                          texto: 'Você ainda não resgatou nenhum prêmio.');
                    }
                    return Column(
                      children: [
                        for (final r in list) ...[
                          _CupomTile(r: r),
                          const SizedBox(height: 10),
                        ],
                      ],
                    );
                  },
                ),
                const SizedBox(height: 28),
                const SectionLabel('Conta'),
                const SizedBox(height: 12),
                _MenuTile(
                  icone: Icons.person_outline,
                  titulo: 'Editar dados',
                  onTap: () {},
                ),
                _MenuTile(
                  icone: Icons.location_on_outlined,
                  titulo: 'Endereço de entrega',
                  subtitulo: u.endereco ?? 'Não informado',
                  onTap: () {},
                ),
                _MenuTile(
                  icone: Icons.description_outlined,
                  titulo: 'Termos e privacidade',
                  onTap: () {},
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () {
                    if (kDemo) {
                      context.go('/login');
                      return;
                    }
                    ref.read(firebaseAuthProvider).signOut();
                  },
                  icon: const Icon(Icons.logout, size: 18),
                  label: const Text('Sair'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: PandaColors.vermelhoAcento,
                    side: const BorderSide(color: PandaColors.vermelhoAcento),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? PandaColors.cardDark : PandaColors.branco,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isDark ? PandaColors.hairlineDark : PandaColors.hairline),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: PandaColors.laranjaSuave,
            backgroundImage:
                user.fotoUrl != null ? NetworkImage(user.fotoUrl!) : null,
            child: user.fotoUrl == null
                ? const Text('🐼', style: TextStyle(fontSize: 26))
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.nome,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 2),
                Text(user.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: PandaColors.cinzaTexto)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          PointsBadge(pontos: user.pontos),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icone,
    required this.titulo,
    this.subtitulo,
    required this.onTap,
  });

  final IconData icone;
  final String titulo;
  final String? subtitulo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(icone, size: 20, color: PandaColors.cinzaTexto),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titulo,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15)),
                      if (subtitulo != null) ...[
                        const SizedBox(height: 2),
                        Text(subtitulo!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: PandaColors.cinzaTexto, fontSize: 13)),
                      ],
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
}

class _CupomTile extends StatelessWidget {
  const _CupomTile({required this.r});
  final Redemption r;

  (String, Color) _status(String s) {
    switch (s) {
      case 'disponivel':
        return ('Disponível', PandaColors.verdeSucesso);
      case 'usado':
        return ('Usado', PandaColors.cinzaTexto);
      default:
        return ('Expirado', PandaColors.vermelhoAcento);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final (label, cor) = _status(r.status);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? PandaColors.cardDark : PandaColors.branco,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark ? PandaColors.hairlineDark : PandaColors.hairline),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: PandaColors.laranjaSuave,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.confirmation_number_outlined,
                color: PandaColors.laranja, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.rewardTitulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 2),
                Text(r.codigo,
                    style: const TextStyle(
                        color: PandaColors.cinzaTexto,
                        fontSize: 13,
                        letterSpacing: 1)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: cor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(label,
                style: TextStyle(
                    color: cor, fontWeight: FontWeight.w700, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _VazioLinha extends StatelessWidget {
  const _VazioLinha({required this.texto});
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(texto,
          style: const TextStyle(color: PandaColors.cinzaTexto)),
    );
  }
}
