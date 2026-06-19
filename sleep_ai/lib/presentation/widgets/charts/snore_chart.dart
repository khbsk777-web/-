import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/sleep_session.dart';

class SnoreChart extends StatelessWidget {
  final List<SleepSession> sessions;
  const SnoreChart({super.key, required this.sessions});

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

    final maxSnore = last7
        .map((s) => s.snoreCount ?? 0)
        .reduce((a, b) => a > b ? a : b)
        .toDouble();

    return Container(
      height: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxSnore > 0 ? maxSnore * 1.3 : 10,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
              color: AppColors.divider,
              strokeWidth: 0.5,
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (val, _) => Text(
                  '${val.toInt()}',
                  style: const TextStyle(
                      color: AppColors.textTertiary, fontSize: 10),
                ),
                reservedSize: 24,
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
          barGroups: last7.asMap().entries.map((e) {
            final count = (e.value.snoreCount ?? 0).toDouble();
            return BarChartGroupData(
              x: e.key,
              barRods: [
                BarChartRodData(
                  toY: count,
                  gradient: const LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: AppColors.snoreGradient,
                  ),
                  width: 20,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(6)),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
