import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import 'widgets/health_fields.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final summary = ref.watch(dashboardSummaryProvider);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: AppColors.surfaceElevated,
            child: Text(
              (user?.displayName.isNotEmpty == true
                      ? user!.displayName[0]
                      : '?')
                  .toUpperCase(),
              style: text.headlineMedium?.copyWith(color: AppColors.teal),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(user?.displayName ?? '', style: text.headlineSmall),
          Text(user?.email ?? '', style: text.bodyMedium),
          const SizedBox(height: AppSpacing.lg),
          _HealthSummary(
            sex: user?.sex,
            birthDate: user?.birthDate,
            onEdit: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) => const _HealthProfileSheet(),
            ),
          ),
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.folder_outlined),
            title: Text('${summary.reportCount} laudos salvos'),
            subtitle: Text('${summary.totalMarkers} marcadores acompanhados'),
          ),
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.upload_file),
            title: const Text('Importar novo PDF'),
            onTap: () => context.push('/importar'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.info_outline),
            title: const Text('Sobre'),
            subtitle: const Text(
              'ExameFácil não substitui consulta médica. '
              'Seus laudos ficam salvos na sua conta.',
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          OutlinedButton(
            onPressed: () async {
              await ref.read(authRepositoryProvider).logout();
              ref.read(examsRepositoryProvider).clear();
              ref.read(authRevisionProvider.notifier).bump();
              ref.read(examsRevisionProvider.notifier).bump();
              if (context.mounted) context.go('/');
            },
            child: const Text('Sair'),
          ),
        ],
      ),
    );
  }
}

class _HealthSummary extends StatelessWidget {
  const _HealthSummary({
    required this.sex,
    required this.birthDate,
    required this.onEdit,
  });

  final String? sex;
  final DateTime? birthDate;
  final VoidCallback onEdit;

  int _age(DateTime birth) {
    final now = DateTime.now();
    var years = now.year - birth.year;
    if (now.month < birth.month ||
        (now.month == birth.month && now.day < birth.day)) {
      years--;
    }
    return years;
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final incomplete = sex == null || birthDate == null;
    final rows = <(String, String)>[
      (
        'Sexo',
        switch (sex) {
          'M' => 'Masculino',
          'F' => 'Feminino',
          _ => 'Não informado',
        },
      ),
      (
        'Nascimento',
        birthDate == null
            ? 'Não informado'
            : DateFormat('dd/MM/yyyy').format(birthDate!),
      ),
      ('Idade', birthDate == null ? '—' : '${_age(birthDate!)} anos'),
    ];

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: incomplete ? AppColors.warning : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.monitor_heart_outlined,
                color: incomplete ? AppColors.warning : AppColors.teal,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Dados para as faixas de referência',
                  style: text.titleSmall,
                ),
              ),
              IconButton(
                tooltip: 'Editar',
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
              ),
            ],
          ),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Row(
                children: [
                  SizedBox(
                    width: 108,
                    child: Text(
                      row.$1,
                      style: text.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Expanded(child: Text(row.$2, style: text.bodyMedium)),
                ],
              ),
            ),
          if (incomplete) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Complete para o app escolher a faixa certa quando o PDF não trouxer sexo e idade.',
              style: text.bodySmall?.copyWith(color: AppColors.warning),
            ),
          ],
        ],
      ),
    );
  }
}

class _HealthProfileSheet extends ConsumerStatefulWidget {
  const _HealthProfileSheet();

  @override
  ConsumerState<_HealthProfileSheet> createState() =>
      _HealthProfileSheetState();
}

class _HealthProfileSheetState extends ConsumerState<_HealthProfileSheet> {
  DateTime? _birthDate;
  String? _sex;
  var _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider);
    _birthDate = user?.birthDate;
    _sex = user?.sex;
  }

  Future<void> _save() async {
    if (_birthDate == null || _sex == null) {
      setState(() => _error = 'Preencha os dois campos.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .updateHealthProfile(birthDate: _birthDate!, sex: _sex!);
      ref.read(authRevisionProvider.notifier).bump();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _saving = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Dados para as faixas', style: text.titleLarge),
          const SizedBox(height: AppSpacing.md),
          HealthFields(
            birthDate: _birthDate,
            sex: _sex,
            onBirthDate: (date) => setState(() => _birthDate = date),
            onSex: (value) => setState(() => _sex = value),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Vale para os próximos PDFs importados. Para reavaliar laudos já '
            'salvos, apague e importe de novo.',
            style: text.bodySmall,
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(_error!, style: text.bodyMedium?.copyWith(color: AppColors.error)),
          ],
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Salvando…' : 'Salvar'),
          ),
        ],
      ),
    );
  }
}
