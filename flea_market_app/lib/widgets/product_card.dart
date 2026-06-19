import 'dart:io';
import 'package:flutter/material.dart';
import '../models/product.dart';
import '../utils/formatters.dart';
import '../utils/theme.dart';

class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const ProductCard({
    super.key,
    required this.product,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final profit = product.profit;
    final profitColor = profit == null
        ? null
        : profit >= 0
            ? AppTheme.profit
            : AppTheme.loss;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _buildImage(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            product.name,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        _StatusChip(status: product.status),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product.condition.label,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurface.withOpacity(0.6),
                          ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _PlatformBadge(
                          label: 'メルカリ',
                          price: product.mercariPrice.price,
                          color: AppTheme.mercariColor,
                          isBest: product.bestPlatform == 'メルカリ',
                        ),
                        const SizedBox(width: 8),
                        _PlatformBadge(
                          label: 'ラクマ',
                          price: product.rakumaPrice.price,
                          color: AppTheme.rakumaColor,
                          isBest: product.bestPlatform == 'ラクマ',
                        ),
                        const Spacer(),
                        if (profit != null)
                          Text(
                            formatProfit(profit),
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: profitColor,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '仕入: ${formatCurrency(product.purchasePrice)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurface.withOpacity(0.5),
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImage() {
    if (product.imagePaths.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(product.imagePaths.first),
          width: 80,
          height: 80,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _placeholder(),
        ),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.image_outlined, color: Colors.grey, size: 36),
    );
  }
}

class _PlatformBadge extends StatelessWidget {
  final String label;
  final int? price;
  final Color color;
  final bool isBest;

  const _PlatformBadge({
    required this.label,
    required this.price,
    required this.color,
    required this.isBest,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isBest ? color.withOpacity(0.15) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
        border: isBest ? Border.all(color: color, width: 1.5) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isBest ? color : Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            price != null ? '¥${price!.toString()}' : '-',
            style: TextStyle(
              fontSize: 12,
              color: isBest ? color : Colors.grey.shade600,
              fontWeight: isBest ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final ListingStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, bg) = switch (status) {
      ListingStatus.draft => (Colors.grey.shade600, Colors.grey.shade100),
      ListingStatus.listed => (Colors.green.shade700, Colors.green.shade50),
      ListingStatus.sold => (Colors.blue.shade700, Colors.blue.shade50),
      ListingStatus.cancelled => (Colors.red.shade700, Colors.red.shade50),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.label,
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}
