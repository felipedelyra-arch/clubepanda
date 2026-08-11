import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/analytics.dart';
import '../../core/models/models.dart';
import '../../core/pix.dart';
import '../../core/restaurante.dart';
import '../../core/services/services.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/dimens.dart';
import '../../core/widgets/state_views.dart';

/// Abre a folha de gorjeta. O dinheiro vai direto do cliente pro funcionário
/// por Pix — o restaurante não entra no caminho e o app não movimenta valor
/// nenhum, só mostra o código que o banco do cliente vai ler.
void mostrarGorjeta(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    builder: (_) => const _GorjetaSheet(),
  );
}

class _GorjetaSheet extends ConsumerStatefulWidget {
  const _GorjetaSheet();

  @override
  ConsumerState<_GorjetaSheet> createState() => _GorjetaSheetState();
}

class _GorjetaSheetState extends ConsumerState<_GorjetaSheet> {
  Funcionario? _escolhido;
  bool _copiado = false;

  @override
  Widget build(BuildContext context) {
    final equipe = ref.watch(funcionariosProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: _escolhido == null
          ? equipe.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: LoadingView(),
              ),
              error: (_, _) => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: ErrorView(
                    mensagem: 'Não deu pra carregar a equipe agora.'),
              ),
              data: _listaEquipe,
            )
          : _codigoPix(_escolhido!),
    );
  }

  /// Passo 1: quem te atendeu?
  Widget _listaEquipe(List<Funcionario> equipe) {
    if (equipe.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: EmptyView(
          icone: Icons.volunteer_activism_outlined,
          mensagem:
              'A equipe ainda não foi cadastrada. Fale com o restaurante pra '
              'deixar sua gorjeta.',
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Text('Deixar uma gorjeta',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text(
          'Escolha quem te atendeu. O Pix vai direto pra pessoa, e o valor '
          'quem decide é você, no seu banco.',
          textAlign: TextAlign.center,
          style: TextStyle(color: PandaColors.cinzaTexto, height: 1.4),
        ),
        const SizedBox(height: 20),
        // Lista rolável só quando precisa: com 3 nomes a folha fica curta.
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.42,
          ),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: equipe.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _ItemPessoa(
              funcionario: equipe[i],
              onTap: () {
                logEventoUi(ref, 'tip_person_selected');
                setState(() => _escolhido = equipe[i]);
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Agora não'),
        ),
      ],
    );
  }

  /// Passo 2: o código pra pagar.
  Widget _codigoPix(Funcionario f) {
    final restaurante = ref.watch(restauranteProvider);

    // Se a chave cadastrada for inválida a ponto de nem gerar código, é melhor
    // dizer isso do que mostrar um QR que o banco recusa na frente do cliente.
    String? codigo;
    try {
      codigo = pixCopiaECola(
        chave: f.chavePix,
        nome: f.nome,
        cidade: restaurante.cidade,
      );
    } catch (_) {
      codigo = null;
    }

    if (codigo == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ErrorView(
              mensagem:
                  'A chave Pix de ${f.nome} está incompleta no cadastro. '
                  'Avise o restaurante.',
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => setState(() => _escolhido = null),
              child: const Text('Escolher outra pessoa'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Text('Gorjeta para ${f.nome}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text(
            'Abra o app do seu banco, escolha Pix, leia o código e digite '
            'quanto quiser.',
            textAlign: TextAlign.center,
            style: TextStyle(color: PandaColors.cinzaTexto, height: 1.4),
          ),
          const SizedBox(height: 20),
          // Fundo branco fixo de propósito: leitor de QR precisa do contraste,
          // e no tema escuro um QR sobre superfície escura não é lido.
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: PandaRadius.blg,
                border: Border.all(color: PandaColors.hairline),
              ),
              child: QrImageView(
                  data: codigo, size: 190, backgroundColor: Colors.white),
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: codigo!));
              if (!mounted) return;
              logEventoUi(ref, 'tip_code_copied');
              setState(() => _copiado = true);
            },
            icon: Icon(_copiado ? Icons.check : Icons.copy_outlined, size: 18),
            label: Text(_copiado ? 'Código copiado' : 'Copiar código Pix'),
          ),
          const SizedBox(height: 16),
          // O único aviso que realmente protege o cliente: chave errada não tem
          // como o app detectar, mas o banco mostra o nome antes de confirmar.
          _AvisoFavorecido(),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => setState(() {
              _escolhido = null;
              _copiado = false;
            }),
            child: const Text('Escolher outra pessoa'),
          ),
          ElevatedButton(
            // Context do builder da folha: com o ShellRoute do GoRouter, um pop
            // com o context de fora derruba a página inteira em vez da folha.
            onPressed: () => Navigator.pop(context),
            child: const Text('Pronto'),
          ),
        ],
      ),
    );
  }
}

/// Aviso de conferir o favorecido antes de pagar.
///
/// Fundo cor fixa vira mancha clara no tema escuro — aqui o laranja entra como
/// véu sobre a superfície do tema, e o texto vem do próprio tema, então o bloco
/// tem o mesmo peso visual nos dois modos sem perder contraste.
class _AvisoFavorecido extends StatelessWidget {
  const _AvisoFavorecido();

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final escuro = tema.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: escuro
            ? PandaColors.laranja.withValues(alpha: 0.12)
            : PandaColors.laranjaSuave,
        borderRadius: PandaRadius.bsm,
        border: Border.all(
          color: PandaColors.laranja.withValues(alpha: escuro ? 0.38 : 0.22),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 18, color: PandaColors.laranja),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Confira o nome do favorecido na tela do seu banco antes de '
              'confirmar.',
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: tema.textTheme.bodyMedium?.color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemPessoa extends StatelessWidget {
  const _ItemPessoa({required this.funcionario, required this.onTap});

  final Funcionario funcionario;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final iniciais = funcionario.nome.trim().isEmpty
        ? '?'
        : funcionario.nome.trim()[0].toUpperCase();

    return Material(
      color: tema.cardColor,
      borderRadius: PandaRadius.bsm,
      child: InkWell(
        onTap: onTap,
        borderRadius: PandaRadius.bsm,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: PandaColors.laranjaSuave,
                child: Text(iniciais,
                    style: const TextStyle(
                        color: PandaColors.laranja,
                        fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(funcionario.nome,
                        style: tema.textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    if (funcionario.funcao.isNotEmpty)
                      Text(funcionario.funcao,
                          style: const TextStyle(
                              fontSize: 13, color: PandaColors.cinzaTexto)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: PandaColors.cinzaTexto),
            ],
          ),
        ),
      ),
    );
  }
}
