import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants/job_constants.dart';
import '../../core/database/app_database.dart';
import '../../core/utils/money.dart';
import '../customers/data/customers_repository.dart';
import 'data/jobs_repository.dart';

final _jobProvider = FutureProvider.family<Job?, String>((ref, id) {
  return ref.watch(jobsRepositoryProvider).byId(id);
});

class JobDetailScreen extends ConsumerWidget {
  const JobDetailScreen({super.key, required this.jobId});
  final String jobId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobAsync = ref.watch(_jobProvider(jobId));

    return jobAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Hata: $e'))),
      data: (job) {
        if (job == null) {
          return const Scaffold(body: Center(child: Text('İş bulunamadı')));
        }
        return _JobDetailContent(job: job);
      },
    );
  }
}

class _JobDetailContent extends ConsumerWidget {
  const _JobDetailContent({required this.job});
  final Job job;

  Future<void> _changeStatus(BuildContext context, WidgetRef ref) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final entry in jobStatusLabels.entries)
              ListTile(
                title: Text(entry.value),
                trailing: job.status == entry.key ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(context, entry.key),
              ),
          ],
        ),
      ),
    );
    if (selected != null && selected != job.status) {
      await ref.read(jobsRepositoryProvider).updateStatus(job.id, selected);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customerAsync = ref.watch(customersRepositoryProvider).byId(job.customerId);
    final statusColor = jobStatusColors[job.status] ?? Colors.grey;

    return Scaffold(
      appBar: AppBar(title: Text(job.code)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(job.title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              ActionChip(
                avatar: Icon(Icons.circle, size: 10, color: statusColor),
                label: Text(jobStatusLabels[job.status] ?? job.status),
                onPressed: () => _changeStatus(context, ref),
              ),
              Chip(label: Text(jobPriorityLabels[job.priority] ?? job.priority)),
            ],
          ),
          const SizedBox(height: 24),
          FutureBuilder<Customer?>(
            future: customerAsync,
            builder: (context, snapshot) {
              final customer = snapshot.data;
              return _InfoTile(
                icon: Icons.person_outline,
                label: 'Müşteri',
                value: customer?.name ?? '...',
              );
            },
          ),
          if (job.appointmentDate != null)
            _InfoTile(
              icon: Icons.event_outlined,
              label: 'Randevu',
              value: DateFormat('d MMMM y, EEEE HH:mm', 'tr_TR').format(job.appointmentDate!),
            ),
          if (job.address?.isNotEmpty == true)
            _InfoTile(icon: Icons.location_on_outlined, label: 'Adres', value: job.address!),
          if (job.description?.isNotEmpty == true)
            _InfoTile(icon: Icons.description_outlined, label: 'Açıklama', value: job.description!),
          _InfoTile(
            icon: Icons.payments_outlined,
            label: 'Tahmini fiyat',
            value: job.estimatedPriceMinor != null
                ? Money.formatMinor(job.estimatedPriceMinor!)
                : 'Belirtilmedi',
          ),
          _InfoTile(
            icon: Icons.check_circle_outline,
            label: 'Gerçek fiyat',
            value: job.actualPriceMinor != null
                ? Money.formatMinor(job.actualPriceMinor!)
                : 'Henüz girilmedi',
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _showSetPriceDialog(context, ref),
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Gerçek fiyatı gir / işi tamamla'),
          ),
          const SizedBox(height: 24),
          Card(
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.camera_alt_outlined),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text('Fotoğraf ve dijital imza — sonraki oturumda eklenecek'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showSetPriceDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(
      text: job.actualPriceMinor != null ? (job.actualPriceMinor! / 100).toString() : '',
    );
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gerçek fiyat'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(prefixText: '₺ '),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Kaydet ve Tamamla'),
          ),
        ],
      ),
    );
    if (result == null || result.trim().isEmpty) return;

    final minor = Money.parseToMinor(result);
    await ref.read(jobsRepositoryProvider).completeWithPrice(job, minor);
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
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
        ],
      ),
    );
  }
}
