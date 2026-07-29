import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/models.dart';
import '../../core/services/services.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/app_image.dart';
import '../../core/widgets/state_views.dart';

/// Cardápio com fotos reais, vindo do Firestore. Lista simples por categoria —
/// fácil de rolar e enxergar, em qualquer idade.
class MenuScreen extends ConsumerWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardapio = ref.watch(cardapioProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cardápio'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/home'),
        ),
      ),
      body: SafeArea(
        child: cardapio.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(
            mensagem: 'Não deu pra carregar o cardápio.',
            onRetry: () => ref.invalidate(menuProvider),
          ),
          data: (categorias) {
            if (categorias.isEmpty) {
              return const EmptyView(
                mensagem: 'Cardápio em atualização.\nVolte daqui a pouco.',
                icone: Icons.restaurant_menu_outlined,
              );
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              children: [
                const Text(
                  'Nossos destaques. Sócios têm prêmios e promoções exclusivas.',
                  style: TextStyle(
                      color: PandaColors.cinzaTexto,
                      fontSize: 14.5,
                      height: 1.4),
                ),
                const SizedBox(height: 20),
                for (final cat in categorias) ...[
                  _CategoriaTitulo(cat.nome),
                  const SizedBox(height: 14),
                  for (final item in cat.itens) ...[
                    _ItemCard(item: item),
                    const SizedBox(height: 12),
                  ],
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

class _CategoriaTitulo extends StatelessWidget {
  const _CategoriaTitulo(this.texto);
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 22, height: 3, color: PandaColors.laranja),
        const SizedBox(width: 10),
        Expanded(
          child: Text(texto,
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2)),
        ),
      ],
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.item});
  final MenuItem item;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? PandaColors.cardDark : PandaColors.branco,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: isDark ? PandaColors.hairlineDark : PandaColors.hairline),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 88,
              height: 88,
              // Prato sem foto continua aparecendo: cai num ícone em vez de
              // buraco branco. Nem todo item vai ter imagem.
              child: item.imagem == null
                  ? Container(
                      color: PandaColors.laranjaSuave,
                      child: const Icon(Icons.restaurant_rounded,
                          color: PandaColors.laranja),
                    )
                  : appImage(item.imagem!,
                      erro: Container(color: PandaColors.laranjaSuave)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.nome,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15.5)),
                if (item.descricao.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(item.descricao,
                      style: const TextStyle(
                          color: PandaColors.cinzaTexto,
                          fontSize: 13,
                          height: 1.3)),
                ],
                const SizedBox(height: 8),
                Text(item.precoFormatado,
                    style: const TextStyle(
                        color: PandaColors.laranjaEscuro,
                        fontWeight: FontWeight.w800,
                        fontSize: 15)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
