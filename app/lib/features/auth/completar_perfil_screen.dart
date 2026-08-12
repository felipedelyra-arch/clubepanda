import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/services.dart';
import '../../core/theme/colors.dart';
import 'auth_perfil.dart';

/// Completa o cadastro de quem entrou pelo Google.
///
/// O Google entrega nome, e-mail e foto — não entrega telefone nem data de
/// nascimento. Os dois fazem falta: o telefone é como o salão acha o sócio na
/// hora do resgate, e o nascimento alimenta o aviso de aniversário.
///
/// O router só desvia pra cá quando o doc do perfil **já chegou** do Firestore
/// e está mesmo faltando campo — nunca durante o carregamento.
class CompletarPerfilScreen extends ConsumerStatefulWidget {
  const CompletarPerfilScreen({super.key});

  @override
  ConsumerState<CompletarPerfilScreen> createState() =>
      _CompletarPerfilScreenState();
}

class _CompletarPerfilScreenState
    extends ConsumerState<CompletarPerfilScreen> {
  static const _bg = Color(0xFF14110E);
  static const _card = Color(0xFF211C16);
  static const _borda = Color(0x12FFFFFF);

  final _formKey = GlobalKey<FormState>();
  final _telefone = TextEditingController();
  DateTime? _nascimento;
  bool _salvando = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    // Se o doc já tinha telefone (veio da function, por exemplo), não faz o
    // sócio digitar de novo.
    final atual = ref.read(currentUserProvider).value;
    if (atual != null) {
      _telefone.text = atual.telefone;
      _nascimento = atual.nascimento;
    }
  }

  @override
  void dispose() {
    _telefone.dispose();
    super.dispose();
  }

  Future<void> _escolherData() async {
    final agora = DateTime.now();
    final escolhida = await showDatePicker(
      context: context,
      initialDate:
          _nascimento ?? DateTime(agora.year - 25, agora.month, agora.day),
      firstDate: DateTime(1920),
      lastDate: agora,
      locale: const Locale('pt', 'BR'),
      helpText: 'Sua data de nascimento',
    );
    if (escolhida != null) setState(() => _nascimento = escolhida);
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_nascimento == null) {
      setState(() => _erro = 'Escolha sua data de nascimento.');
      return;
    }
    final uid = ref.read(firebaseAuthProvider).currentUser?.uid;
    if (uid == null) return;

    setState(() {
      _salvando = true;
      _erro = null;
    });
    try {
      await ref.read(firestoreProvider).doc('users/$uid').set({
        'telefone': _telefone.text.trim(),
        'nascimento': Timestamp.fromDate(_nascimento!),
      }, SetOptions(merge: true));
      // Sem navegação na mão: o doc muda, `perfilCompletoProvider` vira true e
      // o router solta pra /home sozinho.
    } catch (_) {
      if (mounted) {
        setState(() => _erro = 'Não deu pra salvar agora. Tente de novo.');
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nome = ref.watch(currentUserProvider).value?.nome ?? '';
    final primeiro = nome.split(' ').first;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                Text(
                  primeiro.isEmpty ? 'Quase lá' : 'Quase lá, $primeiro',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Faltam dois dados pra sua carteirinha ficar completa.',
                  style: TextStyle(
                    color: PandaColors.cinzaTexto,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 28),
                TextFormField(
                  controller: _telefone,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: Colors.white),
                  decoration: _decoracao(
                    'Telefone com DDD',
                    Icons.phone_outlined,
                  ),
                  validator: (v) {
                    final so = (v ?? '').replaceAll(RegExp(r'\D'), '');
                    if (so.length < 10) return 'Telefone incompleto.';
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                const Text(
                  'É como o restaurante te encontra na hora do resgate.',
                  style: TextStyle(color: PandaColors.cinzaTexto, fontSize: 12),
                ),
                const SizedBox(height: 20),
                InkWell(
                  onTap: _escolherData,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 18),
                    decoration: BoxDecoration(
                      color: _card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _borda),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.cake_outlined,
                            color: PandaColors.cinzaTexto),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _nascimento == null
                                ? 'Data de nascimento'
                                : '${_nascimento!.day.toString().padLeft(2, '0')}/'
                                    '${_nascimento!.month.toString().padLeft(2, '0')}/'
                                    '${_nascimento!.year}',
                            style: TextStyle(
                              color: _nascimento == null
                                  ? PandaColors.cinzaTexto
                                  : Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Serve pro mimo de aniversário do clube.',
                  style: TextStyle(color: PandaColors.cinzaTexto, fontSize: 12),
                ),
                if (_erro != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _erro!,
                    style: const TextStyle(
                        color: PandaColors.vermelhoAcento, fontSize: 13.5),
                  ),
                ],
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: _salvando ? null : _salvar,
                  style: FilledButton.styleFrom(
                    backgroundColor: PandaColors.laranja,
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _salvando
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Concluir cadastro'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => sair(ref),
                  style: TextButton.styleFrom(
                      foregroundColor: PandaColors.cinzaTexto),
                  child: const Text('Sair'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _decoracao(String hint, IconData icone) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: PandaColors.cinzaTexto),
        prefixIcon: Icon(icone, color: PandaColors.cinzaTexto),
        filled: true,
        fillColor: _card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _borda),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _borda),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: PandaColors.laranja),
        ),
      );
}
