import 'package:flutter/material.dart';

import 'boot_gate.dart';

/// A primeira tela entra antes de qualquer espera.
///
/// Esperar o disco ou a rede aqui segura a abertura do Android (ícone no
/// branco) e a análise da Play trata o app como se não abrisse.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BootGate());
}
