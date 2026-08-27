import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app/palette.dart';
import '../../shared/ui.dart';
import '../../app/theme.dart';
import '../../shared/tc_icon.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/job_constants.dart';
import '../../core/database/app_database.dart';
import '../settings/data/company_repository.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/pdf_service.dart';
import '../../core/utils/customer_display.dart';
import '../../core/utils/map_launcher.dart';
import '../../core/utils/money.dart';
import '../customers/data/customers_repository.dart';
import 'data/job_media_repository.dart';
import 'data/jobs_repository.dart';
import 'job_complete_screen.dart';
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
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
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
                trailing: job.status == entry.key
                    ? const TcIcon(TcIcons.check)
                    : null,
                onTap: () => Navigator.pop(context, entry.key),
              ),
          ],
        ),
      ),
    );
    if (selected != null && selected != job.status) {
      await ref.read(jobsRepositoryProvider).updateStatus(job.id, selected);
      if (selected == 'TAMAMLANDI' || selected == 'IPTAL') {
        await NotificationService.cancelJobReminder(job.id);
      }
    }
  }

  Future<void> _shareServiceFormPdf(BuildContext context, WidgetRef ref) async {
    final company = await ref.read(currentCompanyProvider.future);
    final customer = await ref
        .read(customersRepositoryProvider)
        .byId(job.customerId);
    if (company == null || customer == null) return;

    final notes = await ref
        .read(jobMediaRepositoryProvider)
        .watchNotes(job.id)
        .first;
    final signatures = await ref
        .read(jobMediaRepositoryProvider)
        .watchSignatures(job.id)
        .first;
    final signature = signatures.isNotEmpty ? signatures.first : null;

    final file = await PdfService.buildServiceFormPdf(
      job: job,
      company: company,
      customer: customer,
      notes: notes,
      signatureFile: signature != null ? File(signature.filePath) : null,
      signerName: signature?.signerName,
    );
    if (context.mounted) {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'Servis Formu ${job.code}',
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customerAsync = ref
        .watch(customersRepositoryProvider)
        .byId(job.customerId);

    return Scaffold(
      appBar: AppBar(
        title: Text(job.code),
        actions: [
          IconButton(
            icon: const TcIcon(TcIcons.share),
            tooltip: 'Servis Formu PDF Paylaş',
            onPressed: () => _shareServiceFormPdf(context, ref),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          _IsBasligi(
            job: job,
            onDurumDegistir: () => _changeStatus(context, ref),
          ),
          const SizedBox(height: AppSpacing.xl),
          FutureBuilder<Customer?>(
            future: customerAsync,
            builder: (context, snapshot) {
              final musteri = snapshot.data;
              return _KunyeKarti(
                satirlar: [
                  ('Müşteri', musteri?.displayName ?? '...'),
                  if (job.address?.isNotEmpty == true)
                    ('Adres', job.address!)
                  else if (musteri?.address?.isNotEmpty == true)
                    ('Adres', musteri!.address!),
                  if (job.appointmentDate != null)
                    (
                      'Tarih / saat',
                      DateFormat(
                        'd MMM · HH:mm',
                        'tr_TR',
                      ).format(job.appointmentDate!),
                    ),
                  if (job.description?.isNotEmpty == true)
                    ('Açıklama', job.description!),
                  (
                    'Tahmini',
                    job.estimatedPriceMinor != null
                        ? Money.formatMinor(job.estimatedPriceMinor!)
                        : 'Belirtilmedi',
                  ),
                  if (job.actualPriceMinor != null)
                    ('Alınan ücret', Money.formatMinor(job.actualPriceMinor!)),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          // Ara ve Yol Tarifi ana eylemler: kullanıcı bu ekranı çoğu zaman
          // YOLDA açıyor.
          FutureBuilder<Customer?>(
            future: customerAsync,
            builder: (context, snapshot) {
              final musteri = snapshot.data;
              final telefon = musteri?.phone;
              final adres = job.address?.isNotEmpty == true
                  ? job.address
                  : musteri?.address;
              return Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: telefon == null || telefon.isEmpty
                          ? null
                          : () => launchUrl(Uri.parse('tel:$telefon')),
                      icon: const TcIcon(TcIcons.phone, size: 18),
                      label: const Text('Ara'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: adres == null || adres.isEmpty
                          ? null
                          : () => MapLauncher.openAddress(adres),
                      icon: const TcIcon(TcIcons.map, size: 18),
                      label: const Text('Yol Tarifi'),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          // Tamamlanmış işte etiket değişiyor: ekran aynı ama kullanıcı
          // yaptığı şeyin "kapatmak" değil "düzeltmek" olduğunu bilmeli.
          OutlinedButton.icon(
            onPressed: () => _tamamla(context),
            icon: const TcIcon(TcIcons.checkCircle, size: 18),
            label: Text(
              job.status == 'TAMAMLANDI' ? 'Tutarı düzelt' : 'İşi tamamla',
            ),
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

  Future<void> _tamamla(BuildContext context) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => JobCompleteScreen(job: job)));
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
        content: TextField(
          controller: controller,
          maxLines: 3,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
    if (result != null && result.trim().isNotEmpty) {
      await ref
          .read(jobMediaRepositoryProvider)
          .addNote(jobId: jobId, note: result.trim());
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
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            IconButton(
              icon: const TcIcon(TcIcons.plus),
              onPressed: () => _addNote(context, ref),
            ),
          ],
        ),
        notesAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (e, _) => Text('Hata: $e'),
          data: (notes) {
            if (notes.isEmpty) {
              return Text(
                'Henüz not eklenmedi',
                style: TextStyle(color: scheme.onSurfaceVariant),
              );
            }
            return Column(
              children: [
                for (final note in notes)
                  Card(
                    child: ListTile(
                      title: Text(note.note),
                      subtitle: Text(
                        DateFormat(
                          'd MMM y, HH:mm',
                          'tr_TR',
                        ).format(note.createdAt),
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

class _PhotosSection extends ConsumerWidget {
  const _PhotosSection({required this.jobId});
  final String jobId;

  Future<void> _pickCategoryAndCapture(
    BuildContext context,
    WidgetRef ref,
  ) async {
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
    final file = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
    );
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
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            IconButton(
              icon: const TcIcon(TcIcons.camera),
              onPressed: () => _pickCategoryAndCapture(context, ref),
            ),
          ],
        ),
        photosAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (e, _) => Text('Hata: $e'),
          data: (photos) {
            if (photos.isEmpty) {
              return Text(
                'Henüz fotoğraf eklenmedi',
                style: TextStyle(color: scheme.onSurfaceVariant),
              );
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _photoCategoryLabels[photo.category] ??
                                  photo.category,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                              ),
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
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        signaturesAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (e, _) => Text('Hata: $e'),
          data: (signatures) {
            if (signatures.isEmpty) {
              return OutlinedButton.icon(
                onPressed: () => _capture(context, ref),
                icon: const TcIcon(TcIcons.signature),
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
                      child: Image.file(
                        File(signature.filePath),
                        height: 120,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${signature.signerName} · ${DateFormat('d MMM y, HH:mm', 'tr_TR').format(signature.createdAt)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
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

/// İş başlığı ve rozetler — tasarım teslimatı ekran 03.
///
/// Rozetler tek satırda: aciliyet, durum ve senkron durumu kullanıcının
/// ekrana girer girmez göreceği üç şey.
class _IsBasligi extends StatelessWidget {
  const _IsBasligi({required this.job, required this.onDurumDegistir});

  final Job job;
  final VoidCallback onDurumDegistir;

  @override
  Widget build(BuildContext context) {
    final palet = context.palette;
    final acil = job.priority == 'YUKSEK' && job.status != 'TAMAMLANDI';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(job.title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            if (acil) _Rozet(metin: 'Acil', renk: palet.dangerText),
            // Durum rozetine dokunulunca değiştirilebiliyor; tek dokunuşla
            // "devam ediyor"a geçmek sahadaki en sık eylem.
            _Rozet(
              metin: jobStatusLabels[job.status] ?? job.status,
              renk: job.status == 'TAMAMLANDI'
                  ? palet.successText
                  : palet.accent,
              onTap: onDurumDegistir,
            ),
            if (job.syncStatus == 'PENDING')
              _Rozet(metin: 'Cihazda', renk: palet.warningText),
          ],
        ),
      ],
    );
  }
}

class _Rozet extends StatelessWidget {
  const _Rozet({required this.metin, required this.renk, this.onTap});

  final String metin;
  final Color renk;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final govde = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: renk.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: renk, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            metin,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: renk),
          ),
        ],
      ),
    );

    if (onTap == null) return govde;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: govde,
    );
  }
}

/// Künye kartı: müşteri, adres, tarih/saat.
///
/// Tek kart içinde etiket–değer satırları. Ayrı ayrı kartlara bölmek
/// ekranı uzatıyor ve kullanıcı aşağı kaydırmadan hiçbirini göremiyordu.
class _KunyeKarti extends StatelessWidget {
  const _KunyeKarti({required this.satirlar});

  final List<(String, String)> satirlar;

  @override
  Widget build(BuildContext context) {
    final palet = context.palette;

    return AppCard(
      child: Column(
        children: [
          for (var i = 0; i < satirlar.length; i++) ...[
            if (i > 0) Divider(height: AppSpacing.xl, color: palet.border),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 96,
                  child: Text(
                    satirlar[i].$1,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: palet.textMuted),
                  ),
                ),
                Expanded(
                  child: Text(
                    satirlar[i].$2,
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
