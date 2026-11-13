import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../auth/presentation/register_page.dart';
import '../../care/data/granted_charts.dart';
import '../data/doctor_plan_repository.dart';

/// Página do plano no site. No aplicativo da Play a compra não passa por aqui.
class DoctorPlanPage extends ConsumerStatefulWidget {
  const DoctorPlanPage({super.key, this.paid = false});

  final bool paid;

  @override
  ConsumerState<DoctorPlanPage> createState() => _DoctorPlanPageState();
}

class _DoctorPlanPageState extends ConsumerState<DoctorPlanPage> {
  var _busy = false;
  String? _error;

  Future<void> _checkout() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final url = await ref
          .read(doctorPlanRepositoryProvider)
          .startWebCheckout();
      final opened = await launchUrl(
        Uri.parse(url),
        webOnlyWindowName: '_self',
      );
      if (!opened && mounted) {
        setState(() => _error = 'Não foi possível abrir o pagamento.');
      }
    } catch (error) {
      if (mounted) setState(() => _error = AppException.messageOf(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _logout() async {
    await ref.read(authRepositoryProvider).logout();
    ref.read(examsRepositoryProvider).clear();
    ref.read(grantedChartsProvider.notifier).clear();
    ref.read(shellEpochProvider.notifier).bump();
    ref.read(authRevisionProvider.notifier).bump();
    ref.read(examsRevisionProvider.notifier).bump();
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    if (user != null && user.isDoctor) {
      return _AccountStep(
        title: 'Assinatura do consultório',
        body: widget.paid
            ? 'Se o pagamento foi concluído, o consultório libera em instantes.'
            : 'A conta de médico já existe. O consultório abre quando a assinatura está ativa.',
        busy: _busy,
        error: _error,
        primary: 'Continuar para o pagamento',
        onPrimary: _checkout,
        secondary: 'Ir para o consultório',
        onSecondary: () {
          ref.invalidate(doctorPlanActiveProvider);
          context.go('/consultorio');
        },
      );
    }
    if (user != null) {
      return _AccountStep(
        title: 'Esta conta é de paciente',
        body:
            'Paciente usa o ExameFácil de graça. O plano do consultório pede uma conta de médico, com outro e-mail.',
        busy: false,
        error: null,
        primary: 'Sair e criar a conta de médico',
        onPrimary: _logout,
        secondary: 'Voltar aos meus exames',
        onSecondary: () => context.go('/app'),
      );
    }
    return const RegisterPage(planCheckout: true);
  }
}

class _AccountStep extends StatelessWidget {
  const _AccountStep({
    required this.title,
    required this.body,
    required this.busy,
    required this.error,
    required this.primary,
    required this.onPrimary,
    required this.secondary,
    required this.onSecondary,
  });

  final String title;
  final String body;
  final bool busy;
  final String? error;
  final String primary;
  final VoidCallback onPrimary;
  final String secondary;
  final VoidCallback onSecondary;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Plano do médico')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text(title, style: text.headlineSmall),
              const SizedBox(height: AppSpacing.md),
              Text(body, style: text.bodyLarge),
              if (error != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: busy ? null : onPrimary,
                child: Text(busy ? 'Abrindo pagamento…' : primary),
              ),
              TextButton(onPressed: busy ? null : onSecondary, child: Text(secondary)),
            ],
          ),
        ),
      ),
    );
  }
}
