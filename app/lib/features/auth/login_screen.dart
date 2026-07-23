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
    // Demo: simula login e entra direto.
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
      // redirect do router leva pra /home
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
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  const Center(child: PandaLogo(size: 132, showWordmark: false)),
                  const SizedBox(height: 28),
                  Center(
                    child: Text('Clube Panda',
                        style: Theme.of(context).textTheme.headlineMedium),
                  ),
                  const SizedBox(height: 6),
                  const Center(
                    child: Text(
                      'Seu japa favorito, com vantagens de sócio.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: PandaColors.cinzaTexto, fontSize: 15),
                    ),
                  ),
                  const SizedBox(height: 36),
                  const _Campo(label: 'E-mail'),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(hintText: 'voce@email.com'),
                    validator: (v) =>
                        (v == null || !v.contains('@')) ? 'E-mail inválido' : null,
                  ),
                  const SizedBox(height: 18),
                  const _Campo(label: 'Senha'),
                  TextFormField(
                    controller: _senha,
                    obscureText: true,
                    decoration:
                        const InputDecoration(hintText: 'Sua senha'),
                    validator: (v) =>
                        (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null,
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _recuperarSenha,
                      child: const Text('Esqueci a senha'),
                    ),
                  ),
                  if (_erro != null) ...[
                    const SizedBox(height: 8),
                    Text(_erro!,
                        style: const TextStyle(color: Color(0xFFE23B2E))),
                  ],
                  const SizedBox(height: 16),
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
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => context.go('/signup'),
                    child: const Text('Não tem conta? Cadastre-se'),
                  ),
                  if (kDemo) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: PandaColors.laranjaSuave,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Modo demonstração — use qualquer e-mail e senha (6+ caracteres) e toque em Entrar.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 12.5,
                            height: 1.4,
                            color: PandaColors.laranjaEscuro),
                      ),
                    ),
                  ],
                ],
              ),
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
