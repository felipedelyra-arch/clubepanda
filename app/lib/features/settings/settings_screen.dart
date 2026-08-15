import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/services.dart';
import '../../core/services/chamada.dart';
import '../../core/services/fila_pendentes.dart';
import '../../core/services/push_service.dart';
import '../../core/demo.dart';
import '../../core/restaurante.dart';
import '../../core/ui_prefs.dart';
import '../../core/app_prefs.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/dimens.dart';
import '../../core/widgets/state_views.dart';
import '../../core/widgets/entrada.dart';
import '../../core/models/models.dart';
import '../auth/auth_perfil.dart';

/// Versão instalada, pra mostrar no rodapé das configurações. Se a
/// plataforma não souber informar, o rodapé simplesmente não mostra nada.
final _versaoAppProvider = FutureProvider<String?>((ref) async {
  try {
    final info = await PackageInfo.fromPlatform();
    if (info.version.isEmpty) return null;
    return 'versão ${info.version}'
        '${info.buildNumber.isEmpty ? '' : ' (${info.buildNumber})'}';
  } catch (_) {
    return null;
  }
});

/// Tudo que é ajuste, contato ou dado de conta mora aqui, atrás da
/// engrenagem do perfil. Antes essas seções ficavam empilhadas na tela de
/// perfil e enterravam o que interessa ao sócio (carteirinha, cupons).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/perfil'),
        ),
      ),
      body: SafeArea(
        child: user.when(
          loading: () => const LoadingView(),
          error: (e, _) => const ErrorView(mensagem: 'Erro ao carregar.'),
          data: (u) {
            if (u == null) return const EmptyView(mensagem: 'Sem dados.');
            return ListView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              children: escalonar([
                // Fica no topo quando existe: é a única tela onde o sócio
                // descobre que algo pedido por ele não chegou ao servidor.
                const _NaoEnviados(),
                const SectionLabel('Aparência'),
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: _TemaSelector(),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: _TamanhoLetra(),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 28),
                  child: SectionLabel('Notificações'),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: _NotificacoesToggle(),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: _MenuTile(
                      icone: Icons.campaign_outlined,
                      titulo: 'Central de avisos',
                      subtitulo: 'Promoções e novidades recebidas',
                      onTap: () => context.go('/notificacoes')),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 28),
                  child: SectionLabel('Conta'),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: _MenuTile(
                      icone: Icons.person_outline,
                      titulo: 'Editar dados',
                      onTap: () => _abrirEditar(context, u)),
                ),
                _MenuTile(
                    icone: Icons.location_on_outlined,
                    titulo: 'Endereço de entrega',
                    subtitulo: u.endereco ?? 'Não informado',
                    onTap: () => _abrirEditar(context, u)),
                _MenuTile(
                    icone: Icons.cake_outlined,
                    titulo: 'Aniversário',
                    subtitulo: u.nascimento != null
                        ? DateFormat("d 'de' MMMM", 'pt_BR')
                            .format(u.nascimento!)
                        : 'Não informado',
                    onTap: () => _abrirEditar(context, u)),
                _MenuTile(
                    icone: Icons.description_outlined,
                    titulo: 'Termos e privacidade',
                    onTap: () => _abrirTermos(context)),
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: SectionLabel('Fale com a gente'),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: _FaleConosco(),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 28),
                  child: OutlinedButton.icon(
                    onPressed: () {
                      if (kDemo) {
                        context.go('/login');
                        return;
                      }
                      sair(ref);
                    },
                    icon: const Icon(Icons.logout, size: 18),
                    label: const Text('Sair'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: PandaColors.vermelhoAcento,
                      side: const BorderSide(color: PandaColors.vermelhoAcento),
                    ),
                  ),
                ),
                Center(
                  child: TextButton(
                    onPressed: () => _excluirConta(context, ref),
                    style: TextButton.styleFrom(
                        foregroundColor: PandaColors.cinzaTexto),
                    child: const Text('Excluir minha conta'),
                  ),
                ),
                const _Rodape(),
              ]),
            );
          },
        ),
      ),
    );
  }
}


/// Abre um link externo e avisa se o aparelho não souber tratá-lo — antes
/// o toque simplesmente não fazia nada e parecia botão quebrado.
Future<void> _abrirUrl(BuildContext context, String url) async {
  final messenger = ScaffoldMessenger.of(context);
  final uri = Uri.parse(url);
  var ok = false;
  try {
    ok = await canLaunchUrl(uri) &&
        await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    ok = false;
  }
  if (!ok) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Não deu pra abrir aqui no seu aparelho.')),
    );
  }
}

/// Botões grandes de contato — fáceis pra qualquer idade. Moraram na Home
/// até virarem item de configuração: contato é suporte, não vitrine.
class _FaleConosco extends ConsumerWidget {
  const _FaleConosco();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Telefone, WhatsApp e endereço vêm do painel (`config/restaurante`).
    final restaurante = ref.watch(restauranteProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _ContatoBtn(
                icone: Icons.phone_rounded,
                label: 'Ligar',
                onTap: () => _abrirUrl(context, 'tel:${restaurante.telefone}'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ContatoBtn(
                icone: Icons.chat_rounded,
                label: 'WhatsApp',
                onTap: () => _abrirUrl(
                    context, 'https://wa.me/${restaurante.whatsapp}'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ContatoBtn(
                icone: Icons.location_on_rounded,
                label: 'Como chegar',
                onTap: () => _abrirUrl(context,
                    'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(restaurante.endereco)}'),
              ),
            ),
          ],
        ),
        // Só em debug: lembrete de que os contatos ainda são de exemplo.
        // Em release o bloco nem existe.
        if (kDebugMode && restaurante.contatosPendentes) ...[
          const SizedBox(height: 12),
          const Text(
            '⚠️ Contatos de exemplo — preencher em Configurações no painel.',
            style: TextStyle(
                color: PandaColors.vermelhoAcento, fontSize: 12, height: 1.3),
          ),
        ],
      ],
    );
  }
}

class _ContatoBtn extends StatelessWidget {
  const _ContatoBtn(
      {required this.icone, required this.label, required this.onTap});
  final IconData icone;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? PandaColors.cardDark : PandaColors.branco,
      borderRadius: PandaRadius.bmd,
      child: InkWell(
        onTap: onTap,
        borderRadius: PandaRadius.bmd,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: PandaRadius.bmd,
            border: Border.all(
                color:
                    isDark ? PandaColors.hairlineDark : PandaColors.hairline),
          ),
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 4),
          child: Column(
            children: [
              Icon(icone, color: PandaColors.laranja, size: 26),
              const SizedBox(height: 8),
              // scaleDown: "Como chegar" estoura a coluna na letra Máximo.
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Assinatura do rodapé com a versão instalada — o dono consegue conferir
/// qual build está na mão do cliente sem abrir a loja.
class _Rodape extends ConsumerWidget {
  const _Rodape();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final versao = ref.watch(_versaoAppProvider).value;
    final nome = ref.watch(restauranteProvider).nome;
    return Center(
      child: Text(
        versao == null ? 'PandaVip · $nome' : 'PandaVip · $nome · $versao',
        textAlign: TextAlign.center,
        style: const TextStyle(color: PandaColors.cinzaTexto, fontSize: 12),
      ),
    );
  }
}

/// Escolha do tema: acompanha o sistema, claro ou escuro.
/// Três blocos grandes com ícone — mais legível que um toggle pra quem tem
/// pouca prática, e mostra na hora qual está ativo.
class _TemaSelector extends ConsumerWidget {
  const _TemaSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final modo = ref.watch(themeModeProvider);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: isDark ? PandaColors.cardDark : PandaColors.branco,
        borderRadius: PandaRadius.bmd,
        border: Border.all(
            color: isDark ? PandaColors.hairlineDark : PandaColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: PandaColors.laranjaSuave,
                  borderRadius: PandaRadius.bsm,
                ),
                child: const Icon(Icons.contrast_rounded,
                    size: 20, color: PandaColors.laranja),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Tema do app',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            height: 1.25)),
                    const SizedBox(height: 2),
                    Text(rotuloTema(modo),
                        style: const TextStyle(
                            color: PandaColors.cinzaTexto,
                            fontSize: 13,
                            height: 1.25)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _TemaOpcao(
                icone: Icons.brightness_auto_rounded,
                rotulo: 'Automático',
                ativo: modo == ThemeMode.system,
                onTap: () => ref
                    .read(themeModeProvider.notifier)
                    .definir(ThemeMode.system),
              ),
              const SizedBox(width: 10),
              _TemaOpcao(
                icone: Icons.light_mode_rounded,
                rotulo: 'Claro',
                ativo: modo == ThemeMode.light,
                onTap: () => ref
                    .read(themeModeProvider.notifier)
                    .definir(ThemeMode.light),
              ),
              const SizedBox(width: 10),
              _TemaOpcao(
                icone: Icons.dark_mode_rounded,
                rotulo: 'Escuro',
                ativo: modo == ThemeMode.dark,
                onTap: () => ref
                    .read(themeModeProvider.notifier)
                    .definir(ThemeMode.dark),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TemaOpcao extends StatelessWidget {
  const _TemaOpcao(
      {required this.icone,
      required this.rotulo,
      required this.ativo,
      required this.onTap});
  final IconData icone;
  final String rotulo;
  final bool ativo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final corAtiva = PandaColors.laranja;
    final corInativa = isDark ? PandaColors.hairlineDark : PandaColors.hairline;

    return Expanded(
      child: Material(
        color: ativo
            ? PandaColors.laranja.withValues(alpha: isDark ? 0.18 : 0.10)
            : Colors.transparent,
        borderRadius: PandaRadius.bsm,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          borderRadius: PandaRadius.bsm,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: PandaRadius.bsm,
              border: Border.all(
                color: ativo ? corAtiva : corInativa,
                width: ativo ? 1.6 : 1,
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
            child: Column(
              children: [
                Icon(icone,
                    size: 21,
                    color: ativo ? corAtiva : PandaColors.cinzaTexto),
                const SizedBox(height: 7),
                // scaleDown: "Automático" é uma palavra só, não quebra em
                // duas linhas — sem isso viraria "Automá..." na letra grande.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(rotulo,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      style: TextStyle(
                          fontSize: 11.5,
                          height: 1.2,
                          fontWeight: ativo ? FontWeight.w700 : FontWeight.w500,
                          color: ativo ? corAtiva : null)),
                ),
              ],
            ),
          ),
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
      ref.read(textScaleProvider.notifier).ajustar(delta);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? PandaColors.cardDark : PandaColors.branco,
        borderRadius: PandaRadius.bmd,
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
              borderRadius: PandaRadius.bsm,
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
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        height: 1.25)),
                const SizedBox(height: 2),
                Text(rotuloTamanho(scale),
                    style: const TextStyle(
                        color: PandaColors.cinzaTexto,
                        fontSize: 13,
                        height: 1.25)),
              ],
            ),
          ),
          const SizedBox(width: 12),
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

/// Liga/desliga notificações (push). Persistido em shared_preferences.
class _NotificacoesToggle extends ConsumerWidget {
  const _NotificacoesToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ativas = ref.watch(notificationsEnabledProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
            child: const Icon(Icons.notifications_active_rounded,
                size: 20, color: PandaColors.laranja),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Receber notificações',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 2),
                Text(ativas ? 'Promoções e avisos ligados' : 'Desligado',
                    style: const TextStyle(
                        color: PandaColors.cinzaTexto, fontSize: 13)),
              ],
            ),
          ),
          Switch(
            value: ativas,
            activeThumbColor: PandaColors.laranja,
            onChanged: (v) async {
              await ref.read(notificationsEnabledProvider.notifier).definir(v);
              // O toggle precisa valer de verdade: desligado apaga o token
              // FCM (o servidor deixa de ter pra quem mandar), ligado
              // registra de novo. Antes só mudava o texto da tela.
              if (!kDemo) {
                await ref.read(pushServiceProvider).aplicarPreferencia(v);
              }
            },
          ),
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
void _abrirEditar(BuildContext context, AppUser user) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    builder: (_) => _EditarDadosSheet(user: user),
  );
}

void _abrirTermos(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    builder: (_) => const _TermosSheet(),
  );
}
/// Fluxo de exclusão de conta (LGPD / exigência das lojas). Pede confirmação
/// forte, chama a Cloud Function que apaga tudo e volta pro login.
Future<void> _excluirConta(BuildContext context, WidgetRef ref) async {
  final ok = await showDialog<bool>(
    context: context,
    // context do próprio diálogo: com o de fora, o pop derruba a página.
    builder: (ctxDialogo) => AlertDialog(
      title: const Text('Excluir sua conta?'),
      content: const Text(
          'Isso apaga em definitivo seu cadastro, cupons e assinatura. '
          'Não dá pra desfazer.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctxDialogo, false),
            child: const Text('Voltar')),
        TextButton(
          onPressed: () => Navigator.pop(ctxDialogo, true),
          style: TextButton.styleFrom(
              foregroundColor: PandaColors.vermelhoAcento),
          child: const Text('Excluir conta'),
        ),
      ],
    ),
  );
  if (ok != true) return;

  if (kDemo) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Exclusão desativada no modo demo')),
      );
    }
    return;
  }

  // Loading bloqueante enquanto apaga.
  if (context.mounted) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
          child: CircularProgressIndicator(color: PandaColors.laranja)),
    );
  }
  try {
    // Insistir é seguro: a exclusão grava o progresso etapa por etapa e
    // continua de onde parou (functions/src/account.ts). Antes, uma queda no
    // meio deixava a conta pela metade e o sócio só via um erro genérico.
    await Chamada.chamar(
      ref.read(functionsProvider),
      'deleteAccount',
      repetir: true,
    );
    await sair(ref);
    if (context.mounted) {
      // rootNavigator: o loading foi empilhado lá, não no Navigator da shell.
      Navigator.of(context, rootNavigator: true).pop(); // fecha loading
      context.go('/login');
    }
  } catch (e) {
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop(); // fecha loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            mensagemDeErro(e, acaoFalhou: 'A conta NÃO foi excluída'),
          ),
        ),
      );
    }
  }
}

/// Edição dos dados do sócio (nome, telefone, endereço, aniversário).
/// Grava direto no doc users/{uid} — o stream de currentUser atualiza a tela.
class _EditarDadosSheet extends ConsumerStatefulWidget {
  const _EditarDadosSheet({required this.user});
  final AppUser user;

  @override
  ConsumerState<_EditarDadosSheet> createState() => _EditarDadosSheetState();
}

class _EditarDadosSheetState extends ConsumerState<_EditarDadosSheet> {
  late final TextEditingController _nome;
  late final TextEditingController _telefone;
  late final TextEditingController _endereco;
  DateTime? _nascimento;
  bool _salvando = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _nome = TextEditingController(text: widget.user.nome);
    _telefone = TextEditingController(text: widget.user.telefone);
    _endereco = TextEditingController(text: widget.user.endereco ?? '');
    _nascimento = widget.user.nascimento;
  }

  @override
  void dispose() {
    _nome.dispose();
    _telefone.dispose();
    _endereco.dispose();
    super.dispose();
  }

  Future<void> _escolherData() async {
    final agora = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _nascimento ?? DateTime(agora.year - 25),
      firstDate: DateTime(1920),
      lastDate: agora,
      locale: const Locale('pt', 'BR'),
      helpText: 'Sua data de nascimento',
    );
    if (d != null) setState(() => _nascimento = d);
  }

  Future<void> _salvar() async {
    if (_nome.text.trim().isEmpty) {
      setState(() => _erro = 'Informe seu nome.');
      return;
    }
    setState(() {
      _salvando = true;
      _erro = null;
    });
    if (kDemo) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      // O messenger tem que ser capturado ANTES do pop: depois do pop o
      // context da sheet já não acha mais o Scaffold e o aviso some.
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        const SnackBar(content: Text('Edição desativada no modo demo')),
      );
      return;
    }
    try {
      await ref
          .read(firestoreProvider)
          .collection('users')
          .doc(widget.user.uid)
          .update({
        'nome': _nome.text.trim(),
        'telefone': _telefone.text.trim(),
        'endereco': _endereco.text.trim().isEmpty ? null : _endereco.text.trim(),
        'nascimento':
            _nascimento != null ? Timestamp.fromDate(_nascimento!) : null,
      });
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        const SnackBar(content: Text('Dados atualizados.')),
      );
    } catch (e) {
      setState(() => _erro = 'Não foi possível salvar. Tente de novo.');
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dataLabel = _nascimento != null
        ? DateFormat("d 'de' MMMM 'de' y", 'pt_BR').format(_nascimento!)
        : 'Escolher data';
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Editar dados',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 20),
          _campo(label: 'Nome', controller: _nome),
          const SizedBox(height: 14),
          _campo(
              label: 'Telefone',
              controller: _telefone,
              keyboardType: TextInputType.phone),
          const SizedBox(height: 14),
          _campo(label: 'Endereço de entrega', controller: _endereco),
          const SizedBox(height: 14),
          const Text('Aniversário',
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: PandaColors.cinzaTexto)),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            onPressed: _escolherData,
            icon: const Icon(Icons.cake_outlined, size: 18),
            label: Align(
                alignment: Alignment.centerLeft, child: Text(dataLabel)),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              alignment: Alignment.centerLeft,
            ),
          ),
          if (_erro != null) ...[
            const SizedBox(height: 14),
            Text(_erro!,
                style: const TextStyle(color: PandaColors.vermelhoAcento)),
          ],
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _salvando ? null : _salvar,
            style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(52)),
            child: _salvando
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  Widget _campo({
    required String label,
    required TextEditingController controller,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: PandaColors.cinzaTexto)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            filled: true,
            fillColor: Theme.of(context).brightness == Brightness.dark
                ? PandaColors.cardDark
                : PandaColors.cinzaClaro,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }
}

/// Termos e política de privacidade — texto base, ajuste conforme o jurídico.
class _TermosSheet extends ConsumerWidget {
  const _TermosSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final restaurante = ref.watch(restauranteProvider);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      builder: (_, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        children: [
          Text('Termos e privacidade',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          ...const [
            ('Sobre o PandaVip',
                'O PandaVip é o programa de vantagens do restaurante Tio Panda. Ao se tornar sócio, você tem acesso a promoções e prêmios liberados pelo restaurante, dentro dos prazos e condições informados em cada oferta.'),
            ('Uso dos seus dados',
                'Coletamos apenas os dados necessários para identificar você como sócio e oferecer os benefícios: nome, e-mail, telefone, endereço e data de nascimento. Não vendemos seus dados a terceiros.'),
            ('Prêmios e resgates',
                'Cada prêmio é liberado pelo restaurante com prazo e quantidade limitados. O resgate é confirmado no caixa pela leitura do seu QR. Prêmios já resgatados ou fora do prazo não podem ser reivindicados novamente.'),
            ('Assinatura',
                'A assinatura pode ser cancelada quando quiser. Os benefícios seguem ativos até o fim do período já pago.'),
            ('Contato',
                'Dúvidas sobre seus dados ou sobre o Clube? Use os botões da seção "Fale com a gente", aqui mesmo nas configurações.'),
          ].map((s) => _Secao(titulo: s.$1, texto: s.$2)),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              final uri = Uri.parse(restaurante.politicaPrivacidadeUrl);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: const Text('Ver política de privacidade completa'),
            style:
                OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () async {
              final uri = Uri.parse(restaurante.termosUrl);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: const Text('Ver termos de uso completos'),
            style:
                OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          ),
        ],
      ),
    );
  }
}

/// Ações que o sócio pediu e não chegaram ao servidor.
///
/// Some da tela quando não há nenhuma. Existe porque a alternativa — descartar
/// em silêncio o que esgotou as tentativas — é justamente o que faz a pessoa
/// descobrir na fatura que o cancelamento nunca aconteceu.
class _NaoEnviados extends ConsumerWidget {
  const _NaoEnviados();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itens = ref.watch(naoEnviadosProvider);
    if (itens.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: PandaColors.laranjaSuave,
          borderRadius: PandaRadius.bmd,
          border: Border.all(color: PandaColors.laranja.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.sync_problem_outlined,
                    color: PandaColors.laranjaEscuro),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    itens.length == 1
                        ? '1 ação não foi enviada'
                        : '${itens.length} ações não foram enviadas',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: PandaColors.laranjaEscuro,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Tentamos várias vezes e não deu. Nada foi perdido — você pode '
              'tentar de novo agora.',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            for (final p in itens)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.descricao,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (p.ultimoErro != null)
                      Text(p.ultimoErro!,
                          style: const TextStyle(
                              fontSize: 12.5,
                              height: 1.35,
                              color: PandaColors.cinzaTexto)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => ref
                              .read(filaPendentesProvider.notifier)
                              .tentarDeNovo(p.id),
                          child: const Text('Tentar de novo'),
                        ),
                        TextButton(
                          onPressed: () => ref
                              .read(filaPendentesProvider.notifier)
                              .descartar(p.id),
                          child: const Text('Descartar',
                              style: TextStyle(color: PandaColors.cinzaTexto)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Secao extends StatelessWidget {
  const _Secao({required this.titulo, required this.texto});
  final String titulo;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 15.5)),
          const SizedBox(height: 6),
          Text(texto,
              style: const TextStyle(
                  color: PandaColors.cinzaTexto, fontSize: 14, height: 1.5)),
        ],
      ),
    );
  }
}
