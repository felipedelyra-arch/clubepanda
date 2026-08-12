import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/services.dart';
import '../../core/demo.dart';
import '../../core/theme/colors.dart';
import 'auth_perfil.dart';
import 'botao_social.dart';

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
  bool _mostrarSenha = false;
  String? _erro;

  // Paleta local escura (a tela de auth é sempre "premium dark",
  // independente do tema claro/escuro do resto do app).
  static const _bg = Color(0xFF14110E); // fundo quase preto quente
  static const _card = Color(0xFF211C16); // superfície dos campos
  static const _borda = Color(0x12FFFFFF); // hairline sutil sobre escuro

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

  /// Login social. Usa os provedores nativos do firebase_auth (sem pacote
  /// extra). Requer os provedores habilitados no console + config de
  /// plataforma (client id no web/iOS, "Sign in with Apple" no Xcode).
  Future<void> _entrarComProvedor(Future<void> Function() fluxo) async {
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
      await fluxo();
    } on FirebaseAuthException catch (e) {
      setState(() => _erro = _mensagemErro(e.code));
    } catch (_) {
      setState(() => _erro = 'Não foi possível entrar. Tente de novo.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _entrarGoogle() => _entrarComProvedor(() => entrarComGoogle(ref));

  Future<void> _entrarApple() => _entrarComProvedor(() => entrarComApple(ref));

  Future<void> _recuperarSenha() async {
    if (_email.text.trim().isEmpty) {
      setState(() => _erro = 'Digite seu e-mail para recuperar a senha.');
      return;
    }
    // Sem esse desvio o demo chamava o Firebase, que nem foi inicializado.
    if (kDemo) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Recuperação de senha desativada no modo demo')),
      );
      return;
    }
    setState(() => _erro = null);
    try {
      await ref
          .read(firebaseAuthProvider)
          .sendPasswordResetEmail(email: _email.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('E-mail de recuperação enviado.')),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _erro = e.code == 'invalid-email'
          ? 'E-mail inválido.'
          : 'Não deu pra enviar o e-mail agora. Tente de novo.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _erro = 'Não deu pra enviar o e-mail agora. Tente de novo.');
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
    final size = MediaQuery.of(context).size;
    final heroH = (size.height * 0.40).clamp(230.0, 340.0);

    // IMPORTANTE (bug de render corrigido):
    // A versão anterior usava um Stack com a FOLHA DE LOGIN opaca (contendo o
    // form/scroll) posicionada por cima da Image do hero. Nessa composição o
    // CanvasKit (web) rasterizava a foto e a logo, mas NÃO pintava o form
    // (título, campos, botão) — apesar do layout estar correto.
    // Solução: tudo em FLUXO NORMAL dentro de um único SingleChildScrollView
    // (mesmo padrão da tela de signup, que sempre pintou). O overlap da logo
    // sobre a foto é feito num Stack pequeno que contém só foto + logo — nunca
    // por cima do form.
    return Scaffold(
      backgroundColor: _bg,
      resizeToAvoidBottomInset: true,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ---------- HERO: foto + logo na emenda ----------
            // Container com fundo _bg: a foto é pintada POR CIMA e dissolve no
            // mesmo _bg, sem nenhuma linha/borda entre retângulos adjacentes.
            Container(
              height: heroH + 56, // espaço extra pra logo descer sobre a emenda
              color: _bg,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Foto do prato preenche TODO o container (sem SizedBox
                  // interno em heroH) — não há borda entre foto e fundo.
                  Positioned.fill(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Bloco laranja em ângulo (eco da referência).
                        Positioned(
                          top: -60,
                          right: -70,
                          child: Transform.rotate(
                            angle: -0.35,
                            child: Container(
                              width: 230,
                              height: 230,
                              decoration: BoxDecoration(
                                color: PandaColors.laranja,
                                borderRadius: BorderRadius.circular(56),
                              ),
                            ),
                          ),
                        ),
                        Image.asset(
                          'assets/images/login_bg.jpg',
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              Container(color: PandaColors.laranja),
                        ),
                        // Escurecimento + fusão total com o fundo escuro.
                        // Chega a _bg OPACO antes da base, então a foto dissolve
                        // no fundo sem nenhuma linha/emenda visível.
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                _bg.withValues(alpha: 0.45),
                                _bg.withValues(alpha: 0.0),
                                _bg.withValues(alpha: 0.5),
                                _bg,
                                _bg,
                              ],
                              stops: const [0, 0.25, 0.58, 0.82, 1],
                            ),
                          ),
                        ),
                        // Brilho laranja suave (glow de marca).
                        Positioned(
                          top: 30,
                          right: 24,
                          child: Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  PandaColors.laranja.withValues(alpha: 0.35),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Logo circular sobre a emenda — sem borda, a imagem
                  // preenche todo o círculo (BoxFit.cover recortado).
                  Positioned(
                    top: heroH - 52,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        width: 104,
                        height: 104,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.5),
                              blurRadius: 24,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/logo/panda_logo.png',
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              Container(color: PandaColors.laranja),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ---------- FORM (fluxo normal, pinta sempre) ----------
            Padding(
              padding: const EdgeInsets.fromLTRB(26, 6, 26, 32),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(
                      child: Text(
                        'Que bom te ver!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Center(
                      child: Text(
                        'Entre e aproveite suas vantagens de sócio.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: PandaColors.cinzaTexto,
                          fontSize: 14.5,
                          height: 1.3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),

                    // E-mail
                    _softField(
                      controller: _email,
                      hint: 'voce@email.com',
                      icon: Icons.alternate_email_rounded,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) => (v == null || !v.contains('@'))
                          ? 'E-mail inválido'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    // Senha
                    _softField(
                      controller: _senha,
                      hint: 'Sua senha',
                      icon: Icons.lock_outline_rounded,
                      obscure: !_mostrarSenha,
                      validator: (v) => (v == null || v.length < 6)
                          ? 'Mínimo 6 caracteres'
                          : null,
                      suffix: IconButton(
                        onPressed: () =>
                            setState(() => _mostrarSenha = !_mostrarSenha),
                        icon: Icon(
                          _mostrarSenha
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          color: PandaColors.cinzaTexto,
                          size: 20,
                        ),
                      ),
                    ),

                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _recuperarSenha,
                        style: TextButton.styleFrom(
                          foregroundColor: PandaColors.laranja,
                          padding: const EdgeInsets.symmetric(
                              vertical: 8, horizontal: 4),
                        ),
                        child: const Text('Esqueci a senha'),
                      ),
                    ),

                    if (_erro != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.error_outline_rounded,
                              color: PandaColors.vermelhoAcento, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _erro!,
                              style: const TextStyle(
                                color: PandaColors.vermelhoAcento,
                                fontSize: 13.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 22),

                    // CTA com gradiente + brilho laranja.
                    _botaoEntrar(),

                    const SizedBox(height: 20),
                    _divisorOu(),
                    const SizedBox(height: 16),
                    BotaoSocial(
                      onTap: _loading ? null : _entrarGoogle,
                      icone: const GoogleG(),
                      texto: 'Continuar com Google',
                      corFundo: _card,
                      corBorda: _borda,
                    ),
                    // Apple exige o botão em plataformas Apple (e web Safari).
                    if (defaultTargetPlatform == TargetPlatform.iOS ||
                        defaultTargetPlatform == TargetPlatform.macOS) ...[
                      const SizedBox(height: 12),
                      BotaoSocial(
                        onTap: _loading ? null : _entrarApple,
                        icone: const Icon(Icons.apple_rounded,
                            color: Colors.white, size: 24),
                        texto: 'Continuar com Apple',
                        corFundo: _card,
                        corBorda: _borda,
                      ),
                    ],

                    const SizedBox(height: 22),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Não tem conta?',
                          style: TextStyle(color: PandaColors.cinzaTexto),
                        ),
                        TextButton(
                          onPressed: () => context.go('/signup'),
                          style: TextButton.styleFrom(
                            foregroundColor: PandaColors.laranja,
                          ),
                          child: const Text('Cadastre-se'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Campo de texto com visual neumórfico escuro (fundo elevado + hairline).
  Widget _softField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscure = false,
    String? Function(String?)? validator,
    Widget? suffix,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borda),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscure,
        style: const TextStyle(color: Colors.white, fontSize: 15),
        cursorColor: PandaColors.laranja,
        validator: validator,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: PandaColors.cinzaTexto),
          prefixIcon: Icon(icon, color: PandaColors.cinzaTexto, size: 20),
          suffixIcon: suffix,
          filled: false,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 4, vertical: 18),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: PandaColors.laranja, width: 1.5),
          ),
          errorStyle: const TextStyle(color: PandaColors.vermelhoAcento),
        ),
      ),
    );
  }

  Widget _divisorOu() {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: _borda)),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text('ou',
              style: TextStyle(color: PandaColors.cinzaTexto, fontSize: 13)),
        ),
        Expanded(child: Container(height: 1, color: _borda)),
      ],
    );
  }

  Widget _botaoEntrar() {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: PandaColors.laranja.withValues(alpha: 0.4),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _loading ? null : _entrar,
          child: Ink(
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                colors: [PandaColors.laranja, PandaColors.laranjaEscuro],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Center(
              child: _loading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text(
                      'Entrar',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
