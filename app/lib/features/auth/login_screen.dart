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
  final _email = TextEditingController();
  final _senha = TextEditingController();
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
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'E-mail',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (v) =>
                        (v == null || !v.contains('@')) ? 'E-mail inválido' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _senha,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Senha',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
