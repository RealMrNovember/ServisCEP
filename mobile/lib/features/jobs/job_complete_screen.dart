import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/palette.dart';
import '../../app/theme.dart';
import '../../app/typography.dart';
import '../../core/database/app_database.dart';
import '../../core/services/notification_service.dart';
import '../../core/sync/sync_status.dart';
import '../../core/utils/money.dart';
import '../../shared/tc_icon.dart';
import '../../shared/ui.dart';
import '../finance/data/finance_repository.dart';
import 'data/job_media_repository.dart';
import 'data/jobs_repository.dart';
import 'signature_capture_screen.dart';

/// Ödeme türleri — [Payments.method] alanına yazılan değerler.
const _odemeTurleri = ['Nakit', 'Kart', 'Havale'];

/// İş tamamlama — tasarım teslimatı ekran 11.
///
/// Eskiden tamamlama tek satırlık bir "gerçek fiyat" diyaloguydu: kullanıcı
/// tahsilatı ayrıca girmeyi unutuyor, imzasız/fotoğrafsız işler
/// tamamlanıyordu. Buradaki kontrol listesi eksikleri kapanmadan ÖNCE
/// gösteriyor ama tamamlamayı engellemiyor — sahada bazen fotoğraf
/// çekilemiyor ve kullanıcının işi kapatamaması daha büyük bir sorun.
///
/// NOT: tasarımdaki "Malzeme listesi girildi" satırı yok — kullanılan
/// malzeme kaydı henüz hiçbir yerde tutulmuyor (bkz. ROADMAP).
class JobCompleteScreen extends ConsumerStatefulWidget {
  const JobCompleteScreen({super.key, required this.job});

  final Job job;

  @override
  ConsumerState<JobCompleteScreen> createState() => _JobCompleteScreenState();
}

class _JobCompleteScreenState extends ConsumerState<JobCompleteScreen> {
  late final TextEditingController _tutar = TextEditingController(
    text: _baslangicTutari(),
  );
  final _tahsilat = TextEditingController();

  String _odemeTuru = _odemeTurleri.first;
  bool _kaydediyor = false;

  /// İş tutarı olarak önce daha önce girilmiş gerçek tutar, o yoksa
  /// teklif edilen tutar gelir: çoğu işte ikisi aynı ve kullanıcı alanı
  /// hiç açmadan geçebiliyor.
  String _baslangicTutari() {
    final minor = widget.job.actualPriceMinor ?? widget.job.estimatedPriceMinor;
    return minor == null ? '' : Money.formatMinorPlain(minor);
  }

  @override
  void dispose() {
    _tutar.dispose();
    _tahsilat.dispose();
    super.dispose();
  }

  Future<void> _imzaAl() async {
    final sonuc = await Navigator.of(context).push<(String, List<int>)>(
      MaterialPageRoute(
        builder: (_) => SignatureCaptureScreen(
          altBaslik: '${widget.job.code} · ${widget.job.title}',
        ),
      ),
    );
    if (sonuc == null) return;
    final (ad, bayt) = sonuc;
    await ref
        .read(jobMediaRepositoryProvider)
        .addSignature(jobId: widget.job.id, signerName: ad, pngBytes: bayt);
  }

  Future<void> _tamamla() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final tutarMinor = Money.parseToMinor(_tutar.text);
    if (tutarMinor <= 0) {
      messenger.showSnackBar(const SnackBar(content: Text('İş tutarını gir.')));
      return;
    }

    final tahsilMetni = _tahsilat.text.trim();
    final tahsilMinor = tahsilMetni.isEmpty
        ? 0
        : Money.parseToMinor(tahsilMetni);
    if (tahsilMinor > tutarMinor) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Tahsil edilen tutar iş tutarından büyük olamaz.'),
        ),
      );
      return;
    }

    setState(() => _kaydediyor = true);
    try {
      await ref
          .read(jobsRepositoryProvider)
          .completeWithPrice(widget.job, tutarMinor);

      // Tahsilat AYRI bir kayıt: iş borcu cari hesaba borç, tahsilat
      // alacak olarak yazılıyor. Tek kayda sıkıştırılırsa kısmi
      // tahsilatta bakiye yanlış çıkıyor.
      if (tahsilMinor > 0) {
        await ref
            .read(financeRepositoryProvider)
            .recordPayment(
              companyId: widget.job.companyId,
              customerId: widget.job.customerId,
              amountMinor: tahsilMinor,
              jobId: widget.job.id,
              method: _odemeTuru,
              note: '${widget.job.code} tahsilatı',
            );
      }

      await NotificationService.cancelJobReminder(widget.job.id);
      if (!mounted) return;
      navigator.pop(true);
    } finally {
      if (mounted) setState(() => _kaydediyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palet = context.palette;
    final cevrimici = ref.watch(isOnlineProvider).valueOrNull ?? true;

    final notlar = ref.watch(jobNotesProvider(widget.job.id)).valueOrNull ?? [];
    final fotograflar =
        ref.watch(jobPhotosProvider(widget.job.id)).valueOrNull ?? [];
    final imzalar =
        ref.watch(jobSignaturesProvider(widget.job.id)).valueOrNull ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text('İşi Tamamla')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          Text(
            widget.job.code,
            style: AppTypography.mono.copyWith(fontSize: 13),
          ),
          const SizedBox(height: 2),
          Text(
            widget.job.title,
            style: Theme.of(context).textTheme.titleMedium,
          ),

          const SizedBox(height: AppSpacing.xl),
          AppCard(
            child: Column(
              children: [
                _KontrolSatiri(
                  metin: 'Servis notu yazıldı',
                  tamam: notlar.isNotEmpty,
                ),
                Divider(height: AppSpacing.xl, color: palet.border),
                _KontrolSatiri(
                  metin: 'En az 1 fotoğraf eklendi',
                  tamam: fotograflar.isNotEmpty,
                ),
                Divider(height: AppSpacing.xl, color: palet.border),
                _KontrolSatiri(
                  metin: 'Müşteri imzası alındı',
                  tamam: imzalar.isNotEmpty,
                  eylemEtiketi: 'İmza Al',
                  onEylem: _imzaAl,
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xxl),
          const SectionHeader(
            'Tutar',
            subtitle: 'İş tutarı cari hesaba borç olarak yazılır.',
          ),
          AppCard(
            child: Column(
              children: [
                TextField(
                  controller: _tutar,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'İş tutarı',
                    prefixText: '₺ ',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                TextField(
                  controller: _tahsilat,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Tahsil edilen tutar',
                    prefixText: '₺ ',
                    isDense: true,
                    helperText: 'Boş bırakırsan cari hesaba borç yazılır.',
                    helperMaxLines: 2,
                  ),
                ),
              ],
            ),
          ),

          // Ödeme türü yalnızca tahsilat girildiğinde anlamlı; boşken
          // gösterilirse kullanıcı bir şey seçmek zorunda sanıyor.
          if (_tahsilat.text.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            SegmentedButton<String>(
              segments: [
                for (final tur in _odemeTurleri)
                  ButtonSegment(value: tur, label: Text(tur)),
              ],
              selected: {_odemeTuru},
              onSelectionChanged: (secim) =>
                  setState(() => _odemeTuru = secim.first),
            ),
          ],

          if (!cevrimici) ...[
            const SizedBox(height: AppSpacing.xl),
            AppCard(
              child: Row(
                children: [
                  TcIcon(TcIcons.cloudOff, size: 18, color: palet.warningText),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'İnternet yok — sorun değil',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(color: palet.warningText),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Tamamlama cihaza yazılır, bağlantı gelince '
                          'kendiliğinden gönderilir.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: palet.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: FilledButton(
            onPressed: _kaydediyor ? null : _tamamla,
            child: _kaydediyor
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Tamamla ve Kaydet'),
          ),
        ),
      ),
    );
  }
}

/// Kontrol listesi satırı.
///
/// Eksik satır kırmızı DEĞİL sönük gösteriliyor: bunlar hata değil, henüz
/// yapılmamış işler. Kırmızı, kullanıcının yanlış bir şey yaptığını
/// düşündürüyordu.
class _KontrolSatiri extends StatelessWidget {
  const _KontrolSatiri({
    required this.metin,
    required this.tamam,
    this.eylemEtiketi,
    this.onEylem,
  });

  final String metin;
  final bool tamam;
  final String? eylemEtiketi;
  final VoidCallback? onEylem;

  @override
  Widget build(BuildContext context) {
    final palet = context.palette;
    final renk = tamam ? palet.successText : palet.textMuted;

    return Row(
      children: [
        // Setinde boş daire ikonu yok; yapılmamış satır için 18dp'lik
        // çerçeve çiziliyor — tamamlanan satırla aynı ölçüde durur.
        if (tamam)
          TcIcon(TcIcons.checkCircle, size: 18, color: renk)
        else
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: renk, width: 1.4),
            ),
          ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            metin,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: tamam ? palet.text : palet.textMuted,
            ),
          ),
        ),
        if (!tamam && eylemEtiketi != null && onEylem != null)
          TextButton(onPressed: onEylem, child: Text(eylemEtiketi!)),
      ],
    );
  }
}
