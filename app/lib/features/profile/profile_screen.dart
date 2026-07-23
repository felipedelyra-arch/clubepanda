import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/services.dart';
import '../../core/demo.dart';
import '../../core/ui_prefs.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/state_views.dart';
import '../../core/models/models.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final redemptions = ref.watch(redemptionsProvider);
    final isSub = ref.watch(isSubscriberProvider);
    final cupons = redemptions.value ?? const [];

    return Scaffold(
      body: SafeArea(
        child: user.when(
          loading: () => const LoadingView(),
          error: (e, _) => const ErrorView(mensagem: 'Erro ao carregar perfil.'),
          data: (u) {
            if (u == null) return const EmptyView(mensagem: 'Sem dados.');
            return ListView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              children: [
                _Header(user: u, isSub: isSub),
                const SizedBox(height: 16),
                _StatsRow(
                  pontos: u.pontos,
                  cupons: cupons.length,
                  socio: isSub,
                ),
                const SizedBox(height: 28),
                const SectionLabel('Acessibilidade'),
                const SizedBox(height: 12),
                const _TamanhoLetra(),
                const SizedBox(height: 32),
                const SectionLabel('Meus cupons'),
                const SizedBox(height: 12),
                redemptions.when(
                  loading: () => const Padding(
                      padding: EdgeInsets.only(top: 16), child: LoadingView()),
                  error: (_, _) => const Text('Erro ao carregar cupons.'),
                  data: (list) {
                    if (list.isEmpty) {
                      return const _VazioLinha(
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
                    onTap: () {}),
                _MenuTile(
                    icone: Icons.location_on_outlined,
                    titulo: 'Endereço de entrega',
                    subtitulo: u.endereco ?? 'Não informado',
                    onTap: () {}),
                _MenuTile(
                    icone: Icons.notifications_none_rounded,
                    titulo: 'Notificações',
                    onTap: () {}),
                _MenuTile(
                    icone: Icons.description_outlined,
                    titulo: 'Termos e privacidade',
                    onTap: () {}),
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
                const SizedBox(height: 16),
                const Center(
                  child: Text('Clube Panda · Tio Panda',
                      style: TextStyle(
                          color: PandaColors.cinzaTexto, fontSize: 12)),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Controle de tamanho da letra (A− / A+) — acessibilidade pra todas as idades.
class _TamanhoLetra extends ConsumerWidget {
  const _TamanhoLetra();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scale = ref.watch(textScaleProvider);

    void ajustar(double delta) {
      final novo = (scale + delta).clamp(kMinTextScale, kMaxTextScale);
      ref.read(textScaleProvider.notifier).state =
          double.parse(novo.toStringAsFixed(2));
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? PandaColors.cardDark : PandaColors.branco,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark ? PandaColors.hairlineDark : PandaColors.hairline),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: PandaColors.laranjaSuave,
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(Icons.text_fields_rounded,
                size: 20, color: PandaColors.laranja),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Tamanho da letra',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 2),
                Text(rotuloTamanho(scale),
                    style: const TextStyle(
                        color: PandaColors.cinzaTexto, fontSize: 13)),
              ],
            ),
          ),
          _AjusteBtn(
            texto: 'A',
            fontSize: 14,
            ativo: scale > kMinTextScale,
            onTap: () => ajustar(-kStepTextScale),
          ),
          const SizedBox(width: 10),
          _AjusteBtn(
            texto: 'A',
            fontSize: 20,
            ativo: scale < kMaxTextScale,
            onTap: () => ajustar(kStepTextScale),
          ),
        ],
      ),
    );
  }
}

class _AjusteBtn extends StatelessWidget {
  const _AjusteBtn(
      {required this.texto,
      required this.fontSize,
      required this.ativo,
      required this.onTap});
  final String texto;
  final double fontSize;
  final bool ativo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ativo ? PandaColors.laranja : PandaColors.laranja.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: ativo ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Text(texto,
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: fontSize,
                    fontWeight: FontWeight.w800)),
          ),
        ),
      ),
    );
  }
}

/// Cabeçalho — avatar grande, nome, e-mail, status de sócio.
class _Header extends StatelessWidget {
  const _Header({required this.user, required this.isSub});
  final AppUser user;
  final bool isSub;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: PandaColors.laranja, width: 2),
          ),
          child: CircleAvatar(
            radius: 42,
            backgroundColor: PandaColors.laranjaSuave,
            backgroundImage:
                user.fotoUrl != null ? NetworkImage(user.fotoUrl!) : null,
            child: user.fotoUrl == null
                ? const Text('🐼', style: TextStyle(fontSize: 36))
                : null,
          ),
        ),
        const SizedBox(height: 14),
        Text(user.nome,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center),
        const SizedBox(height: 2),
        Text(user.email,
            style: const TextStyle(color: PandaColors.cinzaTexto)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSub
                ? PandaColors.verdeSucesso.withValues(alpha: 0.12)
                : PandaColors.cinzaClaro,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(isSub ? Icons.verified_rounded : Icons.person_outline,
                  size: 16,
                  color:
                      isSub ? PandaColors.verdeSucesso : PandaColors.cinzaTexto),
              const SizedBox(width: 6),
              Text(isSub ? 'Sócio do Clube' : 'Cliente',
                  style: TextStyle(
                      color: isSub
                          ? PandaColors.verdeSucesso
                          : PandaColors.cinzaTexto,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Linha de estatísticas: pontos, cupons, plano.
class _StatsRow extends StatelessWidget {
  const _StatsRow(
      {required this.pontos, required this.cupons, required this.socio});
  final int pontos;
  final int cupons;
  final bool socio;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Stat(valor: '$pontos', label: 'Pontos', icone: Icons.star_rounded),
        const SizedBox(width: 12),
        _Stat(
            valor: '$cupons',
            label: 'Cupons',
            icone: Icons.confirmation_number_outlined),
        const SizedBox(width: 12),
        _Stat(
            valor: socio ? 'Sim' : 'Não',
            label: 'Sócio',
            icone: Icons.workspace_premium_outlined),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.valor, required this.label, required this.icone});
  final String valor;
  final String label;
  final IconData icone;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isDark ? PandaColors.cardDark : PandaColors.branco,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isDark ? PandaColors.hairlineDark : PandaColors.hairline),
        ),
        child: Column(
          children: [
            Icon(icone, color: PandaColors.laranja, size: 22),
            const SizedBox(height: 8),
            Text(valor,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    color: PandaColors.cinzaTexto, fontSize: 12)),
          ],
        ),
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
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: PandaColors.laranjaSuave,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icone, size: 19, color: PandaColors.laranja),
                ),
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
      child: Text(texto, style: const TextStyle(color: PandaColors.cinzaTexto)),
    );
  }
}
