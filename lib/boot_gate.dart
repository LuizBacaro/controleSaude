import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'bootstrap.dart';
import 'core/providers.dart';
import 'core/theme/app_colors.dart';

/// Pinta uma tela leve e só então fala com o disco e o Supabase.
///
/// Antes, [main] esperava a rede para chamar `runApp`. No celular isso
/// deixava a janela preta por vários segundos e o sistema tratava o app
/// como travado. A abertura do Android 12 fica no ícone branco enquanto
/// o primeiro quadro não sai; por isso a espera começa depois desse quadro.
class BootGate extends StatefulWidget {
  const BootGate({super.key});

  @override
  State<BootGate> createState() => _BootGateState();
}

class _BootGateState extends State<BootGate> {
  ProviderContainer? _container;
  var _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  @override
  void dispose() {
    _container?.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    if (mounted) setState(() => _failed = false);
    ProviderContainer? created;
    try {
      final prefs = await SharedPreferences.getInstance().timeout(
        const Duration(seconds: 8),
      );
      created = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      await openServices().timeout(const Duration(seconds: 15));
      await loadSession(created).timeout(
        const Duration(seconds: 12),
        onTimeout: () {},
      );
      if (!mounted) {
        created.dispose();
        return;
      }
      final previous = _container;
      setState(() {
        _container = created;
        _failed = false;
      });
      if (previous != null && previous != created) previous.dispose();
    } catch (_) {
      created?.dispose();
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final container = _container;
    if (container != null && !_failed) {
      return UncontrolledProviderScope(
        container: container,
        child: const ControleSaudeApp(),
      );
    }
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
