import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/constants/customer_types.dart';
import '../../core/constants/job_constants.dart';
import '../../core/database/app_database.dart';
import '../../core/utils/customer_display.dart';
import '../../core/utils/map_launcher.dart';
import '../../core/utils/money.dart';
import '../auth/data/session_controller.dart';
import '../finance/data/finance_repository.dart';
import '../jobs/data/jobs_repository.dart';
import 'data/customer_ledger_repository.dart';
import 'data/customers_repository.dart';

Future<void> _showRecordPaymentDialog(BuildContext context, WidgetRef ref, String customerId) async {
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
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
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
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Hata: $e'))),
      data: (customer) {
        if (customer == null) {
          return const Scaffold(body: Center(child: Text('Müşteri bulunamadı')));
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
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: Text(customer.displayName),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push('/customers/${customer.id}/edit', extra: customer),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Genel'),
              Tab(text: 'Finans'),
              Tab(text: 'İş Geçmişi'),
              Tab(text: 'Belgeler'),
              Tab(text: 'Fotoğraflar'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _GeneralTab(customer: customer),
            _FinanceTab(customerId: customer.id),
            _JobHistoryTab(customerId: customer.id),
            const _EmptyTab(text: 'Bu müşteriye ait belge yok'),
            const _EmptyTab(text: 'Bu müşteriye ait fotoğraf yok'),
          ],
        ),
      ),
    );
  }
}

class _GeneralTab extends StatelessWidget {
  const _GeneralTab({required this.customer});
  final Customer customer;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _InfoRow(icon: Icons.badge_outlined, label: 'Müşteri no', value: customer.code),
        _InfoRow(
          icon: Icons.category_outlined,
          label: 'Tip',
          value: customerTypeLabels[customer.type] ?? customer.type,
        ),
        if (customer.contactName?.isNotEmpty == true)
          _InfoRow(icon: Icons.person_outline, label: 'Yetkili adı soyadı', value: customer.contactName!),
        if (customer.companyName?.isNotEmpty == true)
          _InfoRow(icon: Icons.apartment_outlined, label: 'Firma adı', value: customer.companyName!),
        if (customer.iban?.isNotEmpty == true)
          _InfoRow(icon: Icons.account_balance_outlined, label: 'IBAN', value: customer.iban!),
        if (customer.phone?.isNotEmpty == true)
          _InfoRow(icon: Icons.phone_outlined, label: 'Telefon', value: customer.phone!),
        if (customer.email?.isNotEmpty == true)
          _InfoRow(icon: Icons.email_outlined, label: 'E-posta', value: customer.email!),
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
          _InfoRow(icon: Icons.receipt_long_outlined, label: 'Vergi bilgisi', value: customer.taxInfo!),
        if (customer.notes?.isNotEmpty == true)
          _InfoRow(icon: Icons.notes_outlined, label: 'Notlar', value: customer.notes!),
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
                Text('Cari bakiye (borç)', style: TextStyle(color: scheme.onSurfaceVariant)),
                const SizedBox(height: 4),
                Text(
                  Money.formatMinor(balanceAsync.valueOrNull ?? 0),
                  style: Theme.of(
                    context,
                  ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _showRecordPaymentDialog(context, ref, customerId),
                  icon: const Icon(Icons.payments_outlined, size: 18),
                  label: const Text('Tahsilat Ekle'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text('Hareketler', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
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
                      entry.type == 'DEBIT' ? Icons.arrow_upward : Icons.arrow_downward,
                      color: entry.type == 'DEBIT' ? scheme.error : Colors.green,
                    ),
                    title: Text(entry.description),
                    subtitle: Text(DateFormat('d MMM y', 'tr_TR').format(entry.entryDate)),
                    trailing: Text(
                      Money.formatMinor(entry.amountMinor),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: entry.type == 'DEBIT' ? scheme.error : Colors.green,
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

class _JobHistoryTab extends ConsumerWidget {
  const _JobHistoryTab({required this.customerId});
  final String customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobsAsync = ref.watch(jobsByCustomerProvider(customerId));
    final scheme = Theme.of(context).colorScheme;

    return jobsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Hata: $e')),
      data: (jobs) {
        if (jobs.isEmpty) {
          return Center(
            child: Text(
              'Bu müşteriye ait iş kaydı yok',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: jobs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final job = jobs[index];
            final statusColor = jobStatusColors[job.status] ?? Colors.grey;
            return Card(
              child: ListTile(
                onTap: () => context.push('/jobs/${job.id}'),
                title: Text(job.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  '${job.code} · ${DateFormat('d MMM y', 'tr_TR').format(job.createdAt)}',
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    jobStatusLabels[job.status] ?? job.status,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _EmptyTab extends StatelessWidget {
  const _EmptyTab({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(text, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value, this.trailing});
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
                Text(label, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
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
