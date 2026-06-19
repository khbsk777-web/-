import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/product.dart';
import '../services/database_service.dart';

final productListProvider =
    AsyncNotifierProvider<ProductListNotifier, List<Product>>(
        ProductListNotifier.new);

class ProductListNotifier extends AsyncNotifier<List<Product>> {
  @override
  Future<List<Product>> build() async {
    return DatabaseService.instance.getAllProducts();
  }

  Future<void> addProduct(Product product) async {
    await DatabaseService.instance.insertProduct(product);
    ref.invalidateSelf();
  }

  Future<void> updateProduct(Product product) async {
    await DatabaseService.instance.updateProduct(product);
    ref.invalidateSelf();
  }

  Future<void> deleteProduct(String id) async {
    await DatabaseService.instance.deleteProduct(id);
    ref.invalidateSelf();
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
  }
}

final statsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  ref.watch(productListProvider);
  return DatabaseService.instance.getStats();
});

final filterStatusProvider = StateProvider<ListingStatus?>((ref) => null);
final searchQueryProvider = StateProvider<String>((ref) => '');
final filterCategoryProvider = StateProvider<ProductCategory?>((ref) => null);

final filteredProductsProvider = Provider<AsyncValue<List<Product>>>((ref) {
  final productsAsync = ref.watch(productListProvider);
  final status = ref.watch(filterStatusProvider);
  final query = ref.watch(searchQueryProvider);
  final category = ref.watch(filterCategoryProvider);

  return productsAsync.whenData((products) {
    var filtered = products;
    if (status != null) {
      filtered = filtered.where((p) => p.status == status).toList();
    }
    if (category != null) {
      filtered = filtered.where((p) => p.category == category).toList();
    }
    if (query.isNotEmpty) {
      final q = query.toLowerCase();
      filtered = filtered
          .where((p) =>
              p.name.toLowerCase().contains(q) ||
              p.description.toLowerCase().contains(q) ||
              p.tags.any((t) => t.toLowerCase().contains(q)))
          .toList();
    }
    return filtered;
  });
});
