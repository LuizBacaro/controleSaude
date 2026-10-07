import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/exam_marker.dart';
import '../../domain/exam_report.dart';

class MarkerChart extends StatelessWidget {
  const MarkerChart({
    super.key,
    required this.series,
    this.height = 200,
  });

  final MarkerSeries series;
  final double height;

  @override
  Widget build(BuildContext context) {
    final points = series.points;
    if (points.length < 2) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            points.isEmpty
                ? 'Sem dados ainda'
                : 'Importe mais exames para ver a evolução',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final dateFmt = DateFormat('dd/MM');
    final spots = <FlSpot>[];
    for (var i = 0; i < points.length; i++) {
      spots.add(FlSpot(i.toDouble(), points[i].value));
    }

    final values = points.map((p) => p.value).toList();
    var minY = values.reduce((a, b) => a < b ? a : b);
    var maxY = values.reduce((a, b) => a > b ? a : b);
    if (series.referenceMin != null) {
      minY = minY < series.referenceMin! ? minY : series.referenceMin!;
    }
    if (series.referenceMax != null) {
      maxY = maxY > series.referenceMax! ? maxY : series.referenceMax!;
    }
    final pad = (maxY - minY).abs() * 0.15 + 0.1;

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minY: minY - pad,
          maxY: maxY + pad,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
              color: AppColors.border.withValues(alpha: 0.6),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 42,
                getTitlesWidget: (value, _) => Text(
                  value.toStringAsFixed(value >= 100 ? 0 : 1),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                getTitlesWidget: (value, _) {
                  final i = value.toInt();
                  if (i < 0 || i >= points.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      dateFmt.format(points[i].date),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  );
                },
              ),
            ),
          ),
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              if (series.referenceMin != null)
                HorizontalLine(
                  y: series.referenceMin!,
                  color: AppColors.info.withValues(alpha: 0.45),
                  strokeWidth: 1,
                  dashArray: [6, 4],
                ),
              if (series.referenceMax != null)
                HorizontalLine(
                  y: series.referenceMax!,
                  color: AppColors.warning.withValues(alpha: 0.45),
                  strokeWidth: 1,
                  dashArray: [6, 4],
                ),
            ],
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: AppColors.teal,
              barWidth: 3,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, bar, index) {
                  final status = _statusFor(spot.y);
                  final color = switch (status) {
                    MarkerStatus.normal => AppColors.success,
                    MarkerStatus.low => AppColors.info,
                    MarkerStatus.high => AppColors.warning,
                    MarkerStatus.unknown => AppColors.teal,
                  };
                  return FlDotCirclePainter(
                    radius: 4.5,
                    color: color,
                    strokeWidth: 2,
                    strokeColor: Colors.white,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.teal.withValues(alpha: 0.08),
              ),
            ),
          ],
        ),
      ),
    );
  }

  MarkerStatus _statusFor(double value) {
    if (series.referenceMin != null && value < series.referenceMin!) {
      return MarkerStatus.low;
    }
    if (series.referenceMax != null && value > series.referenceMax!) {
      return MarkerStatus.high;
    }
    if (series.referenceMin != null || series.referenceMax != null) {
      return MarkerStatus.normal;
    }
    return MarkerStatus.unknown;
  }
}
