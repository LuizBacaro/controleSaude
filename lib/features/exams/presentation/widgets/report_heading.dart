import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/exam_report.dart';

/// Cabeçalho do laudo como no PDF: quem, quando, qual médico e laboratório.
class ReportHeading extends StatelessWidget {
  const ReportHeading({super.key, required this.report, this.showFile = true});

  final ExamReport report;
  final bool showFile;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final rows = <(String, String)>[
      if (report.patientName != null) ('Paciente', report.patientName!),
      if (report.doctorName != null) ('Médico', report.doctorName!),
      if (report.labName != null) ('Laboratório', report.labName!),
      if (report.insuranceName != null) ('Convênio', report.insuranceName!),
      ('Coleta', DateFormat('dd/MM/yyyy').format(report.collectedAt)),
      if (showFile && report.sourceFileName != null)
        ('Arquivo', report.sourceFileName!),
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            color: AppColors.teal,
            child: Text(
              report.labName ?? 'Laudo',
              style: text.titleMedium?.copyWith(color: Colors.white),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: [
                for (final row in rows)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                        Expanded(
                          child: Text(row.$2, style: text.bodyMedium),
                        ),
                      ],
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
