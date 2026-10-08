import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers.dart';
import '../../../core/router/marker_route.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../exams/domain/exam_marker.dart';
import '../../exams/presentation/widgets/status_chip.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final summary = ref.watch(dashboardSummaryProvider);
    final series = ref.watch(markerSeriesProvider);
    final text = Theme.of(context).textTheme;
    final dateFmt = DateFormat('dd/MM/yyyy');

    if (!ref.watch(hasExamsProvider)) {
      return Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Olá, ${user?.displayName ?? 'paciente'}',
                  style: text.headlineMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Ainda não há exames. Importe o PDF do seu laudo para montar o painel.',
                  style: text.bodyLarge,
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () => context.push('/importar'),
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Importar PDF'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final highlight = series.take(8).toList();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            title: Text('Controle Saúde', style: text.titleLarge),
            actions: [
              IconButton(
                tooltip: 'Importar PDF',
                onPressed: () => context.push('/importar'),
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.xxl,
            ),
            sliver: SliverList.list(
              children: [
                Text(
                  'Olá, ${user?.displayName ?? 'paciente'}',
                  style: text.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  summary.lastCollectedAt == null
                      ? 'Acompanhe seus marcadores'
                      : 'Última coleta: ${dateFmt.format(summary.lastCollectedAt!)}',
                  style: text.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        label: 'Marcadores',
                        value: '${summary.totalMarkers}',
                        color: AppColors.teal,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _StatCard(
                        label: 'Fora da faixa',
                        value: '${summary.outOfRange.length}',
                        color: summary.outOfRange.isEmpty
                            ? AppColors.success
                            : AppColors.warning,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _StatCard(
                        label: 'Laudos',
                        value: '${summary.reportCount}',
                        color: AppColors.sage,
                      ),
                    ),
                  ],
                ),
                if (summary.outOfRange.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text('Atenção', style: text.titleMedium),
                  const SizedBox(height: AppSpacing.sm),
                  ...summary.outOfRange
                      .take(5)
                      .map(
                        (s) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: _MarkerTile(
                            name: s.name,
                            value: s.latest!.value,
                            unit: s.unit,
                            status: s.latestStatus,
                            onTap: () => context.push(markerRoute(s.name)),
                          ),
                        ),
                      ),
                ],
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: Text('Marcadores', style: text.titleMedium),
                    ),
                    TextButton(
                      onPressed: () => context.go('/app/evolucao'),
                      child: const Text('Ver todos'),
                    ),
                  ],
                ),
                ...highlight.map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _MarkerTile(
                      name: s.name,
                      value: s.latest?.value ?? 0,
                      unit: s.unit,
                      status: s.latestStatus,
                      category: s.category,
                      delta: s.delta,
                      onTap: () => context.push(markerRoute(s.name)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(color: color),
          ),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _MarkerTile extends StatelessWidget {
  const _MarkerTile({
    required this.name,
    required this.value,
    required this.unit,
    required this.status,
    this.category,
    this.delta,
    this.onTap,
  });

  final String name;
  final double value;
  final String unit;
  final MarkerStatus status;
  final String? category;
  final double? delta;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final valueStr = value >= 1000
        ? NumberFormat.decimalPattern('pt_BR').format(value.round())
        : value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1);

    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (category != null)
                      Text(category!, style: text.bodySmall),
                    Text(name, style: text.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      '$valueStr ${unit.isEmpty ? '' : unit}'.trim(),
                      style: text.bodyLarge?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (delta != null)
                      Text(
                        '${delta! >= 0 ? '▲' : '▼'} ${delta!.abs().toStringAsFixed(1)} vs anterior',
                        style: text.bodySmall?.copyWith(
                          color: delta! >= 0
                              ? AppColors.warning
                              : AppColors.info,
                        ),
                      ),
                  ],
                ),
              ),
              StatusChip(status: status),
              const SizedBox(width: AppSpacing.xs),
              const Icon(Icons.chevron_right, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
