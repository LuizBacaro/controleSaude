import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'bootstrap.dart';
import 'core/theme/app_colors.dart';

/// Pinta uma tela leve e só então fala com o Supabase.
///
/// Antes, [main] esperava a rede para chamar `runApp`. No celular isso
/// deixava a janela preta por vários segundos e o sistema tratava o app
/// como travado.
class BootGate extends StatefulWidget {
  const BootGate({super.key});

  @override
  State<BootGate> createState() => _BootGateState();
}

class _BootGateState extends State<BootGate> {
  var _ready = false;
  var _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  Future<void> _open() async {
    if (mounted) setState(() => _failed = false);
    try {
      await openServices().timeout(const Duration(seconds: 15));
    } catch (_) {
      if (mounted) setState(() => _failed = true);
      return;
    }
    if (!mounted) return;
    await loadSession(ProviderScope.containerOf(context, listen: false))
        .timeout(const Duration(seconds: 12), onTimeout: () {});
    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return const ControleSaudeApp();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/brand/logo.png',
                    width: 180,
                    cacheWidth: 540,
                    filterQuality: FilterQuality.medium,
                  ),
                  const SizedBox(height: 28),
                  if (_failed) ...[
                    const Text(
                      'Não consegui conectar. Os laudos continuam na conta; tente de novo.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _open,
                      child: const Text('Tentar de novo'),
                    ),
                  ] else
                    const CircularProgressIndicator(color: AppColors.teal),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
