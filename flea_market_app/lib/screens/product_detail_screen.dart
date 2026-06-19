import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/product.dart';
import '../providers/product_provider.dart';
import '../utils/formatters.dart';
import '../utils/theme.dart';
import 'product_form_screen.dart';

class ProductDetailScreen extends ConsumerWidget {
  final Product product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(productListProvider).value ?? [];
    final current = products.firstWhere(
      (p) => p.id == product.id,
      orElse: () => product,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(current.name, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => ProductFormScreen(product: current)),
            ),
          ),
          PopupMenuButton(
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'delete', child: Text('削除')),
            ],
            onSelected: (v) async {
              if (v == 'delete') {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('削除確認'),
                    content: Text('「${current.name}」を削除しますか？'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('キャンセル')),
                      FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('削除')),
                    ],
                  ),
                );
                if (ok == true && context.mounted) {
                  await ref
                      .read(productListProvider.notifier)
                      .deleteProduct(current.id);
                  Navigator.pop(context);
                }
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (current.imagePaths.isNotEmpty) _ImageCarousel(current.imagePaths),
          const SizedBox(height: 16),

          _InfoCard(current),
          const SizedBox(height: 12),

          _PriceComparisonCard(current),
          const SizedBox(height: 12),

          _ProfitCard(current),
          const SizedBox(height: 12),

          if (current.description.isNotEmpty) ...[
            _DetailSection('商品説明', current.description),
            const SizedBox(height: 12),
          ],

          if (current.memo != null) ...[
            _DetailSection('メモ', current.memo!),
            const SizedBox(height: 12),
          ],

          if (current.tags.isNotEmpty) ...[
            _TagsSection(current.tags),
            const SizedBox(height: 12),
          ],

          _MetaSection(current),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _ImageCarousel extends StatefulWidget {
  final List<String> paths;
  const _ImageCarousel(this.paths);

  @override
  State<_ImageCarousel> createState() => _ImageCarouselState();
}

class _ImageCarouselState extends State<_ImageCarousel> {
  int _current = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 220,
          child: PageView.builder(
            itemCount: widget.paths.length,
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (_, i) => ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(widget.paths[i]),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
              ),
            ),
          ),
        ),
        if (widget.paths.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              widget.paths.length,
              (i) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: _current == i ? 20 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: _current == i
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final Product product;
  const _InfoCard(this.product);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    product.name,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                _StatusBadge(product.status),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                Chip(
                  label: Text(product.category.label),
                  avatar: const Icon(Icons.category_outlined, size: 16),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                Chip(
                  label: Text('${product.condition.rank} ${product.condition.label}'),
                  avatar: const Icon(Icons.stars_outlined, size: 16),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const Divider(),
            _Row('仕入れ価格', formatCurrency(product.purchasePrice)),
          ],
        ),
      ),
    );
  }
}

class _PriceComparisonCard extends StatelessWidget {
  final Product product;
  const _PriceComparisonCard(this.product);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('価格比較',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _PlatformPriceBox(
                    platform: 'メルカリ',
                    platformPrice: product.mercariPrice,
                    color: AppTheme.mercariColor,
                    isBest: product.bestPlatform == 'メルカリ',
                  ),
                ),
                const SizedBox(width: 12),
                const Text('VS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(width: 12),
                Expanded(
                  child: _PlatformPriceBox(
                    platform: 'ラクマ',
                    platformPrice: product.rakumaPrice,
                    color: AppTheme.rakumaColor,
                    isBest: product.bestPlatform == 'ラクマ',
                  ),
                ),
              ],
            ),
            if (product.mercariPrice.price != null &&
                product.rakumaPrice.price != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('価格差'),
                    Text(
                      formatCurrency(
                          (product.mercariPrice.price! - product.rakumaPrice.price!).abs()),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PlatformPriceBox extends StatelessWidget {
  final String platform;
  final PlatformPrice platformPrice;
  final Color color;
  final bool isBest;

  const _PlatformPriceBox({
    required this.platform,
    required this.platformPrice,
    required this.color,
    required this.isBest,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isBest ? color.withOpacity(0.1) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isBest ? color : Colors.grey.shade200,
          width: isBest ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          if (isBest)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('最高値',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold)),
            ),
          Text(
            platform,
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 6),
          Text(
            formatCurrency(platformPrice.price),
            style: TextStyle(
              fontSize: platformPrice.price != null ? 20 : 14,
              fontWeight: FontWeight.bold,
              color: isBest ? color : Colors.grey,
            ),
          ),
          if (platformPrice.listingUrl != null) ...[
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () async {
                final uri = Uri.tryParse(platformPrice.listingUrl!);
                if (uri != null) await launchUrl(uri);
              },
              child: Text(
                '出品ページを見る',
                style: TextStyle(
                    color: color,
                    fontSize: 11,
                    decoration: TextDecoration.underline),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProfitCard extends StatelessWidget {
  final Product product;
  const _ProfitCard(this.product);

  @override
  Widget build(BuildContext context) {
    final profit = product.profit;
    final rate = product.profitRate;
    if (profit == null) return const SizedBox.shrink();

    final color = profit >= 0 ? AppTheme.profit : AppTheme.loss;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('最高値での利益',
                      style: Theme.of(context).textTheme.bodySmall),
                  Text(
                    formatProfit(profit),
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Text(
                formatProfitRate(rate),
                style: TextStyle(
                    color: color, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  final String title;
  final String content;
  const _DetailSection(this.title, this.content);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(content),
          ],
        ),
      ),
    );
  }
}

class _TagsSection extends StatelessWidget {
  final List<String> tags;
  const _TagsSection(this.tags);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('タグ',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: tags
                  .map((t) => Chip(
                        label: Text(t),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaSection extends StatelessWidget {
  final Product product;
  const _MetaSection(this.product);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _Row('登録日', formatDateTime(product.createdAt)),
            _Row('更新日', formatDateTime(product.updatedAt)),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey.shade600)),
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final ListingStatus status;
  const _StatusBadge(this.status);

  @override
  Widget build(BuildContext context) {
    final (color, bg) = switch (status) {
      ListingStatus.draft => (Colors.grey.shade600, Colors.grey.shade100),
      ListingStatus.listed => (Colors.green.shade700, Colors.green.shade50),
      ListingStatus.sold => (Colors.blue.shade700, Colors.blue.shade50),
      ListingStatus.cancelled => (Colors.red.shade700, Colors.red.shade50),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(status.label,
          style: TextStyle(color: color, fontWeight: FontWeight.bold)),
    );
  }
}
