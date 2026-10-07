import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reports = ref.watch(examReportsProvider);
    final text = Theme.of(context).textTheme;
    final dateFmt = DateFormat('dd/MM/yyyy');

    return Scaffold(
      appBar: AppBar(title: const Text('Histórico de exames')),
      body: reports.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.folder_open, size: 48, color: AppColors.sage),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Nenhum laudo importado ainda.',
                      style: text.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    FilledButton(
                      onPressed: () => context.push('/importar'),
                      child: const Text('Importar PDF'),
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                100,
              ),
              itemCount: reports.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final report = reports[index];
                return Dismissible(
                  key: ValueKey(report.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                    child: const Icon(Icons.delete_outline, color: AppColors.error),
                  ),
                  confirmDismiss: (_) async {
                    return await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Remover laudo?'),
                            content: const Text(
                              'Os marcadores deste PDF sairão do histórico.',
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
                  },
                  onDismissed: (_) async {
                    await ref.read(examsRepositoryProvider).deleteReport(report.id);
                    ref.read(examsRevisionProvider.notifier).bump();
                  },
                  child: Material(
                    color: AppColors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      side: const BorderSide(color: AppColors.border),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      onTap: () => context.push('/laudo/${report.id}'),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dateFmt.format(report.collectedAt),
                              style: text.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              [
                                if (report.labName != null) report.labName!,
                                '${report.markerCount} marcadores',
                                if (report.outOfRangeCount > 0)
                                  '${report.outOfRangeCount} fora da faixa',
                              ].join(' · '),
                              style: text.bodyMedium,
                            ),
                            if (report.sourceFileName != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                report.sourceFileName!,
                                style: text.bodySmall,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
