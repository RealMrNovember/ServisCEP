import 'package:flutter/material.dart';

import '../app/palette.dart';
import '../app/theme.dart';
import '../app/typography.dart';
import '../core/database/app_database.dart';
import '../core/models/doc_item_draft.dart';
import '../core/utils/money.dart';
import '../features/stock/products_list_screen.dart';
import 'tc_icon.dart';
import 'ui.dart';

/// Teklif/Proforma kalemlerini düzenleme — hem Quote hem Proforma
/// formlarında ortak kullanılır. Bkz. docs/16 § Teklif / Proforma Kalem
/// Seçimi: kullanıcı stoktan seçebilir veya serbest metin girebilir.
///
/// Para birimi ve KDV kipi belgeye aittir, kaleme değil; editör bunları
/// yalnızca doğru göstermek için alır — kullanıcı yalnızca birim fiyat
/// girer, çarpımı ve KDV'yi sistem yapar.
class DocumentItemsEditor extends StatefulWidget {
  const DocumentItemsEditor({
    super.key,
    required this.items,
    required this.onChanged,
    this.currency = Currency.try_,
    this.vatMode = VatMode.excluded,
    this.defaultVatRate = 20,
  });

  final List<DocItemDraft> items;
  final ValueChanged<List<DocItemDraft>> onChanged;
  final Currency currency;
  final VatMode vatMode;
  final int defaultVatRate;

  @override
  State<DocumentItemsEditor> createState() => _DocumentItemsEditorState();
}

class _DocumentItemsEditorState extends State<DocumentItemsEditor> {
  Future<void> _addFromStock() async {
    final product = await Navigator.of(context).push<Product>(
      MaterialPageRoute(
        builder: (_) => const ProductsListScreen(selectionMode: true),
      ),
    );
    if (product == null) return;
    _addItem(
      DocItemDraft(
        description: product.name,
        productId: product.id,
        unit: product.unit,
        unitPriceMinor: product.salePriceMinor,
        taxRate: widget.defaultVatRate,
      ),
    );
  }

  Future<void> _addManual() async {
    final draft = await _showItemSheet();
    if (draft != null) _addItem(draft);
  }

  void _addItem(DocItemDraft draft) {
    widget.onChanged([...widget.items, draft]);
  }

  Future<void> _editItem(int index) async {
    final updated = await _showItemSheet(existing: widget.items[index]);
    if (updated == null) return;
    final list = [...widget.items];
    list[index] = updated;
    widget.onChanged(list);
  }

  void _removeItem(int index) {
    final list = [...widget.items]..removeAt(index);
    widget.onChanged(list);
  }

  Future<DocItemDraft?> _showItemSheet({DocItemDraft? existing}) {
    return showModalBottomSheet<DocItemDraft>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ItemSheet(
        existing: existing,
        currency: widget.currency,
        vatMode: widget.vatMode,
        defaultVatRate: widget.defaultVatRate,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totals = DocumentTotals.from(
      widget.items.map((item) => item.amounts(widget.vatMode)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          'Kalemler',
          subtitle: widget.items.isEmpty
              ? 'Stoktan seç ya da serbest satır ekle.'
              : '${widget.items.length} kalem',
        ),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _addFromStock,
                icon: const Icon(Icons.inventory_2_outlined, size: 18),
                label: const Text('Stoktan'),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: FilledButton.icon(
                onPressed: _addManual,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Serbest satır'),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),

        if (widget.items.isEmpty)
          AppCard(
            child: Row(
              children: [
                Icon(
                  Icons.playlist_add_outlined,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'Henüz kalem yok. Eklediğin her satırın toplamı ve KDV\'si '
                    'otomatik hesaplanır.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          for (var i = 0; i < widget.items.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _ItemTile(
                index: i + 1,
                item: widget.items[i],
                currency: widget.currency,
                vatMode: widget.vatMode,
                onTap: () => _editItem(i),
                onRemove: () => _removeItem(i),
              ),
            ),

        if (widget.items.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          DocumentTotalsCard(
            totals: totals,
            currency: widget.currency,
            vatMode: widget.vatMode,
          ),
        ],
      ],
    );
  }
}

/// Kapalı kalem satırı — tasarım teslimatı ekran 13.
///
/// Tasarımda satır yerinde açılıp 3 sütunlu bir ızgaraya dönüşüyor; burada
/// düzenleme mevcut [_ItemSheet] alt sayfasında açılıyor. İkisi de aynı
/// sorunu (7 alanın dar ekrana sığmaması) çözüyor ve alt sayfa klavye
/// açıldığında kırpılmıyor — bu yüzden çalışan çözüm korundu.
class _ItemTile extends StatelessWidget {
  const _ItemTile({
    required this.index,
    required this.item,
    required this.currency,
    required this.vatMode,
    required this.onTap,
    required this.onRemove,
  });

  final int index;
  final DocItemDraft item;
  final Currency currency;
  final VatMode vatMode;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final palet = context.palette;
    final amounts = item.amounts(vatMode);

    return AppCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
      ),
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: palet.accent.withValues(alpha: 0.12),
              borderRadius: AppRadius.field,
            ),
            child: Text(
              '$index',
              style: AppTypography.mono.copyWith(
                fontSize: 12,
                color: palet.accent,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.description,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 3),
                Text(
                  _altSatir(),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: palet.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                Money.formatMinor(amounts.grossMinor, currency: currency),
                style: AppTypography.mono.copyWith(fontSize: 14),
              ),
              SizedBox(
                height: 28,
                width: 28,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  iconSize: 16,
                  tooltip: 'Kalemi sil',
                  icon: const TcIcon(TcIcons.x, size: 16),
                  onPressed: onRemove,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// "40 m × ₺30,00 · KDV %20 · %10 iskonto" — iskonto yalnızca varsa.
  String _altSatir() {
    final parcalar = <String>[
      '${item.quantity} ${item.unit} × '
          '${Money.formatMinor(item.unitPriceMinor, currency: currency)}',
      'KDV %${item.taxRate}',
    ];
    if (item.discountMinor > 0) {
      parcalar.add(
        '${Money.formatMinor(item.discountMinor, currency: currency)} iskonto',
      );
    }
    return parcalar.join('  ·  ');
  }
}

/// Belge toplamları — form önizlemesinde ve detay ekranında aynı kutu.
class DocumentTotalsCard extends StatelessWidget {
  const DocumentTotalsCard({
    super.key,
    required this.totals,
    required this.currency,
    required this.vatMode,
  });

  final DocumentTotals totals;
  final Currency currency;
  final VatMode vatMode;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palet = context.palette;

    Widget row(
      String label,
      int amount, {
      bool strong = false,
      bool negatif = false,
      Color? renk,
    }) {
      final metin = Money.formatMinor(amount, currency: currency);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: strong ? 15 : 13,
                fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
                color: strong ? scheme.onSurface : scheme.onSurfaceVariant,
              ),
            ),
            Text(
              negatif ? '−$metin' : metin,
              style: (strong ? AppTypography.monoLarge : AppTypography.mono)
                  .copyWith(
                    fontSize: strong ? 19 : 13.5,
                    color: renk ?? (strong ? scheme.primary : null),
                  ),
            ),
          ],
        ),
      );
    }

    return AppCard(
      accent: true,
      child: Column(
        children: [
          row('Ara toplam', totals.netMinor),
          // İskonto satırı yalnızca gerçekten indirim varsa çizilir:
          // sıfır yazan bir satır kullanıcıya bir şey söylemiyor.
          if (totals.discountMinor > 0)
            row(
              'Toplam iskonto',
              totals.discountMinor,
              negatif: true,
              renk: palet.successText,
            ),
          row('KDV', totals.vatMinor),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Divider(
              height: 1,
              color: scheme.primary.withValues(alpha: 0.25),
            ),
          ),
          row('Genel toplam', totals.grossMinor, strong: true),
          const SizedBox(height: 2),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${vatMode.label}  ·  ${currency.label}',
              style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kalem ekleme/düzenleme sayfası. Diyalog yerine alt sayfa: klavye
/// açıldığında diyalog içerikleri kırpılıyordu ve saha kullanımında
/// alt sayfa tek elle daha rahat.
class _ItemSheet extends StatefulWidget {
  const _ItemSheet({
    required this.existing,
    required this.currency,
    required this.vatMode,
    required this.defaultVatRate,
  });

  final DocItemDraft? existing;
  final Currency currency;
  final VatMode vatMode;
  final int defaultVatRate;

  @override
  State<_ItemSheet> createState() => _ItemSheetState();
}

class _ItemSheetState extends State<_ItemSheet> {
  late final _descController = TextEditingController(
    text: widget.existing?.description ?? '',
  );
  late final _qtyController = TextEditingController(
    text: (widget.existing?.quantity ?? 1).toString(),
  );
  late final _unitController = TextEditingController(
    text: widget.existing?.unit ?? 'adet',
  );
  late final _priceController = TextEditingController(
    text: widget.existing == null
        ? ''
        : (widget.existing!.unitPriceMinor / 100).toStringAsFixed(2),
  );
  late final _discountController = TextEditingController(
    text: (widget.existing?.discountMinor ?? 0) == 0
        ? ''
        : (widget.existing!.discountMinor / 100).toStringAsFixed(2),
  );
  late int _vatRate = widget.existing?.taxRate ?? widget.defaultVatRate;

  @override
  void initState() {
    super.initState();
    // Canlı önizleme: kullanıcı fiyatı yazarken satır toplamını görsün.
    for (final controller in [
      _qtyController,
      _priceController,
      _discountController,
    ]) {
      controller.addListener(_refresh);
    }
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    for (final controller in [
      _descController,
      _qtyController,
      _unitController,
      _priceController,
      _discountController,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  DocItemDraft _draft() => DocItemDraft(
    description: _descController.text.trim(),
    productId: widget.existing?.productId,
    quantity: int.tryParse(_qtyController.text.trim()) ?? 1,
    unit: _unitController.text.trim().isEmpty
        ? 'adet'
        : _unitController.text.trim(),
    unitPriceMinor: Money.parseToMinor(_priceController.text),
    taxRate: _vatRate,
    discountMinor: Money.parseToMinor(_discountController.text),
  );

  void _save() {
    if (_descController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Açıklama boş olamaz.')));
      return;
    }
    Navigator.pop(context, _draft());
  }

  @override
  Widget build(BuildContext context) {
    final preview = _draft().amounts(widget.vatMode);

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.xl,
        right: AppSpacing.xl,
        top: AppSpacing.sm,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.existing == null ? 'Kalem ekle' : 'Kalemi düzenle',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _descController,
              autofocus: widget.existing == null,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Açıklama',
                hintText: 'Ürün veya hizmet adı',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _qtyController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Miktar'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: TextField(
                    controller: _unitController,
                    decoration: const InputDecoration(labelText: 'Birim'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _priceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Birim fiyat',
                      prefixText: '${widget.currency.symbol} ',
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: TextField(
                    controller: _discountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'İskonto',
                      prefixText: '${widget.currency.symbol} ',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'KDV oranı',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                for (final rate in const [0, 1, 10, 20])
                  ChoiceChip(
                    label: Text('%$rate'),
                    selected: _vatRate == rate,
                    onSelected: (_) => setState(() => _vatRate = rate),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            AppCard(
              accent: true,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Satır toplamı (${widget.vatMode.label})',
                    style: const TextStyle(fontSize: 13),
                  ),
                  Text(
                    Money.formatMinor(
                      preview.grossMinor,
                      currency: widget.currency,
                    ),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Vazgeç'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: _save,
                    child: const Text('Kaydet'),
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
