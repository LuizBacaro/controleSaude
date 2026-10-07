import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_spacing.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  var _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).login(
            email: _email.text,
            password: _password.text,
          );
      ref.read(authRevisionProvider.notifier).bump();
      if (!mounted) return;
      final hasExams = ref.read(examsRepositoryProvider).hasReports;
      context.go(hasExams ? '/app' : '/importar?onboarding=1');
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Entrar')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: const InputDecoration(labelText: 'E-mail'),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Senha'),
            onSubmitted: (_) => _submit(),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Entrar'),
          ),
          TextButton(
            onPressed: () => context.push('/criar-conta'),
            child: const Text('Criar conta'),
          ),
        ],
      ),
    );
  }
}
