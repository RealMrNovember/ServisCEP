import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/constants/job_constants.dart';
import '../../core/database/app_database.dart';
import '../../core/utils/money.dart';
import '../customers/data/customers_repository.dart';
import 'data/job_media_repository.dart';
import 'data/jobs_repository.dart';
import 'signature_capture_screen.dart';

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
          const SizedBox(height: 28),
          _NotesSection(jobId: job.id),
          const SizedBox(height: 28),
          _PhotosSection(jobId: job.id),
          const SizedBox(height: 28),
          _SignatureSection(jobId: job.id),
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

const _photoCategoryLabels = {
  'ONCESI': 'İş Öncesi',
  'ARIZA': 'Arıza',
  'MONTAJ': 'Montaj',
  'SONRASI': 'İş Sonrası',
  'MALZEME': 'Malzeme',
  'DIGER': 'Diğer',
};

class _NotesSection extends ConsumerWidget {
  const _NotesSection({required this.jobId});
  final String jobId;

  Future<void> _addNote(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Not Ekle'),
        content: TextField(controller: controller, maxLines: 3, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
    if (result != null && result.trim().isNotEmpty) {
      await ref.read(jobMediaRepositoryProvider).addNote(jobId: jobId, note: result.trim());
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(jobNotesProvider(jobId));
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Yapılan İşlemler / Notlar',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () => _addNote(context, ref),
            ),
          ],
        ),
        notesAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (e, _) => Text('Hata: $e'),
          data: (notes) {
            if (notes.isEmpty) {
              return Text('Henüz not eklenmedi', style: TextStyle(color: scheme.onSurfaceVariant));
            }
            return Column(
              children: [
                for (final note in notes)
                  Card(
                    child: ListTile(
                      title: Text(note.note),
                      subtitle: Text(DateFormat('d MMM y, HH:mm', 'tr_TR').format(note.createdAt)),
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

class _PhotosSection extends ConsumerWidget {
  const _PhotosSection({required this.jobId});
  final String jobId;

  Future<void> _pickCategoryAndCapture(BuildContext context, WidgetRef ref) async {
    final category = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final entry in _photoCategoryLabels.entries)
              ListTile(
                title: Text(entry.value),
                onTap: () => Navigator.pop(context, entry.key),
              ),
          ],
        ),
      ),
    );
    if (category == null) return;

    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.camera, imageQuality: 70);
    if (file == null) return;

    await ref
        .read(jobMediaRepositoryProvider)
        .addPhoto(jobId: jobId, sourcePath: file.path, category: category);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photosAsync = ref.watch(jobPhotosProvider(jobId));
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Fotoğraflar',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.add_a_photo_outlined),
              onPressed: () => _pickCategoryAndCapture(context, ref),
            ),
          ],
        ),
        photosAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (e, _) => Text('Hata: $e'),
          data: (photos) {
            if (photos.isEmpty) {
              return Text('Henüz fotoğraf eklenmedi', style: TextStyle(color: scheme.onSurfaceVariant));
            }
            return SizedBox(
              height: 96,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: photos.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final photo = photos[index];
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      children: [
                        Image.file(
                          File(photo.filePath),
                          width: 96,
                          height: 96,
                          fit: BoxFit.cover,
                        ),
                        Positioned(
                          left: 4,
                          bottom: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _photoCategoryLabels[photo.category] ?? photo.category,
                              style: const TextStyle(fontSize: 10, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}

class _SignatureSection extends ConsumerWidget {
  const _SignatureSection({required this.jobId});
  final String jobId;

  Future<void> _capture(BuildContext context, WidgetRef ref) async {
    final result = await Navigator.of(context).push<(String, List<int>)>(
      MaterialPageRoute(builder: (_) => const SignatureCaptureScreen()),
    );
    if (result == null) return;
    final (name, bytes) = result;
    await ref
        .read(jobMediaRepositoryProvider)
        .addSignature(jobId: jobId, signerName: name, pngBytes: bytes);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signaturesAsync = ref.watch(jobSignaturesProvider(jobId));
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Müşteri İmzası',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        signaturesAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (e, _) => Text('Hata: $e'),
          data: (signatures) {
            if (signatures.isEmpty) {
              return OutlinedButton.icon(
                onPressed: () => _capture(context, ref),
                icon: const Icon(Icons.draw_outlined),
                label: const Text('İmza Al'),
              );
            }
            final signature = signatures.first;
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(File(signature.filePath), height: 120, fit: BoxFit.contain),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${signature.signerName} · ${DateFormat('d MMM y, HH:mm', 'tr_TR').format(signature.createdAt)}',
                      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
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
