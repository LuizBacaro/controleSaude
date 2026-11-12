import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/providers.dart';
import '../../../core/router/home_location.dart';
import '../../../core/theme/app_spacing.dart';

class ResetPasswordPage extends ConsumerStatefulWidget {
  const ResetPasswordPage({
    super.key,
    this.canSetPassword = true,
    this.initialError,
  });

  final bool canSetPassword;
  final String? initialError;

  @override
  ConsumerState<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends ConsumerState<ResetPasswordPage> {
  final _password = TextEditingController();
  final _passwordConfirm = TextEditingController();
  var _loading = false;
  var _showPassword = false;
  var _showPasswordConfirm = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _error = widget.initialError;
  }

  @override
  void dispose() {
    _password.dispose();
    _passwordConfirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_password.text.length < 6) {
      setState(() => _error = 'A senha precisa ter pelo menos 6 caracteres.');
      return;
    }
    if (_password.text != _passwordConfirm.text) {
      setState(
        () => _error =
            'As senhas não são iguais. Digite a mesma nos dois campos.',
      );
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).updatePassword(_password.text);
      await ref.read(examsRepositoryProvider).load();
      ref.read(authRevisionProvider.notifier).bump();
      ref.read(examsRevisionProvider.notifier).bump();
      if (!mounted) return;
      TextInput.finishAutofillContext();
      final user = ref.read(authRepositoryProvider).currentUser;
      final hasExams = ref.read(examsRepositoryProvider).hasReports;
      context.go(
        homeLocation(isDoctor: user?.isDoctor ?? false, hasExams: hasExams),
      );
    } catch (error) {
      setState(() => _error = AppException.messageOf(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _askAgain() {
    ref.read(authRepositoryProvider).clearRecoveryError();
    context.go('/esqueci-senha');
  }

  @override
  Widget build(BuildContext context) {
    final errorStyle = TextStyle(color: Theme.of(context).colorScheme.error);
    return Scaffold(
      appBar: AppBar(title: const Text('Nova senha')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            if (!widget.canSetPassword) ...[
              Text(
                _error ??
                    'Abra o link no mesmo aparelho em que pediu a nova senha.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: _askAgain,
                child: const Text('Pedir outro link'),
              ),
            ] else ...[
              Text(
                'Escolha uma senha nova, com pelo menos 6 caracteres.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _password,
                obscureText: !_showPassword,
                autocorrect: false,
                smartDashesType: SmartDashesType.disabled,
                smartQuotesType: SmartQuotesType.disabled,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Nova senha',
                  suffixIcon: IconButton(
                    tooltip: _showPassword ? 'Esconder senha' : 'Mostrar senha',
                    onPressed: () =>
                        setState(() => _showPassword = !_showPassword),
                    icon: Icon(
                      _showPassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _passwordConfirm,
                obscureText: !_showPasswordConfirm,
                autocorrect: false,
                smartDashesType: SmartDashesType.disabled,
                smartQuotesType: SmartQuotesType.disabled,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: 'Confirmar senha',
                  suffixIcon: IconButton(
                    tooltip: _showPasswordConfirm
                        ? 'Esconder senha'
                        : 'Mostrar senha',
                    onPressed: () => setState(
                      () => _showPasswordConfirm = !_showPasswordConfirm,
                    ),
                    icon: Icon(
                      _showPasswordConfirm
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                ),
                onSubmitted: (_) => _submit(),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(_error!, style: errorStyle),
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
                    : const Text('Salvar senha'),
              ),
              TextButton(
                onPressed: _loading
                    ? null
                    : () async {
                        await ref.read(authRepositoryProvider).logout();
                        ref.read(authRevisionProvider.notifier).bump();
                        if (!context.mounted) return;
                        context.go('/');
                      },
                child: const Text('Cancelar'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
