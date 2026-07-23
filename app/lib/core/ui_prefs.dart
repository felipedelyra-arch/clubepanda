import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_prefs.dart';

const double kMinTextScale = 1.0;
const double kMaxTextScale = 1.4;
const double kStepTextScale = 0.15;

const String _kTextScaleKey = 'text_scale';

/// Fator de escala do texto (acessibilidade — "A+ / A−").
/// Persistido em disco via shared_preferences (lido no boot): mantém a escolha
/// entre sessões. Aplicado globalmente no MaterialApp (main.dart) via
/// MediaQuery.textScaler.
class TextScaleNotifier extends Notifier<double> {
  @override
  double build() {
    final saved = ref.watch(sharedPreferencesProvider).getDouble(_kTextScaleKey);
    return (saved ?? 1.0).clamp(kMinTextScale, kMaxTextScale);
  }

  /// Define a escala (com clamp) e persiste.
  Future<void> set(double value) async {
    final novo = double.parse(
        value.clamp(kMinTextScale, kMaxTextScale).toStringAsFixed(2));
    state = novo;
    await ref.read(sharedPreferencesProvider).setDouble(_kTextScaleKey, novo);
  }

  /// Ajusta de forma relativa (usado pelos botões A− / A+).
  Future<void> ajustar(double delta) => set(state + delta);
}

final textScaleProvider =
    NotifierProvider<TextScaleNotifier, double>(TextScaleNotifier.new);

/// Rótulo amigável pro nível atual.
String rotuloTamanho(double s) {
  if (s <= 1.0) return 'Normal';
  if (s <= 1.15) return 'Médio';
  if (s <= 1.3) return 'Grande';
  return 'Máximo';
}
