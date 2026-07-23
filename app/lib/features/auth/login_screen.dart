import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/services.dart';
import '../../core/demo.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/panda_logo.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  // No modo demo já vem preenchido com uma conta de teste.
  final _email = TextEditingController(text: kDemo ? 'cliente@teste.com' : '');
  final _senha = TextEditingController(text: kDemo ? '123456' : '');
  bool _loading = false;
  String? _erro;

  @override
  void dispose() {
    _email.dispose();
    _senha.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    if (!_formKey.currentState!.validate()) return;
    if (kDemo) {
      context.go('/home');
      return;
    }
    setState(() {
      _loading = true;
      _erro = null;
    });
    try {
      await ref.read(firebaseAuthProvider).signInWithEmailAndPassword(
            email: _email.text.trim(),
            password: _senha.text,
          );
    } on FirebaseAuthException catch (e) {
      setState(() => _erro = _mensagemErro(e.code));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _recuperarSenha() async {
    if (_email.text.trim().isEmpty) {
      setState(() => _erro = 'Digite seu e-mail para recuperar a senha.');
      return;
    }
    await ref
        .read(firebaseAuthProvider)
        .sendPasswordResetEmail(email: _email.text.trim());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('E-mail de recuperação enviado.')),
      );
    }
  }

  String _mensagemErro(String code) {
    switch (code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'E-mail ou senha incorretos.';
      case 'invalid-email':
        return 'E-mail inválido.';
      case 'too-many-requests':
        return 'Muitas tentativas. Tente mais tarde.';
      default:
        return 'Não foi possível entrar. Tente de novo.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheet = isDark ? PandaColors.fundoDark : PandaColors.branco;
    final insets = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: sheet,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // Foto do restaurante no topo.
          SizedBox(
            height: 250,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset('assets/images/login_bg.jpg',
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        Container(color: PandaColors.laranja)),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.25),
                        Colors.transparent,
                        sheet,
                      ],
                      stops: const [0, 0.55, 1],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Painel de login, sobreposto à foto com cantos arredondados.
          Positioned(
            top: 216,
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: sheet,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(34)),
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(28, 0, 28, insets + 32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 26),
                      const Center(child: PandaLogo(size: 104)),
                      const SizedBox(height: 22),
                      Center(
                        child: Text('Que bom te ver!',
                            style: Theme.of(context).textTheme.headlineMedium),
                      ),
                      const SizedBox(height: 8),
                      const Center(
                        child: Text(
                          'Entre e aproveite suas vantagens de sócio.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: PandaColors.cinzaTexto, fontSize: 15),
                        ),
                      ),
                      const SizedBox(height: 40),
                      const _Campo(label: 'E-mail'),
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        decoration:
                            const InputDecoration(hintText: 'voce@email.com'),
                        validator: (v) => (v == null || !v.contains('@'))
                            ? 'E-mail inválido'
                            : null,
                      ),
                      const SizedBox(height: 22),
                      const _Campo(label: 'Senha'),
                      TextFormField(
                        controller: _senha,
                        obscureText: true,
                        decoration:
                            const InputDecoration(hintText: 'Sua senha'),
                        validator: (v) => (v == null || v.length < 6)
                            ? 'Mínimo 6 caracteres'
                            : null,
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _recuperarSenha,
                          child: const Text('Esqueci a senha'),
                        ),
                      ),
                      if (_erro != null) ...[
                        const SizedBox(height: 6),
                        Text(_erro!,
                            style: const TextStyle(
                                color: PandaColors.vermelhoAcento)),
                      ],
                      const SizedBox(height: 22),
                      ElevatedButton(
                        onPressed: _loading ? null : _entrar,
                        child: _loading
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Entrar'),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Não tem conta?',
                              style: TextStyle(color: PandaColors.cinzaTexto)),
                          TextButton(
                            onPressed: () => context.go('/signup'),
                            child: const Text('Cadastre-se'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
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
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(label,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: PandaColors.cinzaTexto)),
    );
  }
}
