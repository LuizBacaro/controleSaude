import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_spacing.dart';
import '../data/doctor_plan_repository.dart';
import '../data/play_doctor_plan_billing.dart';

/// Consultório fechado até a assinatura estar ativa.
class DoctorPlanLockedPage extends ConsumerStatefulWidget {
  const DoctorPlanLockedPage({super.key, required this.onLogout});

  final Future<void> Function() onLogout;

  @override
  ConsumerState<DoctorPlanLockedPage> createState() =>
      _DoctorPlanLockedPageState();
}

class _DoctorPlanLockedPageState extends ConsumerState<DoctorPlanLockedPage> {
  var _busy = false;
  String? _error;

  Future<void> _subscribe() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (kIsWeb) {
        if (!mounted) return;
        context.go('/plano');
        return;
      }
      final billing = PlayDoctorPlanBilling(
        ref.read(doctorPlanRepositoryProvider).confirmPlayPurchase,
      );
      await billing.buy();
      ref.invalidate(doctorPlanActiveProvider);
    } catch (error) {
      if (mounted) setState(() => _error = AppException.messageOf(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Consultório'),
        actions: [
          IconButton(
            tooltip: 'Sair',
            onPressed: _busy ? null : widget.onLogout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Text('Assinatura do consultório', style: text.headlineSmall),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'O consultório, com a lista de pacientes e a evolução deles, '
                  'faz parte da assinatura do médico. Os seus próprios exames '
                  'continuam gratuitos.',
                  style: text.bodyLarge,
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
                  onPressed: _busy ? null : _subscribe,
                  child: _busy
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          kIsWeb
                              ? 'Assinar no site'
                              : 'Assinar pelo Google Play',
                        ),
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton(
                  onPressed: _busy ? null : () => context.go('/app'),
                  child: const Text('Meus exames'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
