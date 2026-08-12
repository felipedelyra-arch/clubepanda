import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/services/services.dart';
import '../../core/demo.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/panda_logo.dart';
import 'auth_perfil.dart';
import 'botao_social.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nome = TextEditingController();
  final _email = TextEditingController();
  final _telefone = TextEditingController();
  final _senha = TextEditingController();
  final _codigo = TextEditingController();
  DateTime? _nascimento;
  bool _loading = false;
  String? _erro;

  // Mesma paleta escura da tela de login, pro botão do Google ficar igual nas
  // duas. Fixa de propósito: não segue o tema claro/escuro do app.
  static const _cardEscuro = Color(0xFF211C16);
  static const _bordaEscura = Color(0x12FFFFFF);

  @override
  void dispose() {
    _nome.dispose();
    _email.dispose();
    _telefone.dispose();
    _senha.dispose();
    _codigo.dispose();
    super.dispose();
  }

  Future<void> _escolherData() async {
    final agora = DateTime.now();
    final escolhida = await showDatePicker(
      context: context,
      initialDate: _nascimento ?? DateTime(agora.year - 25, agora.month, agora.day),
      firstDate: DateTime(1920),
      lastDate: agora,
      locale: const Locale('pt', 'BR'),
      helpText: 'Sua data de nascimento',
    );
    if (escolhida != null) setState(() => _nascimento = escolhida);
  }

  /// Cadastro pelo Google. Não passa por aqui nada do formulário: o que falta
  /// (telefone e nascimento) é pedido depois, em /completar-perfil, pra não
  /// travar o atalho de um toque com um formulário.
  Future<void> _cadastrarComGoogle() async {
    if (kDemo) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login social desativado no modo demo')),
      );
      return;
    }
    setState(() {
      _loading = true;
      _erro = null;
    });
    try {
      await entrarComGoogle(ref);
    } on FirebaseAuthException catch (e) {
      setState(() => _erro = _mensagemErro(e.code));
    } catch (_) {
      setState(() => _erro = 'Não foi possível entrar com o Google.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _cadastrar() async {
    if (!_formKey.currentState!.validate()) return;
    // Demo: simula cadastro e entra direto.
    if (kDemo) {
      context.go('/home');
      return;
    }
    setState(() {
      _loading = true;
      _erro = null;
    });
    try {
      final cred =
          await ref.read(firebaseAuthProvider).createUserWithEmailAndPassword(
                email: _email.text.trim(),
                password: _senha.text,
              );
      await cred.user?.updateDisplayName(_nome.text.trim());

      // Link de confirmação. O router segura em /verificar-email enquanto o
      // e-mail não for confirmado — é o que impede cadastro com endereço
      // inventado ou de outra pessoa.
      try {
        await cred.user?.sendEmailVerification();
      } catch (_) {
        // Limite de envio do Firebase: a tela de verificação tem "Reenviar".
      }

      // Doc de perfil também é criado no backend (onAuthUserCreate);
      // aqui garante os campos extras informados no cadastro.
      await ref.read(firestoreProvider).doc('users/${cred.user!.uid}').set({
        'nome': _nome.text.trim(),
        'email': _email.text.trim(),
        'telefone': _telefone.text.trim(),
        if (_nascimento != null)
          'nascimento': Timestamp.fromDate(_nascimento!),
        'criadoEm': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Código de indicação (opcional). Falha aqui não bloqueia o cadastro.
      final codigo = _codigo.text.trim();
      if (codigo.isNotEmpty) {
        try {
          await ref
              .read(functionsProvider)
              .httpsCallable('applyReferral')
              .call({'code': codigo});
        } catch (_) {
          // Código inválido/já usado — segue sem interromper o cadastro.
        }
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _erro = _mensagemErro(e.code));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _mensagemErro(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'Esse e-mail já tem conta. Faça login.';
      case 'invalid-email':
        return 'E-mail inválido.';
      case 'weak-password':
        return 'Senha fraca (mínimo 6 caracteres).';
      default:
        return 'Não foi possível cadastrar. Tente de novo.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/login'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: PandaLogo(size: 88, showWordmark: false)),
                const SizedBox(height: 24),
                Center(
                  child: Text('Criar conta',
                      style: Theme.of(context).textTheme.headlineMedium),
                ),
                const SizedBox(height: 6),
                const Center(
                  child: Text(
                    'Leva um minuto e já começa a valer.',
                    style: TextStyle(color: PandaColors.cinzaTexto, fontSize: 15),
                  ),
                ),
                const SizedBox(height: 32),
                _Campo(label: 'Nome'),
                TextFormField(
                  controller: _nome,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(hintText: 'Como te chamam?'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Informe seu nome'
                      : null,
                ),
                const SizedBox(height: 18),
                _Campo(label: 'E-mail'),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(hintText: 'voce@email.com'),
                  validator: (v) => (v == null || !v.contains('@'))
                      ? 'E-mail inválido'
                      : null,
                ),
                const SizedBox(height: 18),
                _Campo(label: 'Telefone (WhatsApp)'),
                TextFormField(
                  controller: _telefone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(hintText: '(14) 90000-0000'),
                ),
                const SizedBox(height: 18),
                _Campo(label: 'Aniversário'),
                InkWell(
                  onTap: _escolherData,
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.cake_outlined),
                      hintText: 'Ganhe um mimo no seu dia',
                    ),
                    child: Text(
                      _nascimento == null
                          ? 'Selecione a data'
                          : DateFormat("d 'de' MMMM 'de' y", 'pt_BR')
                              .format(_nascimento!),
                      style: TextStyle(
                        fontSize: 15,
                        color: _nascimento == null
                            ? PandaColors.cinzaTexto
                            : null,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                _Campo(label: 'Senha'),
                TextFormField(
                  controller: _senha,
                  obscureText: true,
                  decoration:
                      const InputDecoration(hintText: 'Mínimo 6 caracteres'),
                  validator: (v) =>
                      (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null,
                ),
                const SizedBox(height: 18),
                _Campo(label: 'Código de indicação (opcional)'),
                TextFormField(
                  controller: _codigo,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.group_add_outlined),
                      hintText: 'Tem um código de um amigo?'),
                ),
                if (_erro != null) ...[
                  const SizedBox(height: 14),
                  Text(_erro!,
                      style:
                          const TextStyle(color: PandaColors.vermelhoAcento)),
                ],
                const SizedBox(height: 28),
                ElevatedButton(
                  onPressed: _loading ? null : _cadastrar,
                  child: _loading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Criar conta'),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Expanded(
                        child: Divider(color: PandaColors.hairline)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('ou',
                          style: TextStyle(
                              color: PandaColors.cinzaTexto, fontSize: 13)),
                    ),
                    const Expanded(
                        child: Divider(color: PandaColors.hairline)),
                  ],
                ),
                const SizedBox(height: 16),
                // Atalho do Google também aqui: quem chega em "Criar conta"
                // pelo caminho longo do formulário também quer o de um toque.
                // Mesmas cores da tela de login (variante escura aprovada do
                // Google). O branco de antes destoava do resto da tela.
                BotaoSocial(
                  onTap: _loading ? null : _cadastrarComGoogle,
                  icone: const GoogleG(),
                  texto: 'Continuar com Google',
                  corFundo: _cardEscuro,
                  corBorda: _bordaEscura,
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: () => context.go('/login'),
                    child: const Text('Já tenho conta'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Rótulo pequeno acima de cada campo.
class _Campo extends StatelessWidget {
  const _Campo({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 7),
      child: Text(label,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: PandaColors.cinzaTexto)),
    );
  }
}
