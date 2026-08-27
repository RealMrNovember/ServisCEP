import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/palette.dart';
import '../../app/theme.dart';
import '../../app/typography.dart';
import '../../core/database/app_database.dart';
import '../../core/utils/money.dart';
import '../../shared/skeleton.dart';
import '../../shared/tc_icon.dart';
import '../../shared/ui.dart';
import '../auth/data/session_controller.dart';
import 'barcode_scanner_screen.dart';
import 'data/products_repository.dart';
import 'product_form_screen.dart';

const _statusLabels = {
  StockStatus.inStock: 'Stokta',
  StockStatus.low: 'Az kaldı',
  StockStatus.outOfStock: 'Stokta yok',
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

  /// Seçili süzgeç: null = tümü, [_kritikFiltresi] = kritik stok,
  /// diğer her değer bir ürün kategorisi.
  String? _filtre;

  /// Kategori adıyla çakışmayacak bir işaret.
  static const _kritikFiltresi = '\u0000kritik';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _scanAndFind() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (code == null || !mounted) return;

    final companyId = ref
        .read(sessionControllerProvider)
        .valueOrNull
        ?.companyId;
    if (companyId == null) return;

    final repo = ref.read(productsRepositoryProvider);
    final existing = await repo.findByBarcode(companyId, code);

    if (!mounted) return;

    if (existing != null) {
      if (widget.selectionMode) {
        Navigator.of(context).pop(existing);
      } else {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ProductFormScreen(existing: existing),
          ),
        );
      }
      return;
    }

    final globalResult = await repo.lookupGlobalBarcode(code);
    if (!mounted) return;

    Navigator.of(context).push(
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
    final palet = context.palette;
    final productsAsync = ref.watch(productsListProvider);
    final products = productsAsync.valueOrNull ?? const <Product>[];

    final kritikSayisi = products
        .where((p) => p.stockStatus != StockStatus.inStock)
        .length;
    final kategoriler =
        products
            .map((p) => (p.category ?? '').trim())
            .where((c) => c.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.selectionMode ? 'Ürün Seç' : 'Stok'),
        bottom: products.isEmpty
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(20),
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: AppSpacing.xl,
                    right: AppSpacing.xl,
                    bottom: AppSpacing.sm,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${products.length} ürün',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: palet.textMuted),
                    ),
                  ),
                ),
              ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Ürün adı veya barkod',
                      prefixIcon: Icon(Icons.search),
                      filled: true,
                      isDense: true,
                    ),
                    onChanged: (v) =>
                        setState(() => _query = v.trim().toLowerCase()),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: _scanAndFind,
                  icon: const TcIcon(TcIcons.barcode, size: 18),
                  label: const Text('Barkod'),
                ),
              ],
            ),
          ),

          // Süzgeçler: "Kritik" en önemlisi ve sayısıyla birlikte —
          // kullanıcı stoğa çoğunlukla "neyim bitti" diye bakıyor.
          if (products.isNotEmpty)
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.xs,
                ),
                children: [
                  ChoiceChip(
                    label: const Text('Tümü'),
                    selected: _filtre == null,
                    onSelected: (_) => setState(() => _filtre = null),
                  ),
                  if (kritikSayisi > 0)
                    Padding(
                      padding: const EdgeInsets.only(left: AppSpacing.sm),
                      child: ChoiceChip(
                        label: Text('Kritik · $kritikSayisi'),
                        selected: _filtre == _kritikFiltresi,
                        onSelected: (_) =>
                            setState(() => _filtre = _kritikFiltresi),
                      ),
                    ),
                  for (final kategori in kategoriler)
                    Padding(
                      padding: const EdgeInsets.only(left: AppSpacing.sm),
                      child: ChoiceChip(
                        label: Text(kategori),
                        selected: _filtre == kategori,
                        onSelected: (_) => setState(() => _filtre = kategori),
                      ),
                    ),
                ],
              ),
            ),

          Expanded(
            child: productsAsync.when(
              loading: () => const AppSkeleton(count: 6),
              error: (_, _) => AppErrorState(
                message: 'Stok listesi yüklenemedi.',
                onRetry: () => ref.invalidate(productsListProvider),
              ),
              data: (products) {
                if (products.isEmpty) {
                  return _EmptyState(
                    onAdd: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ProductFormScreen(),
                      ),
                    ),
                    onScan: _scanAndFind,
                  );
                }

                final filtered = products.where(_uyuyor).toList();
                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      'Sonuç bulunamadı',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: palet.textMuted),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.xs,
                    AppSpacing.lg,
                    100,
                  ),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final product = filtered[index];
                    return _ProductTile(
                      product: product,
                      onTap: () {
                        if (widget.selectionMode) {
                          Navigator.of(context).pop(product);
                        } else {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  ProductFormScreen(existing: product),
                            ),
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
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProductFormScreen()),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Yeni Ürün'),
            ),
    );
  }

  bool _uyuyor(Product p) {
    if (_filtre == _kritikFiltresi) {
      if (p.stockStatus == StockStatus.inStock) return false;
    } else if (_filtre != null && (p.category ?? '').trim() != _filtre) {
      return false;
    }
    if (_query.isEmpty) return true;
    return p.name.toLowerCase().contains(_query) ||
        (p.barcode ?? '').contains(_query);
  }
}

/// Ürün satırı — tasarım teslimatı ekran 26.
///
/// Barkod tek aralıklı ve adın hemen altında: depoda ürünü elindeki
/// etiketten arayan kullanıcı rakamları hane hane karşılaştırıyor.
class _ProductTile extends StatelessWidget {
  const _ProductTile({required this.product, required this.onTap});
  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palet = context.palette;
    final durum = product.stockStatus;
    final renk = switch (durum) {
      StockStatus.inStock => palet.textMuted,
      StockStatus.low => palet.warningText,
      StockStatus.outOfStock => palet.dangerText,
    };

    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: Theme.of(context).textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _altSatir(product),
                  style: AppTypography.mono.copyWith(
                    fontSize: 12,
                    color: palet.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${product.currentStock} ${product.unit}',
                style: AppTypography.mono.copyWith(fontSize: 15, color: renk),
              ),
              if (durum != StockStatus.inStock) ...[
                const SizedBox(height: 2),
                Text(
                  _statusLabels[durum]!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: renk, fontSize: 11),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// Barkod varsa barkod, yoksa marka ve satış fiyatı.
  static String _altSatir(Product p) {
    final barkod = (p.barcode ?? '').trim();
    if (barkod.isNotEmpty) return barkod;
    return [
      if (p.brand?.trim().isNotEmpty == true) p.brand!.trim(),
      Money.formatMinor(p.salePriceMinor),
    ].join(' · ');
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
            Icon(
              Icons.inventory_2_outlined,
              size: 56,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'Stokta ürün yok',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Barkod tarayarak veya elle ekleyerek başla.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
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
                FilledButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add),
                  label: const Text('Ekle'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
