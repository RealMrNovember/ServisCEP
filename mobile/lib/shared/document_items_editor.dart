import 'package:flutter/material.dart';

import '../core/database/app_database.dart';
import '../core/models/doc_item_draft.dart';
import '../core/utils/money.dart';
import '../features/stock/products_list_screen.dart';

/// Teklif/Proforma kalemlerini düzenleme — hem Quote hem Proforma
/// formlarında ortak kullanılır. Bkz. docs/16 § Teklif / Proforma Kalem
/// Seçimi: kullanıcı stoktan seçebilir veya serbest metin girebilir.
class DocumentItemsEditor extends StatefulWidget {
  const DocumentItemsEditor({super.key, required this.items, required this.onChanged});

  final List<DocItemDraft> items;
  final ValueChanged<List<DocItemDraft>> onChanged;

  @override
  State<DocumentItemsEditor> createState() => _DocumentItemsEditorState();
}

class _DocumentItemsEditorState extends State<DocumentItemsEditor> {
  Future<void> _addFromStock() async {
    final product = await Navigator.of(context).push<Product>(
      MaterialPageRoute(builder: (_) => const ProductsListScreen(selectionMode: true)),
    );
    if (product == null) return;
    _addItem(
      DocItemDraft(
        description: product.name,
        productId: product.id,
        unit: product.unit,
        unitPriceMinor: product.salePriceMinor,
      ),
    );
  }

  Future<void> _addManual() async {
    final draft = await _showItemDialog();
    if (draft != null) _addItem(draft);
  }

  void _addItem(DocItemDraft draft) {
    widget.onChanged([...widget.items, draft]);
  }

  Future<void> _editItem(int index) async {
    final updated = await _showItemDialog(existing: widget.items[index]);
    if (updated == null) return;
    final list = [...widget.items];
    list[index] = updated;
    widget.onChanged(list);
  }

  void _removeItem(int index) {
    final list = [...widget.items]..removeAt(index);
    widget.onChanged(list);
  }

  Future<DocItemDraft?> _showItemDialog({DocItemDraft? existing}) async {
    final descController = TextEditingController(text: existing?.description ?? '');
    final qtyController = TextEditingController(text: (existing?.quantity ?? 1).toString());
    final unitController = TextEditingController(text: existing?.unit ?? 'adet');
    final priceController = TextEditingController(
      text: existing != null ? (existing.unitPriceMinor / 100).toString() : '',
    );
    final taxController = TextEditingController(text: (existing?.taxRate ?? 20).toString());

    return showDialog<DocItemDraft>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? 'Kalem Ekle' : 'Kalemi Düzenle'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: descController,
                decoration: const InputDecoration(labelText: 'Açıklama'),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: qtyController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Miktar'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: unitController,
                      decoration: const InputDecoration(labelText: 'Birim'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: priceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Birim fiyat (₺)'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: taxController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'KDV %'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
          FilledButton(
            onPressed: () {
              if (descController.text.trim().isEmpty) return;
              Navigator.pop(
                context,
                DocItemDraft(
                  description: descController.text.trim(),
                  productId: existing?.productId,
                  quantity: int.tryParse(qtyController.text) ?? 1,
                  unit: unitController.text.trim().isEmpty ? 'adet' : unitController.text.trim(),
                  unitPriceMinor: Money.parseToMinor(priceController.text),
                  taxRate: int.tryParse(taxController.text) ?? 20,
                  discountMinor: existing?.discountMinor ?? 0,
                ),
              );
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final total = widget.items.fold<int>(0, (sum, item) => sum + item.lineTotalMinor);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Kalemler',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: _addFromStock,
              icon: const Icon(Icons.inventory_2_outlined, size: 16),
              label: const Text('Stoktan'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _addManual,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Serbest'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (widget.items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text('Henüz kalem eklenmedi', style: TextStyle(color: scheme.onSurfaceVariant)),
          )
        else
          for (var i = 0; i < widget.items.length; i++)
            Card(
              child: ListTile(
                onTap: () => _editItem(i),
                title: Text(widget.items[i].description),
                subtitle: Text(
                  '${widget.items[i].quantity} ${widget.items[i].unit} × '
                  '${Money.formatMinor(widget.items[i].unitPriceMinor)} '
                  '(KDV %${widget.items[i].taxRate})',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      Money.formatMinor(widget.items[i].lineTotalMinor),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => _removeItem(i),
                    ),
                  ],
                ),
              ),
            ),
        const Divider(height: 24),
        Row(
          children: [
            Text(
              'Genel Toplam',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            Text(
              Money.formatMinor(total),
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: scheme.primary),
            ),
          ],
        ),
      ],
    );
  }
}
