import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/utils/money.dart';
import '../auth/data/session_controller.dart';
import 'barcode_scanner_screen.dart';
import 'data/products_repository.dart';
import 'product_form_screen.dart';

const _statusLabels = {
  StockStatus.inStock: 'Stokta',
  StockStatus.low: 'Az kaldı',
  StockStatus.outOfStock: 'Stokta yok',
};

const _statusColors = {
  StockStatus.inStock: Colors.green,
  StockStatus.low: Colors.orange,
  StockStatus.outOfStock: Colors.red,
};

/// Ürün / stok listesi — bkz. docs/16-stok-ve-barkod.md.
///
/// [selectionMode] true ise (teklif/proforma kalem seçiminden çağrıldığında)
/// dokunma, ürünü seçip geri döner; false ise normal stok yönetim ekranıdır.
class ProductsListScreen extends ConsumerStatefulWidget {
  const ProductsListScreen({super.key, this.selectionMode = false});

  final bool selectionMode;

  @override
  ConsumerState<ProductsListScreen> createState() => _ProductsListScreenState();
}

class _ProductsListScreenState extends ConsumerState<ProductsListScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _scanAndFind() async {
    final code = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()));
    if (code == null || !mounted) return;

    final companyId = ref.read(sessionControllerProvider).valueOrNull?.companyId;
    if (companyId == null) return;

    final repo = ref.read(productsRepositoryProvider);
    final existing = await repo.findByBarcode(companyId, code);

    if (!mounted) return;

    if (existing != null) {
      if (widget.selectionMode) {
        Navigator.of(context).pop(existing);
      } else {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => ProductFormScreen(existing: existing)));
      }
      return;
    }

    final globalResult = await repo.lookupGlobalBarcode(code);
    if (!mounted) return;

    Navigator.of(
      context,
    ).push(
      MaterialPageRoute(
        builder: (_) => ProductFormScreen(
          prefilledBarcode: code,
          prefilledName: globalResult?.name,
          prefilledBrand: globalResult?.brand,
          prefilledCategory: globalResult?.category,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsListProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(widget.selectionMode ? 'Ürün Seç' : 'Stok')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Ürün ara (isim, barkod)...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                    ),
                    onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: _scanAndFind,
                  icon: const Icon(Icons.qr_code_scanner),
                  tooltip: 'Barkod Tara',
                ),
              ],
            ),
          ),
          Expanded(
            child: productsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Bir hata oluştu: $e')),
              data: (products) {
                final filtered = _query.isEmpty
                    ? products
                    : products
                          .where(
                            (p) =>
                                p.name.toLowerCase().contains(_query) ||
                                (p.barcode ?? '').contains(_query),
                          )
                          .toList();

                if (products.isEmpty) {
                  return _EmptyState(
                    onAdd: () => Navigator.of(
                      context,
                    ).push(MaterialPageRoute(builder: (_) => const ProductFormScreen())),
                    onScan: _scanAndFind,
                  );
                }
                if (filtered.isEmpty) {
                  return Center(
                    child: Text('Sonuç bulunamadı', style: TextStyle(color: scheme.onSurfaceVariant)),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 100),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final product = filtered[index];
                    return _ProductTile(
                      product: product,
                      onTap: () {
                        if (widget.selectionMode) {
                          Navigator.of(context).pop(product);
                        } else {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => ProductFormScreen(existing: product)),
                          );
                        }
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: widget.selectionMode
          ? null
          : FloatingActionButton.extended(
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const ProductFormScreen())),
              icon: const Icon(Icons.add),
              label: const Text('Yeni Ürün'),
            ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({required this.product, required this.onTap});
  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = product.stockStatus;
    final color = _statusColors[status]!;

    return Card(
      child: ListTile(
        onTap: onTap,
        title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          [
            if (product.brand?.isNotEmpty == true) product.brand!,
            Money.formatMinor(product.salePriceMinor),
          ].join(' · '),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                _statusLabels[status]!,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
              ),
            ),
            const SizedBox(height: 4),
            Text('${product.currentStock} ${product.unit}', style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd, required this.onScan});
  final VoidCallback onAdd;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inventory_2_outlined, size: 56, color: scheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              'Stokta ürün yok',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Barkod tarayarak veya elle ekleyerek başla.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton.icon(
                  onPressed: onScan,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Barkod Tara'),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: const Text('Ekle')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
