import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/product.dart';
import '../providers/product_provider.dart';
import '../widgets/product_card.dart';
import 'product_detail_screen.dart';
import 'product_form_screen.dart';
import 'stats_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tabIndex,
        children: const [
          _ProductListTab(),
          StatsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: '商品管理',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: '統計',
          ),
        ],
      ),
      floatingActionButton: _tabIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProductFormScreen()),
              ),
              icon: const Icon(Icons.add),
              label: const Text('商品追加'),
            )
          : null,
    );
  }
}

class _ProductListTab extends ConsumerStatefulWidget {
  const _ProductListTab();

  @override
  ConsumerState<_ProductListTab> createState() => _ProductListTabState();
}

class _ProductListTabState extends ConsumerState<_ProductListTab> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredAsync = ref.watch(filteredProductsProvider);
    final selectedStatus = ref.watch(filterStatusProvider);
    final selectedCategory = ref.watch(filterCategoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('フリマ商品管理'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: '商品名・説明・タグで検索',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          ref.read(searchQueryProvider.notifier).state = '';
                        },
                      )
                    : null,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (v) =>
                  ref.read(searchQueryProvider.notifier).state = v,
            ),
          ),
        ),
        actions: [
          PopupMenuButton<ListingStatus?>(
            icon: Badge(
              isLabelVisible: selectedStatus != null,
              child: const Icon(Icons.filter_list),
            ),
            tooltip: 'ステータスで絞り込み',
            initialValue: selectedStatus,
            onSelected: (v) =>
                ref.read(filterStatusProvider.notifier).state = v,
            itemBuilder: (_) => [
              const PopupMenuItem(value: null, child: Text('すべて')),
              ...ListingStatus.values.map(
                (s) => PopupMenuItem(value: s, child: Text(s.label)),
              ),
            ],
          ),
          PopupMenuButton<ProductCategory?>(
            icon: Badge(
              isLabelVisible: selectedCategory != null,
              child: const Icon(Icons.category_outlined),
            ),
            tooltip: 'カテゴリで絞り込み',
            initialValue: selectedCategory,
            onSelected: (v) =>
                ref.read(filterCategoryProvider.notifier).state = v,
            itemBuilder: (_) => [
              const PopupMenuItem(value: null, child: Text('すべて')),
              ...ProductCategory.values.map(
                (c) => PopupMenuItem(value: c, child: Text(c.label)),
              ),
            ],
          ),
        ],
      ),
      body: filteredAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('エラー: $e')),
        data: (products) {
          if (products.isEmpty) {
            return _EmptyState(
              hasFilter: selectedStatus != null ||
                  selectedCategory != null ||
                  _searchCtrl.text.isNotEmpty,
            );
          }
          return RefreshIndicator(
            onRefresh: () =>
                ref.read(productListProvider.notifier).refresh(),
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 80),
              itemCount: products.length,
              itemBuilder: (_, i) => ProductCard(
                product: products[i],
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ProductDetailScreen(product: products[i]),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasFilter;
  const _EmptyState({required this.hasFilter});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasFilter ? Icons.search_off : Icons.inventory_2_outlined,
            size: 72,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            hasFilter ? '条件に一致する商品がありません' : 'まだ商品がありません',
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: Colors.grey),
          ),
          if (!hasFilter) ...[
            const SizedBox(height: 8),
            const Text('右下のボタンから商品を追加しましょう',
                style: TextStyle(color: Colors.grey)),
          ],
        ],
      ),
    );
  }
}
