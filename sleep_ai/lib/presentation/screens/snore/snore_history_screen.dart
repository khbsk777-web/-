import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../viewmodels/dashboard_viewmodel.dart';
import '../../widgets/charts/snore_chart.dart';

class SnoreHistoryScreen extends ConsumerWidget {
  const SnoreHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardViewModelProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('いびき履歴')),
      body: state.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // Summary cards
                      _SnoreSummaryCard(sessions: state.recentSessions),
                      const SizedBox(height: 24),
                      Text('いびき回数の推移',
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 12),
                      SnoreChart(sessions: state.recentSessions),
                      const SizedBox(height: 24),
                      Text('詳細履歴',
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 12),
                      ...state.recentSessions
                          .where((s) => s.snoreCount != null && s.snoreCount! > 0)
                          .map((s) => _SnoreSessionTile(session: s)),
                    ]),
                  ),
                ),
              ],
            ),
    );
  }
}

class _SnoreSummaryCard extends StatelessWidget {
  final List sessions;
  const _SnoreSummaryCard({required this.sessions});

  @override
  Widget build(BuildContext context) {
    final totalSnores = sessions.fold<int>(
        0, (sum, s) => sum + (s.snoreCount as int? ?? 0));
    final avgSnores =
        sessions.isNotEmpty ? totalSnores / sessions.length : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: AppColors.snoreGradient),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _SummaryItem(label: '今月合計', value: '$totalSnores回'),
          _SummaryItem(
              label: '1夜平均',
              value: '${avgSnores.toStringAsFixed(1)}回'),
          _SummaryItem(label: '記録日数', value: '${sessions.length}日'),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w700)),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}

class _SnoreSessionTile extends StatelessWidget {
  final dynamic session;
  const _SnoreSessionTile({required this.session});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.mic_rounded, color: AppColors.accent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('M月d日(E)', 'ja').format(session.startTime),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  '${session.snoreCount}回 · ${session.snoreTotalMinutes ?? 0}分',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${session.snoreCount}回',
              style: const TextStyle(
                  color: AppColors.accent, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
