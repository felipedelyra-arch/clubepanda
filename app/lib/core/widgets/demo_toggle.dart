import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../demo.dart';
import '../theme/colors.dart';

/// Interruptor só do modo demo: alterna entre ver o app como sócio ou visitante.
class DemoToggle extends ConsumerWidget {
  const DemoToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!kDemo) return const SizedBox.shrink();
    final socio = ref.watch(demoIsSubscriber);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: PandaColors.cinzaClaro,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PandaColors.hairline),
      ),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Text('DEMO',
                style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w700,
                    color: PandaColors.cinzaTexto)),
          ),
          _seg(context, ref, 'Sócio', socio),
          _seg(context, ref, 'Visitante', !socio),
        ],
      ),
    );
  }

  Widget _seg(BuildContext context, WidgetRef ref, String label, bool ativo) {
    return Expanded(
      child: GestureDetector(
        onTap: () =>
            ref.read(demoIsSubscriber.notifier).state = label == 'Sócio',
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: ativo ? PandaColors.laranja : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          alignment: Alignment.center,
          child: Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: ativo ? Colors.white : PandaColors.cinzaTexto)),
        ),
      ),
    );
  }
}
