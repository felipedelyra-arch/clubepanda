import 'package:flutter_riverpod/legacy.dart';

/// Fator de escala do texto (acessibilidade — "A+ / A−").
/// Em memória: vale enquanto o app está aberto. Aplicado globalmente no
/// MaterialApp (main.dart) via MediaQuery.textScaler.
final textScaleProvider = StateProvider<double>((_) => 1.0);

const double kMinTextScale = 1.0;
const double kMaxTextScale = 1.4;
const double kStepTextScale = 0.15;

/// Rótulo amigável pro nível atual.
String rotuloTamanho(double s) {
  if (s <= 1.0) return 'Normal';
  if (s <= 1.15) return 'Médio';
  if (s <= 1.3) return 'Grande';
  return 'Máximo';
}
