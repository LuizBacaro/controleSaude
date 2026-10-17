import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers.dart';
import '../../../core/router/marker_route.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../domain/exam_marker.dart';
import 'widgets/report_heading.dart';
import 'widgets/status_chip.dart';

class ReportDetailPage extends ConsumerWidget {
  const ReportDetailPage({super.key, required this.reportId});

  final String reportId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(examsRevisionProvider);
    final report = ref.watch(examsRepositoryProvider).getById(reportId);
    final text = Theme.of(context).textTheme;
    final dateFmt = DateFormat('dd/MM/yyyy');

    if (report == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Laudo')),
        body: const Center(child: Text('Laudo não encontrado')),
      );
    }

    final byCategory = <String, List<ExamMarker>>{};
    for (final m in report.markers) {
      byCategory.putIfAbsent(m.category, () => []).add(m);
    }
    final categories = byCategory.keys.toList()..sort();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          report.labName == null
              ? 'Coleta ${dateFmt.format(report.collectedAt)}'
              : report.labName!,
        ),
        actions: [
          IconButton(
            tooltip: 'Remover laudo',
            onPressed: () async {
              final confirmed =
                  await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Remover laudo?'),
                      content: const Text(
                        'Os marcadores deste PDF sairão do histórico, do painel e da evolução.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancelar'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Remover'),
                        ),
                      ],
                    ),
                  ) ??
                  false;
              if (!confirmed || !context.mounted) return;
              await ref.read(examsRepositoryProvider).deleteReport(report.id);
              ref.read(examsRevisionProvider.notifier).bump();
              if (context.mounted) context.pop();
            },
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          ReportHeading(report: report),
          if (report.unrecognized.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Não interpretado', style: text.titleSmall),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Estes trechos parecem exame, mas o leitor não achou um valor seguro.',
                    style: text.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ...report.unrecognized.map(
                    (line) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('• $line', style: text.bodyMedium),
                    ),
                  ),
                ],
              ),
            ),
          ...categories.expand((cat) {
            final markers = byCategory[cat]!;
            return [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Text(cat, style: text.titleMedium),
              ),
              ...markers.map(
                (m) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      side: const BorderSide(color: AppColors.border),
                    ),
                    tileColor: AppColors.surface,
                    title: Text(m.name),
                    subtitle: Text(
                      m.resultLabel +
                          (m.referenceText != null
                              ? '\nRef: ${m.referenceText}'
                              : ''),
                    ),
                    isThreeLine: m.referenceText != null,
                    trailing: StatusChip(status: m.status),
                    onTap: () => context.push(markerRoute(m.name)),
                  ),
                ),
              ),
            ];
          }),
        ],
      ),
    );
  }
}
