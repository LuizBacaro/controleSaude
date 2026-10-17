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
  String _query = '';
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
      setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
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
    final pending = _sorted(_grants.where((grant) => grant.isPending).toList());
    final accepted = _sorted(
      _grants.where((grant) => grant.isAccepted).toList(),
    );
    final query = _query.trim().toLowerCase();
    final visible = accepted.where((grant) {
      if (query.isEmpty) return true;
      return grant.patientName.toLowerCase().contains(query);
    }).toList();
    final crm = user?.crmLabel;
    final greeting = crm == null
        ? 'Olá, ${user?.displayName ?? 'médico'}'
        : 'Olá, ${user?.displayName ?? 'médico'} · $crm';

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
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    children: [
                      Text(greeting, style: text.headlineSmall),
                      if (_error != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      if (pending.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          'Convites (${pending.length})',
                          style: text.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        for (final grant in pending) ...[
                          _InviteCard(
                            grant: grant,
                            busy: _busyId == grant.id,
                            onAccept: () => _respond(grant, accept: true),
                            onDecline: () => _respond(grant, accept: false),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                        ],
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'Pacientes (${accepted.length})',
                        style: text.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Toque no nome para abrir a Evolução. É somente leitura.',
                        style: text.bodyMedium,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        decoration: const InputDecoration(
                          hintText: 'Buscar paciente',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (value) => setState(() => _query = value),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (visible.isEmpty)
                        Text(
                          accepted.isEmpty
                              ? 'Quando você aceitar um convite, o paciente aparece aqui.'
                              : 'Nenhum paciente com esse nome.',
                          style: text.bodyLarge,
                        )
                      else
                        for (final grant in visible) ...[
                          ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppSpacing.radiusMd,
                              ),
                              side: const BorderSide(color: AppColors.border),
                            ),
                            tileColor: AppColors.surface,
                            title: Text(grant.patientName),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _open(grant),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                        ],
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

List<CareGrant> _sorted(List<CareGrant> grants) {
  grants.sort(
    (a, b) =>
        a.patientName.toLowerCase().compareTo(b.patientName.toLowerCase()),
  );
  return grants;
}

class _InviteCard extends StatelessWidget {
  const _InviteCard({
    required this.grant,
    required this.busy,
    required this.onAccept,
    required this.onDecline,
  });

  final CareGrant grant;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(grant.patientName, style: text.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            if (busy)
              const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: onDecline,
                      child: const Text('Recusar'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: FilledButton(
                      onPressed: onAccept,
                      child: const Text('Aceitar'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
