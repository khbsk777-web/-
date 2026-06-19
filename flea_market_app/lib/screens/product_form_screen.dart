import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../models/product.dart';
import '../providers/product_provider.dart';
import '../utils/formatters.dart';
import '../utils/theme.dart';

class ProductFormScreen extends ConsumerStatefulWidget {
  final Product? product;

  const ProductFormScreen({super.key, this.product});

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _purchaseCtrl;
  late final TextEditingController _mercariCtrl;
  late final TextEditingController _mercariUrlCtrl;
  late final TextEditingController _rakumaCtrl;
  late final TextEditingController _rakumaUrlCtrl;
  late final TextEditingController _memoCtrl;
  late final TextEditingController _tagsCtrl;

  late ProductCategory _category;
  late ProductCondition _condition;
  late ListingStatus _status;
  late List<String> _imagePaths;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _descCtrl = TextEditingController(text: p?.description ?? '');
    _purchaseCtrl =
        TextEditingController(text: p?.purchasePrice != 0 ? p!.purchasePrice.toString() : '');
    _mercariCtrl = TextEditingController(
        text: p?.mercariPrice.price?.toString() ?? '');
    _mercariUrlCtrl =
        TextEditingController(text: p?.mercariPrice.listingUrl ?? '');
    _rakumaCtrl =
        TextEditingController(text: p?.rakumaPrice.price?.toString() ?? '');
    _rakumaUrlCtrl =
        TextEditingController(text: p?.rakumaPrice.listingUrl ?? '');
    _memoCtrl = TextEditingController(text: p?.memo ?? '');
    _tagsCtrl = TextEditingController(text: p?.tags.join(', ') ?? '');
    _category = p?.category ?? ProductCategory.other;
    _condition = p?.condition ?? ProductCondition.good;
    _status = p?.status ?? ListingStatus.draft;
    _imagePaths = List.from(p?.imagePaths ?? []);
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl, _descCtrl, _purchaseCtrl, _mercariCtrl, _mercariUrlCtrl,
      _rakumaCtrl, _rakumaUrlCtrl, _memoCtrl, _tagsCtrl
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(imageQuality: 80);
    if (picked.isNotEmpty) {
      setState(() => _imagePaths.addAll(picked.map((x) => x.path)));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final tags = _tagsCtrl.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    Product product;
    if (widget.product != null) {
      product = widget.product!.copyWith(
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        category: _category,
        condition: _condition,
        purchasePrice: int.tryParse(_purchaseCtrl.text) ?? 0,
        imagePaths: _imagePaths,
        mercariPrice: PlatformPrice(
          platform: 'メルカリ',
          price: int.tryParse(_mercariCtrl.text),
          listingUrl: _mercariUrlCtrl.text.trim().isEmpty
              ? null
              : _mercariUrlCtrl.text.trim(),
          listedAt: widget.product!.mercariPrice.listedAt,
          isSold: widget.product!.mercariPrice.isSold,
        ),
        rakumaPrice: PlatformPrice(
          platform: 'ラクマ',
          price: int.tryParse(_rakumaCtrl.text),
          listingUrl: _rakumaUrlCtrl.text.trim().isEmpty
              ? null
              : _rakumaUrlCtrl.text.trim(),
          listedAt: widget.product!.rakumaPrice.listedAt,
          isSold: widget.product!.rakumaPrice.isSold,
        ),
        status: _status,
        memo: _memoCtrl.text.trim().isEmpty ? null : _memoCtrl.text.trim(),
        tags: tags,
      );
      await ref.read(productListProvider.notifier).updateProduct(product);
    } else {
      product = Product(
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        category: _category,
        condition: _condition,
        purchasePrice: int.tryParse(_purchaseCtrl.text) ?? 0,
        imagePaths: _imagePaths,
        mercariPrice: PlatformPrice(
          platform: 'メルカリ',
          price: int.tryParse(_mercariCtrl.text),
          listingUrl: _mercariUrlCtrl.text.trim().isEmpty
              ? null
              : _mercariUrlCtrl.text.trim(),
        ),
        rakumaPrice: PlatformPrice(
          platform: 'ラクマ',
          price: int.tryParse(_rakumaCtrl.text),
          listingUrl: _rakumaUrlCtrl.text.trim().isEmpty
              ? null
              : _rakumaUrlCtrl.text.trim(),
        ),
        status: _status,
        memo: _memoCtrl.text.trim().isEmpty ? null : _memoCtrl.text.trim(),
        tags: tags,
      );
      await ref.read(productListProvider.notifier).addProduct(product);
    }

    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.product != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? '商品を編集' : '商品を追加'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            TextButton(
              onPressed: _save,
              child: const Text('保存', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SectionHeader('基本情報'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: '商品名 *',
                prefixIcon: Icon(Icons.label_outline),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? '商品名を入力してください' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: '商品説明',
                prefixIcon: Icon(Icons.description_outlined),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<ProductCategory>(
              value: _category,
              decoration: const InputDecoration(
                labelText: 'カテゴリ',
                prefixIcon: Icon(Icons.category_outlined),
              ),
              items: ProductCategory.values
                  .map((c) => DropdownMenuItem(value: c, child: Text(c.label)))
                  .toList(),
              onChanged: (v) => setState(() => _category = v!),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<ProductCondition>(
              value: _condition,
              decoration: const InputDecoration(
                labelText: '商品の状態',
                prefixIcon: Icon(Icons.stars_outlined),
              ),
              items: ProductCondition.values
                  .map((c) => DropdownMenuItem(
                        value: c,
                        child: Text('${c.rank}  ${c.label}'),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _condition = v!),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _purchaseCtrl,
              decoration: const InputDecoration(
                labelText: '仕入れ価格（円）',
                prefixIcon: Icon(Icons.shopping_cart_outlined),
                suffixText: '円',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 20),

            _SectionHeader('価格比較'),
            const SizedBox(height: 8),
            _PlatformPriceField(
              platform: 'メルカリ',
              color: AppTheme.mercariColor,
              icon: Icons.storefront,
              priceCtrl: _mercariCtrl,
              urlCtrl: _mercariUrlCtrl,
            ),
            const SizedBox(height: 12),
            _PlatformPriceField(
              platform: 'ラクマ',
              color: AppTheme.rakumaColor,
              icon: Icons.store,
              priceCtrl: _rakumaCtrl,
              urlCtrl: _rakumaUrlCtrl,
            ),
            _buildProfitPreview(),
            const SizedBox(height: 20),

            _SectionHeader('写真'),
            const SizedBox(height: 8),
            _ImageGrid(
              imagePaths: _imagePaths,
              onAdd: _pickImage,
              onRemove: (i) => setState(() => _imagePaths.removeAt(i)),
            ),
            const SizedBox(height: 20),

            _SectionHeader('管理情報'),
            const SizedBox(height: 8),
            DropdownButtonFormField<ListingStatus>(
              value: _status,
              decoration: const InputDecoration(
                labelText: '出品ステータス',
                prefixIcon: Icon(Icons.flag_outlined),
              ),
              items: ListingStatus.values
                  .map((s) => DropdownMenuItem(value: s, child: Text(s.label)))
                  .toList(),
              onChanged: (v) => setState(() => _status = v!),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _tagsCtrl,
              decoration: const InputDecoration(
                labelText: 'タグ（カンマ区切り）',
                prefixIcon: Icon(Icons.tag),
                hintText: 'ブランド名, カラー, サイズ...',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _memoCtrl,
              decoration: const InputDecoration(
                labelText: 'メモ',
                prefixIcon: Icon(Icons.note_outlined),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save),
              label: Text(isEdit ? '更新する' : '追加する'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildProfitPreview() {
    final mercari = int.tryParse(_mercariCtrl.text);
    final rakuma = int.tryParse(_rakumaCtrl.text);
    final purchase = int.tryParse(_purchaseCtrl.text) ?? 0;
    if (mercari == null && rakuma == null) return const SizedBox.shrink();

    int? best;
    String? bestPlatform;
    if (mercari != null && rakuma != null) {
      if (mercari >= rakuma) {
        best = mercari;
        bestPlatform = 'メルカリ';
      } else {
        best = rakuma;
        bestPlatform = 'ラクマ';
      }
    } else {
      best = mercari ?? rakuma;
      bestPlatform = mercari != null ? 'メルカリ' : 'ラクマ';
    }

    final profit = best! - purchase;
    final color = profit >= 0 ? AppTheme.profit : AppTheme.loss;

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('最高値: $bestPlatform', style: const TextStyle(fontSize: 12)),
              Text(formatCurrency(best),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('利益', style: TextStyle(fontSize: 12)),
              Text(
                formatProfit(profit),
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: color, fontSize: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
    );
  }
}

class _PlatformPriceField extends StatelessWidget {
  final String platform;
  final Color color;
  final IconData icon;
  final TextEditingController priceCtrl;
  final TextEditingController urlCtrl;

  const _PlatformPriceField({
    required this.platform,
    required this.color,
    required this.icon,
    required this.priceCtrl,
    required this.urlCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: color.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(10),
        color: color.withOpacity(0.04),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Text(
                platform,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: priceCtrl,
            decoration: InputDecoration(
              labelText: '販売価格（円）',
              suffixText: '円',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: urlCtrl,
            decoration: InputDecoration(
              labelText: '出品URL（任意）',
              prefixIcon: const Icon(Icons.link, size: 18),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            keyboardType: TextInputType.url,
          ),
        ],
      ),
    );
  }
}

class _ImageGrid extends StatelessWidget {
  final List<String> imagePaths;
  final VoidCallback onAdd;
  final void Function(int) onRemove;

  const _ImageGrid({
    required this.imagePaths,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: imagePaths.length + 1,
      itemBuilder: (_, i) {
        if (i == imagePaths.length) {
          return GestureDetector(
            onTap: onAdd,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: Colors.grey.shade300, style: BorderStyle.solid),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate_outlined, color: Colors.grey),
                  SizedBox(height: 4),
                  Text('写真追加', style: TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
          );
        }
        return Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                File(imagePaths[i]),
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: () => onRemove(i),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 16, color: Colors.white),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
