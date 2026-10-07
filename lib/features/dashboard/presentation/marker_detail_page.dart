import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../exams/presentation/widgets/marker_chart.dart';
import '../../exams/presentation/widgets/status_chip.dart';

class MarkerDetailPage extends ConsumerWidget {
  const MarkerDetailPage({super.key, required this.markerName});

  final String markerName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final series = ref.watch(examsRepositoryProvider).seriesFor(markerName);
    final text = Theme.of(context).textTheme;
    final dateFmt = DateFormat('dd/MM/yyyy');

    if (series == null) {
      return Scaffold(
        appBar: AppBar(title: Text(markerName)),
        body: const Center(child: Text('Marcador não encontrado')),
      );
    }

    final latest = series.latest;

    return Scaffold(
      appBar: AppBar(title: Text(series.name)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(series.category, style: text.bodySmall),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        latest == null
                            ? '—'
                            : '${latest.value} ${series.unit}'.trim(),
                        style: text.displaySmall?.copyWith(color: AppColors.teal),
                      ),
                    ),
                    StatusChip(status: series.latestStatus),
                  ],
                ),
                if (series.referenceText != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Referência: ${series.referenceText}',
                    style: text.bodyMedium,
                  ),
                ],
                if (series.delta != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Variação: ${series.delta! >= 0 ? '+' : ''}${series.delta!.toStringAsFixed(2)}',
                    style: text.bodyMedium,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Evolução', style: text.titleMedium),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: AppColors.border),
            ),
            child: MarkerChart(series: series, height: 240),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Histórico de valores', style: text.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          ...series.points.reversed.map(
            (p) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(dateFmt.format(p.date)),
              trailing: Text(
                '${p.value} ${series.unit}'.trim(),
                style: text.titleSmall,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Este painel é informativo e não substitui avaliação médica.',
            style: text.bodySmall,
          ),
        ],
      ),
    );
  }
}
