import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/palette.dart';
import '../../app/typography.dart';
import '../../app/theme.dart';
import '../../core/constants/job_constants.dart';
import '../../core/utils/customer_display.dart';
import '../../core/utils/money.dart';
import '../../shared/brand_footer.dart';
import '../../shared/skeleton.dart';
import '../../shared/tc_icon.dart';
import '../../shared/ui.dart';
import '../../shared/update_banner.dart';
import '../auth/data/session_controller.dart';
import '../quotes/quote_form_screen.dart';
import '../jobs/data/jobs_repository.dart';
import '../stock/barcode_flow.dart';
import '../subscription/widgets/subscription_banner.dart';

/// Ana Sayfa.
///
/// Ürün vizyonunun merkezi ekranı — bkz. docs/01 § Ana Kullanıcı Deneyimi
/// ve tasarım teslimatı ekran 01: kullanıcı uygulamayı açtığında "bugün ne
/// yapacağım?" sorusunun cevabını doğrudan görmeli.
///
/// Sıralama bilinçli: önce günün TEK RAKAMLA özeti, sonra en sık yapılan
/// dört eylem, sonra SIRADAKİ iş (ekranın en çok bakılan yeri), sonra
/// günün tamamı. Aşağı inildikçe aciliyet azalıyor.
///
/// Tasarımdaki bildirim zili BİLİNÇLİ olarak yok: bildirim merkezi henüz
/// yazılmadı ve hiçbir yere gitmeyen bir zil, kullanıcıya okunmamış bir
/// şey olduğunu söyleyip onu boşa çıkarır. Aynı gerekçeyle "Kullanıcılar
/// ve yetkiler" de sahte ekran yerine pasif bırakılmıştı.
/// Durum kodları düz metin (bkz. job_constants.dart); yerelde iki sabit
/// tutmak, her karşılaştırmada tırnak içinde yazmaktan daha az hataya
/// açık.
const _tamamlandi = 'TAMAMLANDI';
const _iptal = 'IPTAL';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider).valueOrNull;
    final jobsAsync = ref.watch(todaysJobsProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(todaysJobsProvider),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _Selamlama(adSoyad: session?.fullName)),
              const SliverToBoxAdapter(child: UpdateBanner()),

              jobsAsync.when(
                loading: () => const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                    child: AppSkeleton(),
                  ),
                ),
                error: (_, _) => SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: AppErrorState(
                      title: 'Bugünün işleri yüklenemedi',
                      message: 'Cihazdaki kayıtların güvende.',
                      onRetry: () => ref.invalidate(todaysJobsProvider),
                    ),
                  ),
                ),
                data: (isler) => SliverList.list(
                  children: [
                    _GununOzeti(isler: isler),
                    const _HizliEylemler(),
                    if (isler.isNotEmpty) _SiradakiIs(isler: isler),
                    _BugununIsleri(isler: isler),
                    const SubscriptionBanner(),
                    const SizedBox(height: AppSpacing.xxl),
                    const BrandFooter(),
                    const SizedBox(height: AppSpacing.xxl),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tarih ve "Merhaba {ad}".
///
/// Yalnızca İLK AD kullanılıyor: tam ad selamlamada resmi ve uzun duruyor,
/// üstelik uzun adlarda satır taşıyordu.
class _Selamlama extends StatelessWidget {
  const _Selamlama({this.adSoyad});

  final String? adSoyad;

  @override
  Widget build(BuildContext context) {
    final palet = context.palette;
    final tarih = DateFormat('EEEE, d MMMM', 'tr_TR').format(DateTime.now());
    final ilkAd = (adSoyad ?? '').trim().split(' ').first;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tarih,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: palet.textMuted),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            ilkAd.isEmpty ? 'Merhaba' : 'Merhaba $ilkAd',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ],
      ),
    );
  }
}

/// "Bugünün özeti" — tek rakam ve üç kırılım.
///
/// Büyük rakam bilinçli: kullanıcı ekranı açtığında okuyacağı ilk şey
/// günün yükü olmalı. Kırılımlar (biten / bekleyen / tahsilat) onun altında
/// ve küçük.
class _GununOzeti extends StatelessWidget {
  const _GununOzeti({required this.isler});

  final List<JobWithCustomer> isler;

  @override
  Widget build(BuildContext context) {
    final palet = context.palette;

    final biten = isler.where((i) => i.job.status == _tamamlandi).length;
    final bekleyen = isler.length - biten;

    // Tahsilat: yalnızca HENÜZ ücreti alınmamış işlerin tahmini bedeli.
    // Tamamlanıp ücreti alınmış işi buraya katmak, aynı parayı iki kez
    // beklenen tahsilat göstermek olurdu.
    final tahsilat = isler
        .where((i) => i.job.actualPriceMinor == null)
        .fold<int>(0, (t, i) => t + (i.job.estimatedPriceMinor ?? 0));

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.lg,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: palet.accentSoft,
          borderRadius: AppRadius.card,
          border: Border.all(color: palet.accentLine),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'BUGÜNÜN ÖZETİ',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: palet.accent,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '${isler.length}',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  isler.isEmpty ? 'iş planlı değil' : 'iş planlı',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: palet.textMuted),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                _OzetKirilim(etiket: 'Biten', deger: '$biten'),
                _OzetKirilim(etiket: 'Bekleyen', deger: '$bekleyen'),
                _OzetKirilim(
                  etiket: 'Tahsilat',
                  deger: Money.formatMinor(tahsilat, decimals: false),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OzetKirilim extends StatelessWidget {
  const _OzetKirilim({required this.etiket, required this.deger});

  final String etiket;
  final String deger;

  @override
  Widget build(BuildContext context) {
    final palet = context.palette;

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            etiket,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: palet.textMuted),
          ),
          const SizedBox(height: 2),
          // Tutar ve sayılar tabular: farklı satırlarda rakamlar hizalı
          // dursun diye (bkz. AppTypography.mono).
          Text(deger, style: AppTypography.mono.copyWith(fontSize: 16)),
        ],
      ),
    );
  }
}

/// En sık yapılan dört eylem.
///
/// Dörtten fazlası ızgarayı ikinci satıra taşırdı ve ekranın en değerli
/// bölgesini yerdi; dörtten azı ise kullanıcıyı menüye gönderirdi.
class _HizliEylemler extends ConsumerWidget {
  const _HizliEylemler();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      child: Row(
        children: [
          _EylemKutusu(
            ikon: TcIcons.plus,
            etiket: 'Yeni İş',
            onTap: () => context.push('/jobs/new'),
          ),
          _EylemKutusu(
            ikon: TcIcons.file,
            etiket: 'Yeni Teklif',
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const QuoteFormScreen())),
          ),
          _EylemKutusu(
            ikon: TcIcons.userPlus,
            etiket: 'Müşteri',
            onTap: () => context.push('/customers/new'),
          ),
          _EylemKutusu(
            ikon: TcIcons.barcode,
            etiket: 'Barkod',
            onTap: () => scanBarcodeAndOpen(context, ref),
          ),
        ],
      ),
    );
  }
}

class _EylemKutusu extends StatelessWidget {
  const _EylemKutusu({
    required this.ikon,
    required this.etiket,
    required this.onTap,
  });

  final String ikon;
  final String etiket;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palet = context.palette;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.card,
          child: Column(
            children: [
              Container(
                height: 56,
                decoration: BoxDecoration(
                  color: palet.surface,
                  borderRadius: AppRadius.card,
                  border: Border.all(color: palet.border),
                ),
                child: Center(
                  child: TcIcon(ikon, size: 22, color: palet.accent),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                etiket,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sıradaki iş — ekranın en çok bakılan yeri.
///
/// "Şimdi nereye gidiyorum, kime, ne zaman" sorusunun cevabı. Ara ve Yol
/// Tarifi burada duruyor çünkü kullanıcı bunları YOLDA, tek eliyle
/// kullanıyor; iş detayına girmek zorunda kalmamalı.
class _SiradakiIs extends StatelessWidget {
  const _SiradakiIs({required this.isler});

  final List<JobWithCustomer> isler;

  @override
  Widget build(BuildContext context) {
    final palet = context.palette;
    final simdi = DateTime.now();

    // Sıradaki = tamamlanmamış ve randevusu GELECEKTE olan ilk iş.
    // Geçmiş saatli bir işi "sıradaki" göstermek kullanıcıyı yanıltır.
    final sonraki = isler
        .where(
          (i) =>
              i.job.status != _tamamlandi &&
              i.job.status != _iptal &&
              (i.job.appointmentDate?.isAfter(simdi) ?? false),
        )
        .toList();
    if (sonraki.isEmpty) return const SizedBox.shrink();

    sonraki.sort(
      (a, b) => a.job.appointmentDate!.compareTo(b.job.appointmentDate!),
    );
    final is_ = sonraki.first;
    final kalan = is_.job.appointmentDate!.difference(simdi);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                'Sıradaki iş',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                _kalanMetni(kalan),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: palet.textMuted),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            onTap: () => context.push('/jobs/${is_.job.id}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      is_.job.startTime ?? '—',
                      style: AppTypography.monoLarge,
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            is_.job.title,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _musteriSatiri(is_),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: palet.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: _MiniEylem(
                        ikon: TcIcons.phone,
                        etiket: 'Ara',
                        onTap: is_.customer.phone == null
                            ? null
                            : () => launchUrl(
                                Uri.parse('tel:${is_.customer.phone}'),
                              ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _MiniEylem(
                        ikon: TcIcons.map,
                        etiket: 'Yol Tarifi',
                        onTap: _adres(is_) == null
                            ? null
                            : () => launchUrl(
                                Uri.parse(
                                  'https://www.google.com/maps/search/?api=1'
                                  '&query=${Uri.encodeComponent(_adres(is_)!)}',
                                ),
                                mode: LaunchMode.externalApplication,
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _kalanMetni(Duration k) {
    if (k.inMinutes < 60) return '${k.inMinutes} dakika sonra';
    if (k.inHours < 24) return '${k.inHours} saat sonra';
    return 'yarın';
  }

  static String _musteriSatiri(JobWithCustomer i) {
    final ad = i.customer.displayName;
    final ilce = i.customer.ilce;
    return ilce == null || ilce.isEmpty ? ad : '$ad · $ilce';
  }

  static String? _adres(JobWithCustomer i) {
    final parcalar = [
      i.job.address,
      i.customer.address,
      i.customer.ilce,
      i.customer.il,
    ].where((p) => p != null && p.trim().isNotEmpty).cast<String>().toList();
    return parcalar.isEmpty ? null : parcalar.join(' ');
  }
}

class _MiniEylem extends StatelessWidget {
  const _MiniEylem({required this.ikon, required this.etiket, this.onTap});

  final String ikon;
  final String etiket;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palet = context.palette;
    // Veri yoksa buton PASİF görünüyor. Basılabilir görünüp hiçbir şey
    // yapmamak, kullanıcıya uygulamanın bozuk olduğunu düşündürür.
    final aktif = onTap != null;

    return OutlinedButton.icon(
      onPressed: onTap,
      icon: TcIcon(
        ikon,
        size: 18,
        color: aktif ? palet.text : palet.disabledText,
      ),
      label: Text(etiket),
    );
  }
}

/// Günün tamamı. Sıradaki iş yukarıda ayrıca gösterildiği için burada
/// tekrar etmesi sorun değil: kullanıcı günü bir bütün olarak da görmek
/// istiyor.
class _BugununIsleri extends StatelessWidget {
  const _BugununIsleri({required this.isler});

  final List<JobWithCustomer> isler;

  @override
  Widget build(BuildContext context) {
    if (isler.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: AppEmptyState(
          icon: Icons.event_available_outlined,
          title: 'Bugün için planlanmış iş yok',
          message: 'Yeni bir iş oluşturarak günü planla.',
          action: FilledButton(
            onPressed: () => context.push('/jobs/new'),
            child: const Text('Yeni İş'),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Bugünün işleri',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              TextButton(
                onPressed: () => context.go('/jobs'),
                child: const Text('Tümü'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final i in isler) _IsSatiri(is_: i),
        ],
      ),
    );
  }
}

class _IsSatiri extends StatelessWidget {
  const _IsSatiri({required this.is_});

  final JobWithCustomer is_;

  @override
  Widget build(BuildContext context) {
    final palet = context.palette;
    final tamamlandi = is_.job.status == _tamamlandi;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        onTap: () => context.push('/jobs/${is_.job.id}'),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: tamamlandi
                    ? palet.successSoft
                    : palet.accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: TcIcon(
                  tamamlandi ? TcIcons.checkCircle : TcIcons.briefcase,
                  size: 18,
                  color: tamamlandi ? palet.successText : palet.accent,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    is_.job.title,
                    style: Theme.of(context).textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _SiradakiIs._musteriSatiri(is_),
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: palet.textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  is_.job.startTime ?? '—',
                  style: AppTypography.mono.copyWith(fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  jobStatusLabels[is_.job.status] ?? is_.job.status,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: tamamlandi ? palet.successText : palet.textMuted,
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
