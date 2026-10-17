import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../data/care_repository.dart';
import '../domain/care_grant.dart';

class DoctorsPage extends ConsumerStatefulWidget {
  const DoctorsPage({super.key});

  @override
  ConsumerState<DoctorsPage> createState() => _DoctorsPageState();
}

class _DoctorsPageState extends ConsumerState<DoctorsPage> {
  var _loading = true;
  String? _error;
  String? _busyId;
  String _query = '';
  bool? _tabShown;
  List<DoctorListing> _doctors = const [];
  List<CareGrant> _grants = const [];

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final shown = TickerMode.valuesOf(context).enabled;
    final previous = _tabShown;
    _tabShown = shown;
    if (previous == false && shown && !_loading) {
      _load(silent: true);
    }
  }

  Future<void> _load({bool silent = false}) async {
    if (silent && _loading) return;
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final care = ref.read(careRepositoryProvider);
      final doctors = await care.listDoctors();
      final grants = await care.grantsAsPatient();
      if (!mounted) return;
      setState(() {
        _doctors = doctors;
        _grants = grants;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _text(error));
    } finally {
      if (mounted && !silent) setState(() => _loading = false);
    }
  }

  CareGrant? _grantFor(String doctorId) {
    for (final grant in _grants) {
      if (grant.doctorId == doctorId) return grant;
    }
    return null;
  }

  Future<void> _invite(DoctorListing doctor) async {
    setState(() => _busyId = doctor.id);
    try {
      await ref.read(careRepositoryProvider).invite(doctor.id);
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = _text(error));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _revoke(CareGrant grant) async {
    setState(() => _busyId = grant.doctorId);
    try {
      await ref.read(careRepositoryProvider).revoke(grant.id);
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = _text(error));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  String _text(Object error) =>
      error.toString().replaceFirst('Exception: ', '');

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final query = _query.trim().toLowerCase();
    final visible = _doctors.where((doctor) {
      if (query.isEmpty) return true;
      return doctor.displayName.toLowerCase().contains(query) ||
          doctor.crmLabel.toLowerCase().contains(query);
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Médicos')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  Text(
                    'O médico só vê a sua Evolução depois que você convida e ele aceita.',
                    style: text.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    decoration: const InputDecoration(
                      hintText: 'Buscar por nome ou CRM',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (value) => setState(() => _query = value),
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
                  const SizedBox(height: AppSpacing.md),
                  if (visible.isEmpty)
                    Text(
                      _doctors.isEmpty
                          ? 'Ainda não há médico cadastrado.'
                          : 'Nenhum médico com esse nome ou CRM.',
                      style: text.bodyLarge,
                    ),
                  for (final doctor in visible) ...[
                    DoctorInviteCard(
                      doctor: doctor,
                      grant: _grantFor(doctor.id),
                      busy: _busyId == doctor.id,
                      onInvite: () => _invite(doctor),
                      onRevoke: (grant) => _revoke(grant),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                ],
              ),
            ),
    );
  }
}

class DoctorInviteCard extends StatelessWidget {
  const DoctorInviteCard({
    super.key,
    required this.doctor,
    required this.grant,
    required this.busy,
    required this.onInvite,
    required this.onRevoke,
  });

  final DoctorListing doctor;
  final CareGrant? grant;
  final bool busy;
  final VoidCallback onInvite;
  final ValueChanged<CareGrant> onRevoke;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final grant = this.grant;
    final accepted = grant?.isAccepted ?? false;
    final pending = grant?.isPending ?? false;
    final icon = accepted
        ? Icons.verified_outlined
        : pending
        ? Icons.hourglass_top
        : Icons.medical_services_outlined;

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
            Row(
              children: [
                Icon(icon, color: AppColors.teal),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(doctor.displayName, style: text.titleMedium),
                      Text(doctor.crmLabel, style: text.bodyMedium),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            if (busy)
              const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (grant != null && (accepted || pending))
              Row(
                children: [
                  Expanded(
                    child: Text(
                      accepted ? 'Acesso liberado' : 'Aguardando aceite',
                      style: text.bodyMedium,
                    ),
                  ),
                  TextButton(
                    onPressed: () => onRevoke(grant),
                    child: Text(accepted ? 'Revogar' : 'Cancelar'),
                  ),
                ],
              )
            else
              FilledButton(onPressed: onInvite, child: const Text('Convidar')),
          ],
        ),
      ),
    );
  }
}
