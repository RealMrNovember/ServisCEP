import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../core/database/app_database.dart';
import '../../core/models/doc_item_draft.dart';
import '../../core/utils/customer_display.dart';
import '../../core/services/pdf_service.dart';
import '../../core/utils/money.dart';
import '../auth/data/session_controller.dart';
import '../customers/data/customers_repository.dart';
import '../proformas/data/proformas_repository.dart';
import '../proformas/proforma_detail_screen.dart';
import '../quotes/data/quotes_repository.dart';
import '../quotes/quote_detail_screen.dart';
import '../settings/data/company_repository.dart';
import '../../core/utils/document_numbering.dart';
import '../../shared/customer_picker.dart';
import '../../shared/document_items_editor.dart';
import '../../shared/template_field.dart';
import '../../shared/ui.dart';

/// Geçerlilik için hazır gün seçenekleri.
const _quickValidityOptions = [1, 3, 7, 15, 30];

/// Belge türü.
///
/// Teklif formu ile proforma fatura, işletmenin gözünde aynı evrakın iki
/// adıdır: aynı müşteri, aynı kalemler, aynı KDV kuralları. Farkı yalnızca
/// başlığı ve numara serisidir. Bu yüzden ikisi tek formdan üretilir ve
/// kullanıcı hangisi olduğunu formun içinden seçer.
enum DocumentKind {
  quote('Teklif Formu', 'TKF'),
  proforma('Proforma Fatura', 'PRF');

  const DocumentKind(this.label, this.codePrefix);

  final String label;
  final String codePrefix;
}

/// Formun ürettiği belge taslağı.
class DocumentDraft {
  const DocumentDraft({
    required this.code,
    required this.customerId,
    required this.items,
    required this.currency,
    required this.vatMode,
    required this.vatRate,
    this.validUntil,
    this.notes,
    this.introText,
    this.paymentTerms,
    this.deliveryTime,
    this.warrantyTerms,
  });

  /// Belge numarası — kullanıcı değiştirebilir (bkz. DocumentNumbering).
  final String code;

  final String customerId;
  final List<DocItemDraft> items;
  final Currency currency;
  final VatMode vatMode;
  final int vatRate;
  final DateTime? validUntil;
  final String? notes;

  /// Belgeye yazılan metinler. Şirket varsayılanından kopyalanır, bu
  /// belgeye özel değiştirilebilir.
  final String? introText;
  final String? paymentTerms;
  final String? deliveryTime;
  final String? warrantyTerms;
}

/// Teklif ve proformanın ortak formu.
///
/// İki belge kullanıcı gözünde neredeyse aynı: aynı müşteri seçimi, aynı
/// kalemler, aynı KDV kuralları. Ayrı ayrı yazıldıklarında biri
/// iyileştirilip diğeri geride kalıyordu (teklifte para birimi vardı,
/// proformada yoktu). Tek form, ikisinin de aynı kalitede kalmasını
/// yapısal olarak garanti eder.
///
/// Alanların sırası belge kurma sırasına göredir: kime, hangi para
/// biriminde ve KDV kipinde, hangi kalemlerle, ne kadar süreyle.
class DocumentFormScreen extends ConsumerStatefulWidget {
  const DocumentFormScreen({
    super.key,
    this.initialKind = DocumentKind.quote,
    this.preselectedCustomerId,
  });

  /// Ekran hangi türle açıldı — kullanıcı formun içinden değiştirebilir.
  final DocumentKind initialKind;
  final String? preselectedCustomerId;

  @override
  ConsumerState<DocumentFormScreen> createState() => _DocumentFormScreenState();
}

class _DocumentFormScreenState extends ConsumerState<DocumentFormScreen> {
  static final _dateFormat = DateFormat('d MMMM y', 'tr_TR');

  late DocumentKind _kind = widget.initialKind;
  String? _customerId;
  final _codeController = TextEditingController();

  /// Kullanıcı numaraya dokunduysa tür değiştiğinde numarayı EZMEYİZ;
  /// elle girilmiş bir numaranın form üstünde kendiliğinden değişmesi
  /// güven kırıcı olur.
  bool _codeEdited = false;

  final _notesController = TextEditingController();
  final _vatRateController = TextEditingController(text: '20');
  final _introController = TextEditingController();
  final _paymentTermsController = TextEditingController();
  final _deliveryTimeController = TextEditingController();
  final _warrantyTermsController = TextEditingController();

  /// Şirket varsayılanları yalnızca BİR kez yüklenir; kullanıcı metni
  /// değiştirdikten sonra sağlayıcı yeniden tetiklendiğinde yazdıklarının
  /// üzerine geri yazılması kabul edilemez.
  bool _defaultsApplied = false;
  final List<DocItemDraft> _items = [];

  Currency _currency = Currency.try_;
  VatMode _vatMode = VatMode.excluded;

  /// Geçerlilik GÜN olarak sorulur, tarih olarak basılır.
  ///
  /// Kullanıcı "bu teklif kaç gün geçerli" sorusunun cevabını bilir;
  /// takvimden gün saymak zorunda kalması gereksiz bir yük. Seçilen gün
  /// sayısı belgenin düzenlendiği tarihe eklenir.
  int? _validityDays = 15;
  final _customDaysController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _customerId = widget.preselectedCustomerId;
    _codeController.addListener(() => _codeEdited = true);
    // İlk numara önerisi, kaydedilmiş son belgeden türetilir.
    WidgetsBinding.instance.addPostFrameCallback((_) => _suggestCode());
  }

  @override
  void dispose() {
    for (final controller in [
      _codeController,
      _customDaysController,
      _notesController,
      _vatRateController,
      _introController,
      _paymentTermsController,
      _deliveryTimeController,
      _warrantyTermsController,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Şirket ayarlarındaki metinleri forma taşır.
  void _applyCompanyDefaults(Company company) {
    if (_defaultsApplied) return;
    _defaultsApplied = true;

    _introController.text = company.introText?.trim().isNotEmpty == true
        ? company.introText!
        : PdfService.defaultIntro(_kind.label);
    _paymentTermsController.text = company.paymentTerms ?? '';
    _deliveryTimeController.text = company.deliveryTime ?? '';
    _warrantyTermsController.text = company.warrantyTerms ?? '';
  }

  String? _trimmed(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : value;
  }

  int get _vatRate {
    final parsed = int.tryParse(_vatRateController.text.trim());
    if (parsed == null || parsed < 0 || parsed > 100) return 20;
    return parsed;
  }

  /// Belge geneli KDV oranı değişince, oranı elle değiştirilmemiş kalemler
  /// de yeni orana çekilir — aksi halde kullanıcı oranı değiştirdiğini
  /// sanıp eski oranla belge gönderiyor.
  void _applyVatRateToItems(int previousRate, int newRate) {
    if (previousRate == newRate) return;
    setState(() {
      for (var i = 0; i < _items.length; i++) {
        if (_items[i].taxRate == previousRate) {
          _items[i] = _items[i].copyWith(taxRate: newRate);
        }
      }
    });
  }

  Future<void> _pickCustomer() async {
    final selected = await showCustomerPicker(context);
    if (selected != null) setState(() => _customerId = selected);
  }

  /// Gün sayısından hesaplanan geçerlilik tarihi.
  DateTime? get _validUntil {
    final days = _validityDays;
    if (days == null) return null;
    final today = DateTime.now();
    return DateTime(today.year, today.month, today.day + days);
  }

  void _setValidityDays(int? days) {
    setState(() {
      _validityDays = days;
      if (days == null || _quickValidityOptions.contains(days)) {
        _customDaysController.clear();
      }
    });
  }

  /// Seçili türün serisine göre sıradaki numarayı öner.
  Future<void> _suggestCode() async {
    final session = ref.read(sessionControllerProvider).valueOrNull;
    if (session == null) return;

    final code = switch (_kind) {
      DocumentKind.quote =>
        await ref.read(quotesRepositoryProvider).nextCode(session.companyId),
      DocumentKind.proforma =>
        await ref.read(proformasRepositoryProvider).nextCode(session.companyId),
    };
    if (!mounted) return;

    _codeController.text = code;
    _codeEdited = false;
  }

  void _changeKind(DocumentKind kind) {
    if (kind == _kind) return;
    setState(() => _kind = kind);
    // Numara serisi türe bağlı; kullanıcı numaraya dokunmadıysa tazele.
    if (!_codeEdited) _suggestCode();
  }

  Future<void> _submit() async {
    final messenger = ScaffoldMessenger.of(context);

    // Eksikler tek tek ve adıyla bildirilir.
    if (_customerId == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Önce bir müşteri seç.')),
      );
      return;
    }
    if (_items.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'En az bir kalem ekle — "Serbest satır" ya da '
            '"Stoktan" ile ekleyebilirsin.',
          ),
        ),
      );
      return;
    }

    final session = ref.read(sessionControllerProvider).valueOrNull;
    if (session == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Oturum bulunamadı, yeniden giriş yap.')),
      );
      return;
    }

    final code = _codeController.text.trim();
    final codeError = DocumentNumbering.validate(code);
    if (codeError != null) {
      messenger.showSnackBar(SnackBar(content: Text(codeError)));
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final taken = switch (_kind) {
        DocumentKind.quote =>
          await ref
              .read(quotesRepositoryProvider)
              .isCodeTaken(session.companyId, code),
        DocumentKind.proforma =>
          await ref
              .read(proformasRepositoryProvider)
              .isCodeTaken(session.companyId, code),
      };
      if (taken) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('$code numarası bu işletmede zaten kullanılmış.'),
          ),
        );
        return;
      }

      final draft = DocumentDraft(
        code: code,
        customerId: _customerId!,
        items: List.unmodifiable(_items),
        currency: _currency,
        vatMode: _vatMode,
        vatRate: _vatRate,
        validUntil: _validUntil,
        notes: _trimmed(_notesController),
        introText: _trimmed(_introController),
        paymentTerms: _trimmed(_paymentTermsController),
        deliveryTime: _trimmed(_deliveryTimeController),
        warrantyTerms: _trimmed(_warrantyTermsController),
      );

      final destination = switch (_kind) {
        DocumentKind.quote => await _saveQuote(session.companyId, draft),
        DocumentKind.proforma => await _saveProforma(session.companyId, draft),
      };

      if (!mounted) return;
      // Belgeyi oluşturup listeye dönmek yarım bir iş: kullanıcının bir
      // sonraki adımı neredeyse her zaman PDF'i göndermek. Form yerine
      // detay ekranı bırakılır ki geri tuşu yarım forma dönmesin.
      await Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => destination));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<Widget> _saveQuote(String companyId, DocumentDraft draft) async {
    final quote = await ref
        .read(quotesRepositoryProvider)
        .create(
          companyId: companyId,
          customerId: draft.customerId,
          items: draft.items,
          notes: draft.notes,
          introText: draft.introText,
          paymentTerms: draft.paymentTerms,
          deliveryTime: draft.deliveryTime,
          warrantyTerms: draft.warrantyTerms,
          currency: draft.currency,
          vatMode: draft.vatMode,
          vatRate: draft.vatRate,
          validUntil: draft.validUntil,
          requestedCode: draft.code,
        );
    return QuoteDetailScreen(quoteId: quote.id);
  }

  Future<Widget> _saveProforma(String companyId, DocumentDraft draft) async {
    final proforma = await ref
        .read(proformasRepositoryProvider)
        .create(
          companyId: companyId,
          customerId: draft.customerId,
          items: draft.items,
          notes: draft.notes,
          introText: draft.introText,
          paymentTerms: draft.paymentTerms,
          deliveryTime: draft.deliveryTime,
          warrantyTerms: draft.warrantyTerms,
          currency: draft.currency,
          vatMode: draft.vatMode,
          vatRate: draft.vatRate,
          validUntil: draft.validUntil,
          requestedCode: draft.code,
        );
    return ProformaDetailScreen(proformaId: proforma.id);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final totals = DocumentTotals.from(
      _items.map((item) => item.amounts(_vatMode)),
    );

    final company = ref.watch(currentCompanyProvider).valueOrNull;
    if (company != null) _applyCompanyDefaults(company);

    return Scaffold(
      appBar: AppBar(title: Text(_kind.label)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          const SectionHeader(
            'Belge',
            subtitle: 'Belgenin başlığı ve numarası müşteriye böyle gider.',
          ),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SegmentedButton<DocumentKind>(
                  segments: [
                    for (final kind in DocumentKind.values)
                      ButtonSegment(value: kind, label: Text(kind.label)),
                  ],
                  selected: {_kind},
                  onSelectionChanged: (value) => _changeKind(value.first),
                ),
                const SizedBox(height: AppSpacing.lg),
                TextField(
                  controller: _codeController,
                  decoration: const InputDecoration(
                    labelText: 'Belge numarası',
                    isDense: true,
                    helperText:
                        'Değiştirebilirsin; sonraki belgeler buradan devam '
                        'eder.',
                    helperMaxLines: 2,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xxl),
          const SectionHeader(
            'Müşteri',
            subtitle: 'Belgenin üstünde bu bilgiler görünecek.',
          ),
          _CustomerSlot(customerId: _customerId, onPick: _pickCustomer),

          const SizedBox(height: AppSpacing.xxl),
          const SectionHeader(
            'Para birimi ve KDV',
            subtitle: 'Fiyatları hangi birimde ve nasıl yazacağını seç.',
          ),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SegmentedButton<Currency>(
                  segments: [
                    for (final currency in Currency.values)
                      ButtonSegment(
                        value: currency,
                        label: Text('${currency.symbol} ${currency.code}'),
                      ),
                  ],
                  selected: {_currency},
                  onSelectionChanged: (value) =>
                      setState(() => _currency = value.first),
                ),
                const SizedBox(height: AppSpacing.lg),
                SegmentedButton<VatMode>(
                  segments: [
                    for (final mode in VatMode.values)
                      ButtonSegment(value: mode, label: Text(mode.label)),
                  ],
                  selected: {_vatMode},
                  onSelectionChanged: (value) =>
                      setState(() => _vatMode = value.first),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 110,
                      child: TextField(
                        controller: _vatRateController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'KDV %',
                          isDense: true,
                        ),
                        onChanged: (value) {
                          final previous = _vatRate;
                          final parsed = int.tryParse(value.trim());
                          if (parsed == null || parsed < 0 || parsed > 100) {
                            return;
                          }
                          _applyVatRateToItems(previous, parsed);
                        },
                      ),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.sm),
                        child: Text(
                          _vatMode == VatMode.included
                              ? 'Girdiğin fiyatların içinde KDV var kabul '
                                    'edilir, belgede ayrıştırılıp gösterilir.'
                              : 'Girdiğin fiyatlara KDV eklenir ve belgede '
                                    'ayrı satırda gösterilir.',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xxl),
          DocumentItemsEditor(
            items: _items,
            currency: _currency,
            vatMode: _vatMode,
            defaultVatRate: _vatRate,
            onChanged: (items) => setState(() {
              _items
                ..clear()
                ..addAll(items);
            }),
          ),

          const SizedBox(height: AppSpacing.xxl),
          const SectionHeader(
            'Geçerlilik',
            subtitle: 'Kaç gün geçerli olacak? Belgeye tarih olarak basılır.',
          ),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final days in _quickValidityOptions)
                      ChoiceChip(
                        label: Text('$days gün'),
                        selected: _validityDays == days,
                        onSelected: (_) => _setValidityDays(days),
                      ),
                    ChoiceChip(
                      label: const Text('Süresiz'),
                      selected: _validityDays == null,
                      onSelected: (_) => _setValidityDays(null),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 128,
                      child: TextField(
                        controller: _customDaysController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Başka gün',
                          isDense: true,
                          suffixText: 'gün',
                        ),
                        onChanged: (value) {
                          final days = int.tryParse(value.trim());
                          if (days != null && days > 0 && days <= 365) {
                            setState(() => _validityDays = days);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Text(
                        _validUntil == null
                            ? 'Belgede geçerlilik tarihi yazmayacak.'
                            : 'Belgeye yazılacak tarih: '
                                  '${_dateFormat.format(_validUntil!)}',
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xxl),
          const SectionHeader(
            'Belge metinleri',
            subtitle:
                'Şirket ayarlarındaki varsayılanlar geldi; bu belgeye özel '
                'değiştirebilir ya da hazır ifadelerden seçebilirsin.',
          ),
          DocumentTextsSection(
            intro: _introController,
            paymentTerms: _paymentTermsController,
            deliveryTime: _deliveryTimeController,
            warrantyTerms: _warrantyTermsController,
            notes: _notesController,
          ),

          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
      bottomNavigationBar: _SubmitBar(
        totals: totals,
        currency: _currency,
        label: 'Belgeyi oluştur',
        isSubmitting: _isSubmitting,
        // Buton BİLİNÇLİ olarak hiç devre dışı bırakılmıyor.
        //
        // Sessizce sönük duran bir düğme, kullanıcıya neyin eksik
        // olduğunu söylemiyor; ekranı baştan sona kontrol etmek zorunda
        // kalıyor ve çoğu zaman da bulamıyor. Eksik varsa basıldığında
        // tam olarak ne eksik olduğu yazılır (bkz. [_submit]).
        onSubmit: _submit,
      ),
    );
  }
}

/// Seçili müşteri kartı — seçilmemişse seçime çağıran boş durum.
class _CustomerSlot extends ConsumerWidget {
  const _CustomerSlot({required this.customerId, required this.onPick});

  final String? customerId;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final id = customerId;

    if (id == null) {
      return AppCard(
        onTap: onPick,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(Icons.person_search_outlined, color: scheme.primary),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Müşteri seç',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Listeden seç ya da yeni müşteri ekle',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
          ],
        ),
      );
    }

    return ref
        .watch(customerByIdProvider(id))
        .when(
          loading: () => const AppCard(child: LinearProgressIndicator()),
          error: (_, _) => AppCard(
            onTap: onPick,
            child: const Text('Müşteri bilgisi okunamadı. Yeniden seç.'),
          ),
          data: (customer) => AppCard(
            onTap: onPick,
            child: customer == null
                ? const Text('Müşteri bulunamadı. Yeniden seç.')
                : _CustomerSummary(customer: customer),
          ),
        );
  }
}

class _CustomerSummary extends StatelessWidget {
  const _CustomerSummary({required this.customer});

  final Customer customer;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final details = <String>[
      if (customer.companyName?.trim().isNotEmpty == true &&
          customer.contactName?.trim().isNotEmpty == true)
        'Yetkili: ${customer.contactName!.trim()}',
      if (customer.phone?.trim().isNotEmpty == true) customer.phone!.trim(),
      if (customer.address?.trim().isNotEmpty == true) customer.address!.trim(),
      if (customer.taxInfo?.trim().isNotEmpty == true) customer.taxInfo!.trim(),
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                customer.displayName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              for (final line in details)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    line,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              if (details.isEmpty)
                Text(
                  'Adres ve vergi bilgisi girilmemiş — belgede görünmez.',
                  style: TextStyle(fontSize: 12, color: scheme.error),
                ),
            ],
          ),
        ),
        Icon(Icons.swap_horiz, size: 20, color: scheme.onSurfaceVariant),
      ],
    );
  }
}

/// Alt bar: toplam + oluştur. Kaydırmadan görünmesi bilinçli — kullanıcı
/// fiyat girerken müşteriye gidecek rakamı sürekli görmeli.
class _SubmitBar extends StatelessWidget {
  const _SubmitBar({
    required this.totals,
    required this.currency,
    required this.label,
    required this.isSubmitting,
    required this.onSubmit,
  });

  final DocumentTotals totals;
  final Currency currency;
  final String label;
  final bool isSubmitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          border: Border(top: BorderSide(color: scheme.outlineVariant)),
        ),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Genel toplam',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  Money.formatMinor(totals.grossMinor, currency: currency),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: FilledButton(
                onPressed: isSubmitting ? null : onSubmit,
                child: isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(label),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
