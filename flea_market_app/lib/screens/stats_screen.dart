import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/product.dart';
import '../providers/product_provider.dart';
import '../utils/formatters.dart';
import '../utils/theme.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(statsProvider);
    final productsAsync = ref.watch(productListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('統計・分析')),
      body: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('エラー: $e')),
        data: (stats) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SummaryCards(stats),
            const SizedBox(height: 16),
            productsAsync.whenOrNull(
                  data: (products) => _CategoryChart(products),
                ) ??
                const SizedBox.shrink(),
            const SizedBox(height: 16),
            productsAsync.whenOrNull(
                  data: (products) => _PlatformStats(products),
                ) ??
                const SizedBox.shrink(),
            const SizedBox(height: 16),
            productsAsync.whenOrNull(
                  data: (products) => _TopProfitList(products),
                ) ??
                const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }
}

class _SummaryCards extends StatelessWidget {
  final Map<String, dynamic> stats;
  const _SummaryCards(this.stats);

  @override
  Widget build(BuildContext context) {
    final revenue = stats['soldRevenue'] as int;
    final purchase = stats['totalPurchase'] as int;
    final totalProfit = revenue - purchase;

    return Column(
      children: [
        Row(
          children: [
            _StatCard('総商品数', '${stats['total']}点',
                Icons.inventory_2_outlined, Colors.indigo),
            const SizedBox(width: 12),
            _StatCard('出品中', '${stats['listed']}点',
                Icons.storefront_outlined, Colors.green),
            const SizedBox(width: 12),
            _StatCard('売却済み', '${stats['sold']}点',
                Icons.check_circle_outline, Colors.blue),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _FinanceItem('売上合計', revenue, Colors.green.shade700),
                    _FinanceItem('仕入合計', purchase, Colors.orange.shade700),
                    _FinanceItem('利益合計', totalProfit,
                        totalProfit >= 0 ? AppTheme.profit : AppTheme.loss),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 4),
              Text(value,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold, color: color)),
              Text(label,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}

class _FinanceItem extends StatelessWidget {
  final String label;
  final int amount;
  final Color color;

  const _FinanceItem(this.label, this.amount, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        Text(
          formatCurrency(amount),
          style: TextStyle(
              fontWeight: FontWeight.bold, color: color, fontSize: 15),
        ),
      ],
    );
  }
}

class _CategoryChart extends StatelessWidget {
  final List<Product> products;
  const _CategoryChart(this.products);

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) return const SizedBox.shrink();

    final counts = <ProductCategory, int>{};
    for (final p in products) {
      counts[p.category] = (counts[p.category] ?? 0) + 1;
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(6).toList();

    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('カテゴリ別商品数',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: Row(
                children: [
                  Expanded(
                    child: PieChart(
                      PieChartData(
                        sections: List.generate(top.length, (i) {
                          final entry = top[i];
                          return PieChartSectionData(
                            value: entry.value.toDouble(),
                            color: colors[i % colors.length],
                            radius: 60,
                            title: entry.value.toString(),
                            titleStyle: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12),
                          );
                        }),
                        sectionsSpace: 2,
                        centerSpaceRadius: 30,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: List.generate(
                      top.length,
                      (i) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: colors[i % colors.length],
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(top[i].key.label,
                                style: const TextStyle(fontSize: 12)),
                            const SizedBox(width: 4),
                            Text('${top[i].value}',
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlatformStats extends StatelessWidget {
  final List<Product> products;
  const _PlatformStats(this.products);

  @override
  Widget build(BuildContext context) {
    int mercariCount = 0, rakumaCount = 0;
    int mercariTotal = 0, rakumaTotal = 0;

    for (final p in products) {
      if (p.mercariPrice.price != null) {
        mercariCount++;
        mercariTotal += p.mercariPrice.price!;
      }
      if (p.rakumaPrice.price != null) {
        rakumaCount++;
        rakumaTotal += p.rakumaPrice.price!;
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('プラットフォーム別出品状況',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _PlatformStatBox(
                    platform: 'メルカリ',
                    count: mercariCount,
                    avgPrice: mercariCount > 0
                        ? mercariTotal ~/ mercariCount
                        : null,
                    color: AppTheme.mercariColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PlatformStatBox(
                    platform: 'ラクマ',
                    count: rakumaCount,
                    avgPrice:
                        rakumaCount > 0 ? rakumaTotal ~/ rakumaCount : null,
                    color: AppTheme.rakumaColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PlatformStatBox extends StatelessWidget {
  final String platform;
  final int count;
  final int? avgPrice;
  final Color color;

  const _PlatformStatBox({
    required this.platform,
    required this.count,
    required this.avgPrice,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(platform,
              style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('$count件',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          Text('平均: ${formatCurrency(avgPrice)}',
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }
}

class _TopProfitList extends StatelessWidget {
  final List<Product> products;
  const _TopProfitList(this.products);

  @override
  Widget build(BuildContext context) {
    final withProfit = products
        .where((p) => p.profit != null)
        .toList()
      ..sort((a, b) => (b.profit ?? 0).compareTo(a.profit ?? 0));

    if (withProfit.isEmpty) return const SizedBox.shrink();
    final top5 = withProfit.take(5).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('利益上位商品',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...List.generate(top5.length, (i) {
              final p = top5[i];
              final profit = p.profit!;
              final color = profit >= 0 ? AppTheme.profit : AppTheme.loss;
              return ListTile(
                dense: true,
                leading: CircleAvatar(
                  radius: 14,
                  backgroundColor: color.withOpacity(0.1),
                  child: Text('${i + 1}',
                      style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                ),
                title: Text(p.name,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(p.bestPlatform ?? ''),
                trailing: Text(
                  formatProfit(profit),
                  style: TextStyle(color: color, fontWeight: FontWeight.bold),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
