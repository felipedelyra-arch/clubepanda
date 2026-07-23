import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      appBar: AppBar(title: const Text('Perfil')),
      body: user.when(
        loading: () => const LoadingView(),
        error: (e, _) => const ErrorView(mensagem: 'Erro ao carregar perfil.'),
        data: (u) {
          if (u == null) return const EmptyView(mensagem: 'Sem dados.');
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 44,
                      backgroundColor:
                          PandaColors.laranja.withValues(alpha: 0.15),
                      backgroundImage:
                          u.fotoUrl != null ? NetworkImage(u.fotoUrl!) : null,
                      child: u.fotoUrl == null
                          ? const Text('🐼', style: TextStyle(fontSize: 36))
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Text(u.nome,
                        style: Theme.of(context).textTheme.titleLarge),
                    Text(u.email,
                        style:
                            const TextStyle(color: PandaColors.cinzaTexto)),
                    const SizedBox(height: 12),
                    PointsBadge(pontos: u.pontos),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              _Secao(titulo: 'Meus cupons resgatados'),
              redemptions.when(
                loading: () => const Padding(
                    padding: EdgeInsets.all(16), child: LoadingView()),
                error: (_, _) =>
                    const Text('Erro ao carregar cupons.'),
                data: (list) {
                  if (list.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text('Nenhum cupom ainda.',
                          style: TextStyle(color: PandaColors.cinzaTexto)),
                    );
                  }
                  return Column(
                    children: list.map((r) => _CupomTile(r: r)).toList(),
                  );
                },
              ),
              const SizedBox(height: 24),
              const _Secao(titulo: 'Conta'),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Editar dados'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {},
              ),
              ListTile(
                leading: const Icon(Icons.location_on_outlined),
                title: const Text('Endereço de entrega'),
                subtitle: Text(u.endereco ?? 'Não informado'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {},
              ),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('Termos e privacidade'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {},
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  if (kDemo) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Sair desativado no modo demo 🐼')),
                    );
                    return;
                  }
                  ref.read(firebaseAuthProvider).signOut();
                },
                icon: const Icon(Icons.logout),
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
    );
  }
}

class _Secao extends StatelessWidget {
  const _Secao({required this.titulo});
  final String titulo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(titulo, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _CupomTile extends StatelessWidget {
  const _CupomTile({required this.r});
  final Redemption r;

  Color _cor(String status) {
    switch (status) {
      case 'disponivel':
        return PandaColors.verdeSucesso;
      case 'usado':
        return PandaColors.cinzaTexto;
      default:
        return PandaColors.vermelhoAcento;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.confirmation_number_outlined,
            color: PandaColors.laranja),
        title: Text(r.rewardTitulo),
        subtitle: Text('Código: ${r.codigo}'),
        trailing: Text(
          r.status,
          style: TextStyle(color: _cor(r.status), fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
