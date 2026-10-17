import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../care/data/granted_charts.dart';
import '../data/care_repository.dart';
import '../domain/care_grant.dart';

class OfficePage extends ConsumerStatefulWidget {
  const OfficePage({super.key});

  @override
  ConsumerState<OfficePage> createState() => _OfficePageState();
}

class _OfficePageState extends ConsumerState<OfficePage> {
  var _loading = true;
  String? _error;
  String? _busyId;
  List<CareGrant> _grants = const [];

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final grants = await ref.read(careRepositoryProvider).grantsAsDoctor();
      if (!mounted) return;
      setState(() {
        _grants = grants
            .where((grant) => grant.isPending || grant.isAccepted)
            .toList();
      });
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _error = error.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _respond(CareGrant grant, {required bool accept}) async {
    setState(() => _busyId = grant.id);
    try {
      final care = ref.read(careRepositoryProvider);
      if (accept) {
        await care.accept(grant.id);
      } else {
        await care.decline(grant.id);
      }
      await _load();
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _busyId = null);
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

  void _open(CareGrant grant) {
    final uri = Uri(
      path: '/consultorio/paciente/${grant.patientId}',
      queryParameters: {'nome': grant.patientName},
    );
    context.push(uri.toString());
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final user = ref.watch(currentUserProvider);
    final pending = _grants.where((grant) => grant.isPending).toList();
    final accepted = _grants.where((grant) => grant.isAccepted).toList();
    final wide = MediaQuery.sizeOf(context).width >= 840;

    final invites = _InviteList(
      pending: pending,
      busyId: _busyId,
      onAccept: (grant) => _respond(grant, accept: true),
      onDecline: (grant) => _respond(grant, accept: false),
    );
    final patients = _PatientList(accepted: accepted, onOpen: _open);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Consultório'),
        actions: [
          IconButton(
            tooltip: 'Sair',
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  Text(
                    'Olá, ${user?.displayName ?? 'médico'}',
                    style: text.headlineSmall,
                  ),
                  if (user?.crmLabel != null)
                    Text(user!.crmLabel!, style: text.bodyMedium),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Você só vê quem enviou um convite. Sem o aceite, o exame não abre.',
                    style: text.bodyMedium,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: invites),
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(child: patients),
                      ],
                    )
                  else ...[
                    invites,
                    const SizedBox(height: AppSpacing.lg),
                    patients,
                  ],
                ],
              ),
            ),
    );
  }
}

class _InviteList extends StatelessWidget {
  const _InviteList({
    required this.pending,
    required this.busyId,
    required this.onAccept,
    required this.onDecline,
  });

  final List<CareGrant> pending;
  final String? busyId;
  final ValueChanged<CareGrant> onAccept;
  final ValueChanged<CareGrant> onDecline;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Convites', style: text.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        if (pending.isEmpty)
          Text('Nenhum convite pendente.', style: text.bodyMedium)
        else
          for (final grant in pending) ...[
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                side: const BorderSide(color: AppColors.border),
              ),
              tileColor: AppColors.surface,
              title: Text(grant.patientName),
              subtitle: const Text('Quer liberar a Evolução'),
              trailing: busyId == grant.id
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
            ),
            if (busyId != grant.id)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => onDecline(grant),
                      child: const Text('Recusar'),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    FilledButton(
                      onPressed: () => onAccept(grant),
                      child: const Text('Aceitar'),
                    ),
                  ],
                ),
              )
            else
              const SizedBox(height: AppSpacing.sm),
          ],
      ],
    );
  }
}

class _PatientList extends StatelessWidget {
  const _PatientList({required this.accepted, required this.onOpen});

  final List<CareGrant> accepted;
  final ValueChanged<CareGrant> onOpen;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Pacientes com acesso', style: text.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        if (accepted.isEmpty)
          Text(
            'Quando você aceitar um convite, o paciente aparece aqui.',
            style: text.bodyMedium,
          )
        else
          for (final grant in accepted) ...[
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                side: const BorderSide(color: AppColors.border),
              ),
              tileColor: AppColors.surface,
              title: Text(grant.patientName),
              subtitle: const Text('Evolução somente leitura'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => onOpen(grant),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
      ],
    );
  }
}
