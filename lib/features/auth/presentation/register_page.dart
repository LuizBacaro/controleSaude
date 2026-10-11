import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_spacing.dart';
import 'widgets/health_fields.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _sex;
  DateTime? _birthDate;
  var _loading = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_birthDate == null || _sex == null) {
      setState(
        () => _error = 'Informe data de nascimento e sexo para avaliar os exames.',
      );
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .register(
            email: _email.text,
            password: _password.text,
            displayName: _name.text,
            sex: _sex,
            birthDate: _birthDate,
          );
      ref.read(authRevisionProvider.notifier).bump();
      await ref.read(examsRepositoryProvider).load();
      ref.read(examsRevisionProvider.notifier).bump();
      if (!mounted) return;
      // Pós-cadastro: pedir o PDF do exame.
      context.go('/importar?onboarding=1');
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Criar conta')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text(
            'A conta fica salva. Se reinstalar o app, entre de novo com o mesmo e-mail e senha.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Nome'),
          ),
          const SizedBox(height: AppSpacing.md),
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
            decoration: const InputDecoration(
              labelText: 'Senha',
              helperText: 'Mínimo de 6 caracteres',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          HealthFields(
            birthDate: _birthDate,
            sex: _sex,
            onBirthDate: (date) => setState(() => _birthDate = date),
            onSex: (value) => setState(() => _sex = value),
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
                : const Text('Continuar'),
          ),
        ],
      ),
    );
  }
}
