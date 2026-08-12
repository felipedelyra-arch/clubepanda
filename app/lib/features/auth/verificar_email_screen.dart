import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/services.dart';
import '../../core/theme/colors.dart';

/// Porta de entrada de quem se cadastrou com e-mail e senha e ainda não
/// confirmou o endereço.
///
/// O router segura aqui enquanto `emailVerified` for falso. Quem entra pelo
/// Google nunca vê esta tela.
class VerificarEmailScreen extends ConsumerStatefulWidget {
  const VerificarEmailScreen({super.key});

  @override
  ConsumerState<VerificarEmailScreen> createState() =>
      _VerificarEmailScreenState();
}

class _VerificarEmailScreenState extends ConsumerState<VerificarEmailScreen> {
  static const _bg = Color(0xFF14110E);
  static const _card = Color(0xFF211C16);
  static const _borda = Color(0x12FFFFFF);

  bool _enviando = false;
  bool _conferindo = false;
  String? _aviso;
  Timer? _relogio;

  /// Segundos que faltam pra poder reenviar. O Firebase limita reenvio por IP;
  /// sem essa trava o sócio clica cinco vezes, toma `too-many-requests` e fica
  /// sem conseguir reenviar por muito mais tempo.
  int _espera = 0;

  @override
  void initState() {
    super.initState();
    // Confere sozinho a cada 5s: o sócio confirma no e-mail (às vezes em outro
    // aparelho) e volta pro app esperando estar dentro, sem apertar nada.
    _relogio = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _conferir(silencioso: true),
    );
  }

  @override
  void dispose() {
    _relogio?.cancel();
    super.dispose();
  }

  Future<void> _reenviar() async {
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null || _espera > 0) return;
    setState(() {
      _enviando = true;
      _aviso = null;
    });
    try {
      await user.sendEmailVerification();
      if (!mounted) return;
      setState(() {
        _aviso = 'Enviamos de novo. Olhe também o lixo eletrônico.';
        _espera = 60;
      });
      _contarRegressiva();
    } catch (_) {
      if (!mounted) return;
      setState(() => _aviso = 'Não deu pra enviar agora. Tente em um minuto.');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  void _contarRegressiva() {
    Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || _espera <= 0) {
        t.cancel();
        return;
      }
      setState(() => _espera--);
    });
  }

  /// Relê o usuário no Firebase. `authStateChanges` **não** dispara depois de
  /// `reload()`, então o provider é invalidado na mão pra o router reavaliar o
  /// desvio e soltar a pessoa pra dentro.
  Future<void> _conferir({bool silencioso = false}) async {
    if (_conferindo) return;
    _conferindo = true;
    try {
      final auth = ref.read(firebaseAuthProvider);
      await auth.currentUser?.reload();
      if (auth.currentUser?.emailVerified ?? false) {
        ref.invalidate(authStateProvider);
        return;
      }
      if (!silencioso && mounted) {
        setState(() => _aviso = 'Ainda não confirmado. Abra o link do e-mail.');
      }
    } catch (_) {
      // Offline ou token velho: o timer tenta de novo em 5s.
    } finally {
      _conferindo = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(firebaseAuthProvider).currentUser?.email ?? '';

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.mark_email_unread_outlined,
                    size: 64, color: PandaColors.laranja),
                const SizedBox(height: 20),
                const Text(
                  'Confirme seu e-mail',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  email.isEmpty
                      ? 'Mandamos um link de confirmação pro seu e-mail.'
                      : 'Mandamos um link de confirmação para\n$email',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: PandaColors.cinzaTexto,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Abra o link e volte aqui. A tela libera sozinha.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: PandaColors.cinzaTexto, fontSize: 13),
                ),
                if (_aviso != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _borda),
                    ),
                    child: Text(
                      _aviso!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13.5),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _conferindo ? null : () => _conferir(),
                  style: FilledButton.styleFrom(
                    backgroundColor: PandaColors.laranja,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Já confirmei'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: (_enviando || _espera > 0) ? null : _reenviar,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: _borda),
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(_espera > 0
                      ? 'Reenviar em ${_espera}s'
                      : 'Reenviar e-mail'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => ref.read(firebaseAuthProvider).signOut(),
                  style: TextButton.styleFrom(
                      foregroundColor: PandaColors.cinzaTexto),
                  child: const Text('Sair e usar outro e-mail'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
