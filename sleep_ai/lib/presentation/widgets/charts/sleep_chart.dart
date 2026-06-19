import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/sleep_session.dart';

class SleepChart extends StatelessWidget {
  final List<SleepSession> sessions;
  const SleepChart({super.key, required this.sessions});

  @override
  Widget build(BuildContext context) {
    final last7 = sessions.take(7).toList().reversed.toList();

    if (last7.isEmpty) {
      return Container(
        height: 160,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Text('データなし',
              style: TextStyle(color: AppColors.textTertiary)),
        ),
      );
    }

    final spots = last7.asMap().entries.map((e) {
      final hours = (e.value.totalMinutes ?? 0) / 60.0;
      return FlSpot(e.key.toDouble(), hours);
    }).toList();

    return Container(
      height: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 2,
            getDrawingHorizontalLine: (_) => FlLine(
              color: AppColors.divider,
              strokeWidth: 0.5,
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 2,
                getTitlesWidget: (val, _) => Text(
                  '${val.toInt()}h',
                  style: const TextStyle(
                      color: AppColors.textTertiary, fontSize: 10),
                ),
                reservedSize: 30,
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (val, _) {
                  final idx = val.toInt();
                  if (idx < 0 || idx >= last7.length) return const SizedBox();
                  return Text(
                    DateFormat('E', 'ja').format(last7[idx].startTime),
                    style: const TextStyle(
                        color: AppColors.textTertiary, fontSize: 10),
                  );
                },
              ),
            ),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          minY: 0,
          maxY: 12,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              gradient: const LinearGradient(colors: AppColors.scoreGradient),
              barWidth: 2.5,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                  radius: 4,
                  color: AppColors.primary,
                  strokeWidth: 2,
                  strokeColor: AppColors.background,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.primary.withOpacity(0.3),
                    AppColors.primary.withOpacity(0),
                  ],
                ),
              ),
            ),
          ],
          // Ideal sleep line at 8h
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              HorizontalLine(
                y: 8,
                color: AppColors.success.withOpacity(0.3),
                strokeWidth: 1,
                dashArray: [4, 4],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
