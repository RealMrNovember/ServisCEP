import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/palette.dart';
import '../app/theme.dart';
import '../core/database/app_database.dart';
import '../core/utils/customer_display.dart';
import '../features/customers/data/customers_repository.dart';
import 'tc_icon.dart';
import 'ui.dart';

/// Müşteri seçme alt sayfası; seçilen müşterinin id'sini döndürür.
///
/// Belge formlarında `DropdownButtonFormField` kullanılıyordu; birkaç yüz
/// müşterisi olan bir işletmede o liste kullanılamaz hâle geliyor. Burada
/// arama var ve "yeni müşteri" akışı formu terk etmeden başlatılabiliyor.
Future<String?> showCustomerPicker(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (context) => const _CustomerPickerSheet(),
  );
}

class _CustomerPickerSheet extends ConsumerStatefulWidget {
  const _CustomerPickerSheet();

  @override
  ConsumerState<_CustomerPickerSheet> createState() =>
      _CustomerPickerSheetState();
}

class _CustomerPickerSheetState extends ConsumerState<_CustomerPickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Yeni müşteri oluşturur ve OLUŞTURULANI SEÇEREK kapanır.
  ///
  /// Önceden seçici sonuçsuz kapatılıp müşteri formu ayrıca açılıyordu:
  /// kullanıcı müşteriyi oluşturup belge formuna dönüyor ama müşteri
  /// seçilmemiş oluyordu — seçtiğini sandığı hâlde. "Belge oluştur"
  /// düğmesi de bu yüzden sönük kalıyor ve sebebi hiçbir yerde
  /// yazmıyordu.
  Future<void> _yeniMusteri(BuildContext context) async {
    final navigator = Navigator.of(context);
    final olusturulanId = await context.push<String>('/customers/new');

    if (!navigator.mounted) return;
    navigator.pop(olusturulanId);
  }

  bool _matches(Customer customer) {
    if (_query.isEmpty) return true;
    final needle = _query.toLowerCase();
    return [
      customer.displayName,
      customer.contactName ?? '',
      customer.companyName ?? '',
      customer.phone ?? '',
      customer.code,
    ].any((field) => field.toLowerCase().contains(needle));
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customersListProvider);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.78,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  0,
                  AppSpacing.xl,
                  AppSpacing.md,
                ),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Müşteri seç',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: _searchController,
                      autofocus: false,
                      decoration: const InputDecoration(
                        hintText: 'İsim, firma, telefon veya kod ara',
                        prefixIcon: TcIcon(TcIcons.search),
                        isDense: true,
                      ),
                      onChanged: (value) =>
                          setState(() => _query = value.trim()),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: customersAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) =>
                      Center(child: Text('Müşteriler yüklenemedi: $e')),
                  data: (customers) {
                    final filtered = customers.where(_matches).toList();
                    if (filtered.isEmpty) {
                      return AppEmptyState(
                        icon: TcIcons.userOff,
                        title: _query.isEmpty
                            ? 'Henüz müşteri yok'
                            : 'Eşleşen müşteri yok',
                        message: _query.isEmpty
                            ? 'Teklif hazırlamak için önce bir müşteri ekle.'
                            : '"$_query" için sonuç bulunamadı.',
                        action: FilledButton.icon(
                          onPressed: () => _yeniMusteri(context),
                          icon: const TcIcon(TcIcons.userPlus),
                          label: const Text('Yeni müşteri ekle'),
                        ),
                      );
                    }

                    final palet = context.palette;

                    return ListView.builder(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                      // Bir fazla: listenin başındaki "yeni müşteri" satırı.
                      //
                      // Aranan müşteri çıkmadığında kullanıcının ilk
                      // refleksi listenin başına bakmak; oluşturma eylemi
                      // başlıkta küçük bir düğmeyken fark edilmiyordu.
                      itemCount: filtered.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return ListTile(
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: palet.accent.withValues(alpha: 0.12),
                                borderRadius: AppRadius.field,
                              ),
                              child: TcIcon(
                                TcIcons.userPlus,
                                size: 18,
                                color: palet.accent,
                              ),
                            ),
                            title: Text(
                              'Yeni müşteri oluştur',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(color: palet.accent),
                            ),
                            onTap: () => _yeniMusteri(context),
                          );
                        }

                        final customer = filtered[index - 1];
                        final subtitle = [
                          if (customer.phone?.trim().isNotEmpty == true)
                            customer.phone!.trim(),
                          if (customer.ilce?.trim().isNotEmpty == true)
                            customer.ilce!.trim(),
                        ].join('  ·  ');

                        return ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: palet.accent.withValues(alpha: 0.12),
                              borderRadius: AppRadius.field,
                            ),
                            child: Text(
                              initialsOf(customer.displayName),
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(color: palet.accent),
                            ),
                          ),
                          title: Text(customer.displayName),
                          subtitle: subtitle.isEmpty ? null : Text(subtitle),
                          onTap: () => Navigator.pop(context, customer.id),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Form içindeki müşteri satırı: seçiliyse özeti, değilse "müşteri seç".
///
/// Teklif/proforma ve iş formu aynı satırı kullanıyor. Açılır liste
/// yerine [showCustomerPicker] açılıyor — birkaç yüz müşterisi olan bir
/// işletmede açılır liste kullanılamaz hâle geliyor.
class CustomerSlot extends ConsumerWidget {
  const CustomerSlot({
    super.key,
    required this.customerId,
    required this.onPick,
  });

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
              child: TcIcon(TcIcons.userSearch, color: scheme.primary),
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
            TcIcon(TcIcons.chevronRight, color: scheme.onSurfaceVariant),
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
        TcIcon(TcIcons.swap, size: 20, color: scheme.onSurfaceVariant),
      ],
    );
  }
}
