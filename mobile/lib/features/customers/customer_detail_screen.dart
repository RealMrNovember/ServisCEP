import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../app/palette.dart';
import '../../app/typography.dart';
import '../../shared/ui.dart';
import '../../app/theme.dart';
import 'package:open_filex/open_filex.dart';

import '../../core/constants/customer_types.dart';
import '../../core/database/app_database.dart';
import '../../core/utils/customer_display.dart';
import '../../core/utils/map_launcher.dart';
import '../../core/utils/money.dart';
import '../auth/data/session_controller.dart';
import '../finance/data/finance_repository.dart';
import '../jobs/data/jobs_repository.dart';
import '../../shared/logo_picker.dart';
import 'data/customer_ledger_repository.dart';
import 'data/customers_repository.dart';

Future<void> _showRecordPaymentDialog(
  BuildContext context,
  WidgetRef ref,
  String customerId,
) async {
  final controller = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Tahsilat Ekle'),
      content: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(prefixText: '₺ ', labelText: 'Tutar'),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: const Text('Kaydet'),
        ),
      ],
    ),
  );
  if (result == null || result.trim().isEmpty) return;

  final session = ref.read(sessionControllerProvider).valueOrNull;
  if (session == null) return;

  await ref
      .read(financeRepositoryProvider)
      .recordPayment(
        companyId: session.companyId,
        customerId: customerId,
        amountMinor: Money.parseToMinor(result),
      );
}

final _customerProvider = FutureProvider.family<Customer?, String>((ref, id) {
  return ref.watch(customersRepositoryProvider).byId(id);
});

/// Müşteri profili — bkz. docs/02 § Müşteri Profili: Genel, Finans, İş
/// Geçmişi, Belgeler, Fotoğraflar sekmeleri.
class CustomerDetailScreen extends ConsumerWidget {
  const CustomerDetailScreen({super.key, required this.customerId});

  final String customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customerAsync = ref.watch(_customerProvider(customerId));

    return customerAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Hata: $e'))),
      data: (customer) {
        if (customer == null) {
          return const Scaffold(
            body: Center(child: Text('Müşteri bulunamadı')),
          );
        }
        return _CustomerDetailContent(customer: customer);
      },
    );
  }
}

class _CustomerDetailContent extends StatelessWidget {
  const _CustomerDetailContent({required this.customer});
  final Customer customer;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      // Tasarım teslimatı ekran 04: ÜÇ sekme.
      //
      // "Fotoğraflar" sekmesi kaldırıldı — her zaman boş bir yer tutucuydu,
      // hiçbir şey göstermiyordu. "İş Geçmişi" Bilgi sekmesinin içine
      // taşındı; ayrı sekme olması kullanıcıyı müşterinin geçmişini görmek
      // için sekme değiştirmeye zorluyordu.
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(customer.displayName),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push(
                '/customers/${customer.id}/edit',
                extra: customer,
              ),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Bilgi'),
              Tab(text: 'Cari Hesap'),
              Tab(text: 'Belgeler'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _GeneralTab(customer: customer),
            _FinanceTab(customerId: customer.id),
            _DocumentsTab(customer: customer),
          ],
        ),
      ),
    );
  }
}

class _GeneralTab extends ConsumerWidget {
  const _GeneralTab({required this.customer});
  final Customer customer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _InfoRow(
          icon: Icons.badge_outlined,
          label: 'Müşteri no',
          value: customer.code,
        ),
        _InfoRow(
          icon: Icons.category_outlined,
          label: 'Tip',
          value: customerTypeLabels[customer.type] ?? customer.type,
        ),
        if (customer.contactName?.isNotEmpty == true)
          _InfoRow(
            icon: Icons.person_outline,
            label: 'Yetkili adı soyadı',
            value: customer.contactName!,
          ),
        if (customer.companyName?.isNotEmpty == true)
          _InfoRow(
            icon: Icons.apartment_outlined,
            label: 'Firma adı',
            value: customer.companyName!,
          ),
        if (customer.iban?.isNotEmpty == true)
          _InfoRow(
            icon: Icons.account_balance_outlined,
            label: 'IBAN',
            value: customer.iban!,
          ),
        if (customer.phone?.isNotEmpty == true)
          _InfoRow(
            icon: Icons.phone_outlined,
            label: 'Telefon',
            value: customer.phone!,
          ),
        if (customer.email?.isNotEmpty == true)
          _InfoRow(
            icon: Icons.email_outlined,
            label: 'E-posta',
            value: customer.email!,
          ),
        if (customer.address?.isNotEmpty == true)
          _InfoRow(
            icon: Icons.location_on_outlined,
            label: 'Adres',
            value: customer.address!,
            trailing: IconButton(
              icon: const Icon(Icons.map_outlined, size: 20),
              tooltip: 'Haritada Aç',
              onPressed: () => MapLauncher.openAddress(customer.address!),
            ),
          ),
        if (customer.taxInfo?.isNotEmpty == true)
          _InfoRow(
            icon: Icons.receipt_long_outlined,
            label: 'Vergi bilgisi',
            value: customer.taxInfo!,
          ),
        if (customer.notes?.isNotEmpty == true)
          _InfoRow(
            icon: Icons.notes_outlined,
            label: 'Notlar',
            value: customer.notes!,
          ),

        // GEÇMİŞ İŞLER burada, ayrı sekmede değil (tasarım ekran 04).
        // Kullanıcı müşteriye baktığında ilk merak ettiği şey onunla daha
        // önce ne yapıldığı; bunun için sekme değiştirmek zorunda kalmamalı.
        const SizedBox(height: AppSpacing.xxl),
        _GecmisIsler(customerId: customer.id),
      ],
    );
  }
}

class _FinanceTab extends ConsumerWidget {
  const _FinanceTab({required this.customerId});
  final String customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final balanceAsync = ref.watch(customerBalanceProvider(customerId));
    final entriesAsync = ref.watch(customerLedgerEntriesProvider(customerId));

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cari bakiye (borç)',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 4),
                Text(
                  Money.formatMinor(balanceAsync.valueOrNull ?? 0),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () =>
                      _showRecordPaymentDialog(context, ref, customerId),
                  icon: const Icon(Icons.payments_outlined, size: 18),
                  label: const Text('Tahsilat Ekle'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Hareketler',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        entriesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Hata: $e'),
          data: (entries) {
            if (entries.isEmpty) {
              return Text(
                'Henüz iş veya tahsilat hareketi yok. İlk iş tamamlandığında cari hesap burada görünecek.',
                style: TextStyle(color: scheme.onSurfaceVariant),
              );
            }
            return Column(
              children: [
                for (final entry in entries)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      entry.type == 'DEBIT'
                          ? Icons.arrow_upward
                          : Icons.arrow_downward,
                      color: entry.type == 'DEBIT'
                          ? scheme.error
                          : Colors.green,
                    ),
                    title: Text(entry.description),
                    subtitle: Text(
                      DateFormat('d MMM y', 'tr_TR').format(entry.entryDate),
                    ),
                    trailing: Text(
                      Money.formatMinor(entry.amountMinor),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: entry.type == 'DEBIT'
                            ? scheme.error
                            : Colors.green,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Müşterinin geçmiş işleri — Bilgi sekmesinin içinde.
///
/// ListView DEĞİL Column döndürüyor: dış ListView'in içine giriyor ve
/// iç içe iki kaydırma alanı kullanıcıyı hep şaşırtır.
class _GecmisIsler extends ConsumerWidget {
  const _GecmisIsler({required this.customerId});
  final String customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palet = context.palette;
    final jobsAsync = ref.watch(jobsByCustomerProvider(customerId));

    return jobsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (jobs) {
        if (jobs.isEmpty) {
          return Text(
            'Bu müşteriye ait iş kaydı yok',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: palet.textMuted),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  'Geçmiş işler',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '${jobs.length} iş',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: palet.textMuted),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final job in jobs)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: AppCard(
                  onTap: () => context.push('/jobs/${job.id}'),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              job.title,
                              style: Theme.of(context).textTheme.titleSmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              DateFormat(
                                'd MMM y',
                                'tr_TR',
                              ).format(job.createdAt),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: palet.textMuted),
                            ),
                          ],
                        ),
                      ),
                      if (job.actualPriceMinor != null)
                        Text(
                          Money.formatMinor(
                            job.actualPriceMinor!,
                            decimals: false,
                          ),
                          style: AppTypography.mono.copyWith(fontSize: 14),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Belgeler sekmesi — şimdilik tek belge türü: vergi levhası (web
/// panelindeki `tax_certificate_path` alanının mobil karşılığı).
///
/// Belge kamerayla taranır (galeri izni istenmez — bkz. AndroidManifest
/// izin disiplini). Yerel kopya cihazda tutulur, yükleme outbox üzerinden
/// yapılır: çevrimdışıyken de çekilebilir, bağlantı gelince yüklenir.
class _DocumentsTab extends ConsumerStatefulWidget {
  const _DocumentsTab({required this.customer});
  final Customer customer;

  @override
  ConsumerState<_DocumentsTab> createState() => _DocumentsTabState();
}

class _DocumentsTabState extends ConsumerState<_DocumentsTab> {
  bool _busy = false;

  Future<void> _capture() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );
    if (file == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(customersRepositoryProvider)
          .setTaxCertificate(
            customerId: widget.customer.id,
            sourcePath: file.path,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vergi levhası kaydedildi, senkronda yüklenecek.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final localPath = widget.customer.taxCertificatePath;
    final hasLocal = localPath != null && File(localPath).existsSync();
    final hasAny = hasLocal || widget.customer.hasTaxCertificate;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      children: [
        Text(
          'Vergi Levhası',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),

        if (hasLocal)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: GestureDetector(
              onTap: () => OpenFilex.open(localPath),
              child: Image.file(
                File(localPath),
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  hasAny
                      ? Icons.cloud_done_outlined
                      : Icons.description_outlined,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    hasAny
                        ? 'Belge sunucuda kayıtlı. Görüntülemek için web '
                              'panelini kullanabilir ya da yeniden tarayabilirsin.'
                        : 'Henüz vergi levhası eklenmemiş.',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _busy ? null : _capture,
          icon: _busy
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.document_scanner_outlined),
          label: Text(hasAny ? 'Yeniden tara' : 'Kamerayla tara'),
        ),
        const SizedBox(height: 10),
        Text(
          'Belge cihazında güvenli şekilde saklanır ve yalnızca senin '
          'işletmene ait alana yüklenir.',
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        ),

        const SizedBox(height: 32),
        const Divider(),
        const SizedBox(height: 20),
        LogoPickerField(
          currentPath: widget.customer.logoPath,
          label: 'Müşteri logosu',
          helper:
              'Bu müşteriye düzenlediğin teklif ve proformaların sağ üst '
              'köşesinde görünür. Zorunlu değil.',
          onPicked: (bytes) => ref
              .read(customersRepositoryProvider)
              .setLogo(customerId: widget.customer.id, bytes: bytes),
          onRemoved: () => ref
              .read(customersRepositoryProvider)
              .removeLogo(widget.customer.id),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
  });
  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: scheme.onSurfaceVariant),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 15)),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
