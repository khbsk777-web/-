import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../viewmodels/dashboard_viewmodel.dart';
import '../../widgets/cards/sleep_score_card.dart';
import '../../widgets/cards/stat_card.dart';
import '../../widgets/cards/ai_report_card.dart';
import '../../widgets/charts/sleep_chart.dart';

class DashboardTab extends ConsumerWidget {
  const DashboardTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardViewModelProvider);
    final vm = ref.read(dashboardViewModelProvider.notifier);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            backgroundColor: AppColors.background,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              title: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('M月d日(E)', 'ja').format(DateTime.now()),
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12),
                  ),
                  const Text(
                    'Sleep AI',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
          if (state.isLoading)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Score cards
                  Row(
                    children: [
                      Expanded(
                        child: SleepScoreCard(
                          label: '睡眠スコア',
                          score: state.lastSession?.sleepScore ?? 0,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SleepScoreCard(
                          label: '回復スコア',
                          score: state.lastSession?.recoveryScore ?? 0,
                          color: AppColors.secondary,
                        ),
                      ),
                    ],
                  ).animate().fadeIn(duration: 400.ms),
                  const SizedBox(height: 12),

                  // Stat cards row 1
                  Row(
                    children: [
                      Expanded(
                        child: StatCard(
                          icon: Icons.bedtime_rounded,
                          label: '睡眠時間',
                          value: _formatSleepTime(
                              state.lastSession?.totalMinutes),
                          color: AppColors.primaryLight,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: StatCard(
                          icon: Icons.mic_rounded,
                          label: 'いびき回数',
                          value:
                              '${state.lastSession?.snoreCount ?? 0}回',
                          color: AppColors.accent,
                        ),
                      ),
                    ],
                  ).animate().fadeIn(delay: 100.ms),
                  const SizedBox(height: 12),

                  // Stat cards row 2
                  Row(
                    children: [
                      Expanded(
                        child: StatCard(
                          icon: Icons.directions_walk_rounded,
                          label: '歩数',
                          value:
                              '${_formatNumber(state.healthSnapshot?.steps)}歩',
                          color: AppColors.success,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: StatCard(
                          icon: Icons.favorite_rounded,
                          label: '心拍数',
                          value:
                              '${state.healthSnapshot?.heartRateAvg?.toStringAsFixed(0) ?? '--'}bpm',
                          color: AppColors.error,
                        ),
                      ),
                    ],
                  ).animate().fadeIn(delay: 200.ms),
                  const SizedBox(height: 24),

                  // Sleep chart
                  _SectionHeader(title: '睡眠時間の推移'),
                  const SizedBox(height: 12),
                  SleepChart(sessions: state.recentSessions)
                      .animate()
                      .fadeIn(delay: 300.ms),
                  const SizedBox(height: 24),

                  // AI Report
                  _SectionHeader(
                    title: 'AIレポート',
                    action: TextButton(
                      onPressed: vm.generateAiReport,
                      child: const Text('更新',
                          style: TextStyle(color: AppColors.primary)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  AiReportCard(report: state.latestReport)
                      .animate()
                      .fadeIn(delay: 400.ms),
                  const SizedBox(height: 32),
                ]),
              ),
            ),
        ],
      ),
    );
  }

  String _formatSleepTime(int? minutes) {
    if (minutes == null) return '--';
    return '${minutes ~/ 60}h${minutes % 60}m';
  }

  String _formatNumber(int? n) => n != null
      ? n.toString().replaceAllMapped(
          RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',')
      : '--';
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Widget? action;
  const _SectionHeader({required this.title, this.action});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        if (action != null) action!,
      ],
    );
  }
}
