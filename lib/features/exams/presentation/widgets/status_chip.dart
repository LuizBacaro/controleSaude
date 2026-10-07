import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/exam_marker.dart';

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});

  final MarkerStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      MarkerStatus.normal => ('Normal', AppColors.success),
      MarkerStatus.low => ('Baixo', AppColors.info),
      MarkerStatus.high => ('Alto', AppColors.warning),
      MarkerStatus.unknown => ('—', AppColors.textMuted),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color),
      ),
    );
  }
}
