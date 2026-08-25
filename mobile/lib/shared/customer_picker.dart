import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/theme.dart';
import '../core/database/app_database.dart';
import '../core/utils/customer_display.dart';
import '../features/customers/data/customers_repository.dart';
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Müşteri seç',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            context.push('/customers/new');
                          },
                          icon: const Icon(Icons.person_add_alt, size: 18),
                          label: const Text('Yeni'),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: _searchController,
                      autofocus: false,
                      decoration: const InputDecoration(
                        hintText: 'İsim, firma, telefon veya kod ara',
                        prefixIcon: Icon(Icons.search),
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
                        icon: Icons.person_off_outlined,
                        title: _query.isEmpty
                            ? 'Henüz müşteri yok'
                            : 'Eşleşen müşteri yok',
                        message: _query.isEmpty
                            ? 'Teklif hazırlamak için önce bir müşteri ekle.'
                            : '"$_query" için sonuç bulunamadı.',
                        action: FilledButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            context.push('/customers/new');
                          },
                          icon: const Icon(Icons.person_add_alt),
                          label: const Text('Yeni müşteri ekle'),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final customer = filtered[index];
                        final subtitle = [
                          if (customer.phone?.trim().isNotEmpty == true)
                            customer.phone!.trim(),
                          if (customer.il?.trim().isNotEmpty == true)
                            customer.il!.trim(),
                        ].join('  ·  ');

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.12),
                            child: Text(
                              customer.displayName.isEmpty
                                  ? '?'
                                  : customer.displayName
                                        .substring(0, 1)
                                        .toUpperCase(),
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context).colorScheme.primary,
                              ),
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
