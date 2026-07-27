import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/demo.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/app_image.dart';

/// Cardápio com fotos reais. Lista simples por categoria — fácil de rolar
/// e enxergar, em qualquer idade.
class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cardápio'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          children: [
            const Text(
              'Nossos destaques. Sócios têm prêmios e promoções exclusivas.',
              style: TextStyle(
                  color: PandaColors.cinzaTexto, fontSize: 14.5, height: 1.4),
            ),
            const SizedBox(height: 20),
            for (final cat in demoCardapio) ...[
              _CategoriaTitulo(cat.nome),
              const SizedBox(height: 14),
              for (final item in cat.itens) ...[
                _ItemCard(item: item),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 16),
            ],
          ],
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
        Text(texto,
            style: const TextStyle(
                fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: 0.2)),
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
              child: appImage(item.imagem,
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
                const SizedBox(height: 4),
                Text(item.descricao,
                    style: const TextStyle(
                        color: PandaColors.cinzaTexto,
                        fontSize: 13,
                        height: 1.3)),
                const SizedBox(height: 8),
                Text(item.preco,
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
