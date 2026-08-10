import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/services/services.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/dimens.dart';
import '../../core/widgets/entrada.dart';
import '../../core/widgets/panda_logo.dart';
import '../../core/widgets/state_views.dart';

/// Carteirinha digital do sócio.
/// Tela simples: mostra o app no caixa, o atendente lê o QR (ou o número)
/// pra identificar você e liberar seus benefícios. Pensada pra qualquer idade.
class CarteirinhaScreen extends ConsumerWidget {
  const CarteirinhaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final isSub = ref.watch(isSubscriberProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Minha carteirinha'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/home'),
        ),
      ),
      body: SafeArea(
        child: user.when(
          loading: () => const LoadingView(),
          error: (_, _) => const ErrorView(mensagem: 'Erro ao carregar.'),
          data: (u) {
            if (u == null) return const EmptyView(mensagem: 'Sem dados.');
            // Código que o caixa lê (id do sócio).
            final codigo = u.uid.toUpperCase();
            return ListView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
              children: escalonar([
                const Text(
                  'Mostre esta tela no caixa do Tio Panda.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: PandaColors.cinzaTexto, fontSize: 15, height: 1.4),
                ),
                const SizedBox(height: 24),
                _Cartao(
                  nome: u.nome,
                  socio: isSub,
                  codigo: codigo,
                ),
                const SizedBox(height: 28),
                _passo(Icons.looks_one_rounded, 'Abra esta tela no caixa.'),
                const SizedBox(height: 12),
                _passo(Icons.looks_two_rounded,
                    'O atendente lê o código (QR ou número).'),
                const SizedBox(height: 12),
                _passo(Icons.looks_3_rounded,
                    'Pronto — você está identificado como sócio.'),
              ]),
            );
          },
        ),
      ),
    );
  }

  Widget _passo(IconData icone, String texto) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icone, color: PandaColors.laranja, size: 26),
        const SizedBox(width: 12),
        Expanded(
          child: Text(texto,
              style: const TextStyle(fontSize: 14.5, height: 1.3)),
        ),
      ],
    );
  }
}

class _Cartao extends StatelessWidget {
  const _Cartao(
      {required this.nome, required this.socio, required this.codigo});
  final String nome;
  final bool socio;
  final String codigo;

  @override
  Widget build(BuildContext context) {
    // Sombra num DecoratedBox externo, com spread negativo: dentro do
    // Container clipado ela escapava pelos cantos de baixo e deixava a
    // silhueta com quinas retas.
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: PandaRadius.blg,
        boxShadow: [
          BoxShadow(
            color: PandaColors.laranja.withValues(alpha: 0.32),
            blurRadius: 30,
            spreadRadius: -8,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [PandaColors.laranja, PandaColors.laranjaEscuro],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: PandaRadius.blg,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Marca d'água: a logo grande sangrando pelo canto, bem apagada.
            // Dá textura ao cartão sem competir com o QR.
            Positioned(
              right: -68,
              bottom: -52,
              child: Opacity(
                opacity: 0.07,
                child: Transform.rotate(
                  angle: -0.18,
                  child: const PandaLogo(size: 210, showWordmark: false),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: _conteudo(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _conteudo(BuildContext context) {
    return Column(
        children: [
          Row(
            children: [
              // Logo real num selo branco — emoji em cartão premium
              // parecia rascunho.
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const PandaLogo(size: 26, showWordmark: false),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('PandaVip',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: PandaRadius.bxs,
                ),
                child: Text(socio ? 'SÓCIO' : 'CLIENTE',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        letterSpacing: 1,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 22),
          // QR grande num "palco" branco.
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: PandaRadius.blg,
            ),
            child: QrImageView(
              data: codigo,
              size: 190,
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 18),
          Text(nome,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          SelectableText(codigo,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 13,
                  letterSpacing: 1.5)),
          const SizedBox(height: 18),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.25)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(socio ? Icons.verified_rounded : Icons.info_outline,
                  color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                  socio
                      ? 'Sócio ativo · prêmios liberados'
                      : 'Assine pra liberar os prêmios',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ],
    );
  }
}
