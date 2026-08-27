import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../app/theme.dart';
import '../../app/typography.dart';
import '../../core/utils/money.dart';
import '../auth/data/session_controller.dart';
import 'barcode_scanner_screen.dart';
import '../../shared/tc_icon.dart';
import '../../shared/ui.dart';
import 'data/products_repository.dart';

/// Ürün oluşturma / düzenleme — bkz. docs/16-stok-ve-barkod.md.
class ProductFormScreen extends ConsumerStatefulWidget {
  const ProductFormScreen({
    super.key,
    this.existing,
    this.prefilledBarcode,
    this.prefilledName,
    this.prefilledBrand,
    this.prefilledCategory,
  });

  final Product? existing;
  final String? prefilledBarcode;
  final String? prefilledName;
  final String? prefilledBrand;
  final String? prefilledCategory;

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: widget.existing?.name ?? widget.prefilledName ?? '',
  );
  late final _barcodeController = TextEditingController(
    text: widget.existing?.barcode ?? widget.prefilledBarcode ?? '',
  );
  late final _brandController = TextEditingController(
    text: widget.existing?.brand ?? widget.prefilledBrand ?? '',
  );
  late final _categoryController = TextEditingController(
    text: widget.existing?.category ?? widget.prefilledCategory ?? '',
  );
  late final _unitController = TextEditingController(
    text: widget.existing?.unit ?? 'adet',
  );
  late final _salePriceController = TextEditingController(
    text: widget.existing != null
        ? (widget.existing!.salePriceMinor / 100).toString()
        : '',
  );
  late final _purchasePriceController = TextEditingController(
    text: widget.existing != null
        ? (widget.existing!.purchasePriceMinor / 100).toString()
        : '',
  );
  late final _stockController = TextEditingController(
    text: widget.existing?.currentStock.toString() ?? '0',
  );
  late final _minStockController = TextEditingController(
    text: widget.existing?.minStock.toString() ?? '0',
  );

  bool _isSubmitting = false;

  bool get _isEditing => widget.existing != null;

  @override
  void dispose() {
    _nameController.dispose();
    _barcodeController.dispose();
    _brandController.dispose();
    _categoryController.dispose();
    _unitController.dispose();
    _salePriceController.dispose();
    _purchasePriceController.dispose();
    _stockController.dispose();
    _minStockController.dispose();
    super.dispose();
  }

  Future<void> _scanBarcode() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (code != null) setState(() => _barcodeController.text = code);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    final repo = ref.read(productsRepositoryProvider);
    try {
      if (_isEditing) {
        final updated = widget.existing!.copyWith(
          name: _nameController.text.trim(),
          barcode: Value(_emptyToNull(_barcodeController.text)),
          brand: Value(_emptyToNull(_brandController.text)),
          category: Value(_emptyToNull(_categoryController.text)),
          unit: _unitController.text.trim().isEmpty
              ? 'adet'
              : _unitController.text.trim(),
          salePriceMinor: Money.parseToMinor(_salePriceController.text),
          purchasePriceMinor: Money.parseToMinor(_purchasePriceController.text),
          currentStock: int.tryParse(_stockController.text) ?? 0,
          minStock: int.tryParse(_minStockController.text) ?? 0,
        );
        await repo.update(updated);
      } else {
        final session = ref.read(sessionControllerProvider).valueOrNull;
        if (session == null) return;
        await repo.create(
          companyId: session.companyId,
          name: _nameController.text.trim(),
          barcode: _emptyToNull(_barcodeController.text),
          brand: _emptyToNull(_brandController.text),
          category: _emptyToNull(_categoryController.text),
          unit: _unitController.text.trim().isEmpty
              ? 'adet'
              : _unitController.text.trim(),
          salePriceMinor: Money.parseToMinor(_salePriceController.text),
          purchasePriceMinor: Money.parseToMinor(_purchasePriceController.text),
          currentStock: int.tryParse(_stockController.text) ?? 0,
          minStock: int.tryParse(_minStockController.text) ?? 0,
          source: widget.prefilledName != null ? 'GLOBAL_LOOKUP' : 'MANUAL',
        );
      }
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String? _emptyToNull(String v) => v.trim().isEmpty ? null : v.trim();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Ürünü Düzenle' : 'Yeni Ürün')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Ürün adı'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Bu alan gerekli' : null,
            ),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _barcodeController,
              style: AppTypography.mono.copyWith(fontSize: 15),
              decoration: InputDecoration(
                labelText: 'Barkod',
                helperText: 'Zorunlu değil.',
                suffixIcon: IconButton(
                  icon: const TcIcon(TcIcons.barcode),
                  tooltip: 'Barkod tara',
                  onPressed: _scanBarcode,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _brandController,
                    decoration: const InputDecoration(labelText: 'Marka'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: TextFormField(
                    controller: _categoryController,
                    decoration: const InputDecoration(labelText: 'Kategori'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.xxl),
            const SectionHeader(
              'Fiyat',
              subtitle: 'Satış fiyatı tekliflere hazır gelir.',
            ),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _purchasePriceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Alış fiyatı',
                      prefixText: '₺ ',
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: TextFormField(
                    controller: _salePriceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Satış fiyatı',
                      prefixText: '₺ ',
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.xxl),
            const SectionHeader('Stok'),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _stockController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Stok miktarı',
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _unitController,
                    decoration: const InputDecoration(labelText: 'Birim'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _minStockController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Kritik stok uyarısı',
                helperText: 'Bu sayının altına düşünce uyarı gelir.',
                helperMaxLines: 2,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('İptal'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_isEditing ? 'Kaydet' : 'Ürünü Ekle'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
