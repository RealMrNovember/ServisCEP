import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/motion.dart';
import '../app/palette.dart';
import '../app/theme.dart';
import '../app/typography.dart';
import '../core/sync/sync_service.dart';
import '../core/sync/sync_status.dart';
import '../features/settings/sync_status_screen.dart';
import 'tc_icon.dart';

/// Eşitleme Durumu ekranını açar.
///
/// Bu ekranın GoRouter rotası yok; uygulamanın başka yerlerinde de
/// doğrudan push ediliyor (bkz. settings_screen.dart).
void _esitlemeDurumunaGit(BuildContext context) {
  Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const SyncStatusScreen()));
}

/// Çevrimdışı göstergeleri — tasarım sistemi § 6.
///
/// Bu üç katman ürünün güven kazandığı yer. Temel kural şu:
///
/// **Sessizlik iyi haberdir.** Eşitlenmiş kayda hiçbir işaret konmaz;
/// yalnızca bekleyen kayıt işaretlenir. Her şeyin yanına "eşitlendi"
/// yazmak, gerçekten eşitlenmemiş olanı görünmez kılar.
///
/// **Cihaz gerçeği anlatılır.** Kaydetme anında "gönderiliyor" denmez.
/// Uygulamanın saatlerce sunucuya ulaşamadığı hâlde "her şey eşitlendi"
/// yazdığı bir sürüm yaşandı; bu metinler o yüzden ihtiyatlı.

/// Şeridin gösterebileceği durumlar.
enum SyncBannerState {
  /// Gösterilecek bir şey yok — şerit kapalı.
  hidden,

  /// Cihazın bağlantısı yok.
  offline,

  /// Gerçekten bir senkron turu çalışıyor.
  syncing,

  /// Bağlantı var, tur çalışmıyor, kuyrukta kayıt var.
  waiting,

  /// Kuyruk yeni boşaldı — kısa süre görünür.
  done,
}

/// Şerit durumunu üç sinyalden hesaplar.
///
/// [running] ile [pending] ayrımı bu fonksiyonun asıl sebebi. Kuyrukta
/// kayıt olması turun çalıştığı anlamına GELMEZ: cihazın interneti varken
/// bile sunucuya hiç ulaşılamayabiliyor ve bir sürümde tam olarak bu oldu.
/// O yüzden "Eşitleniyor" yalnızca gerçek bir tur çalışırken yazılır;
/// aksi hâlde "bekliyor" denir.
SyncBannerState syncBannerStateFor({
  required bool online,
  required int pending,
  required bool running,
}) {
  if (!online) return SyncBannerState.offline;
  if (running) return SyncBannerState.syncing;
  if (pending > 0) return SyncBannerState.waiting;
  return SyncBannerState.hidden;
}

/// Kullanıcının kapattığı şerit hâlâ kapalı kalmalı mı.
///
/// Kapatma, o ANKİ duruma bağlıdır; kalıcı bir "bir daha gösterme"
/// değildir. Durum değişirse ya da bekleyen kayıt sayısı artarsa şerit
/// yeniden çıkar — kullanıcı kapatırken henüz var olmayan kayıtlardan
/// haberdar olmalı.
///
/// Kötüleşme kontrolü bilerek tek yönlü: sayı DÜŞERSE şerit geri gelmez.
/// Kullanıcıyı iyi haberle rahatsız etmenin anlamı yok.
bool syncBannerStaysHidden({
  required SyncBannerState dismissedState,
  required int dismissedPending,
  required SyncBannerState currentState,
  required int currentPending,
}) {
  if (dismissedState != currentState) return false;
  if (currentPending > dismissedPending) return false;
  return true;
}

/// Üst çubuğun hemen altında duran global durum şeridi.
///
/// İçeriğin ÜSTÜNE binmez, aşağı iter — hiçbir eylem örtülmemeli.
/// Dokununca Eşitleme Durumu ekranına gider.
///
/// **Kapatılabilir, ama durum değişince geri gelir.** Tasarım sistemi
/// şeridi hiç kapatılamaz yapıyordu; gerekçesi kullanıcının durumu
/// kaybetmemesiydi. Uzun bir çevrimdışı çalışmada sürekli duran bir
/// şerit rahatsız edici olduğu için burada kapatılabilir yapıldı, fakat
/// kapatma yalnızca O ANKİ durum için geçerli: bağlantı durumu değişirse
/// ya da bekleyen kayıt sayısı artarsa şerit yeniden çıkar. Kalıcı ve
/// rahatsız etmeyen gösterge olarak üst çubuktaki [PendingBadge] duruyor.
class SyncBanner extends ConsumerStatefulWidget {
  const SyncBanner({super.key});

  @override
  ConsumerState<SyncBanner> createState() => _SyncBannerState();
}

class _SyncBannerState extends ConsumerState<SyncBanner> {
  /// "Tamamlandı" durumu kalıcı değildir: 2 saniye görünür, sonra kapanır.
  Timer? _tamamlandiZamanlayici;
  bool _tamamlandiGoster = false;
  SyncBannerState _oncekiDurum = SyncBannerState.hidden;

  /// Kullanıcının kapattığı durum. Aynı durum sürdüğü sürece şerit
  /// gösterilmez; durum değişir ya da kötüleşirse yeniden çıkar.
  ({SyncBannerState durum, int bekleyen})? _kapatilan;

  bool _kapaliKalmali(SyncBannerState durum, int bekleyen) {
    final kapatilan = _kapatilan;
    if (kapatilan == null) return false;
    return syncBannerStaysHidden(
      dismissedState: kapatilan.durum,
      dismissedPending: kapatilan.bekleyen,
      currentState: durum,
      currentPending: bekleyen,
    );
  }

  @override
  void dispose() {
    _tamamlandiZamanlayici?.cancel();
    super.dispose();
  }

  /// İş bittiğinde kısa bir "tamamlandı" gösterip kapanır.
  ///
  /// Yalnızca GERÇEKTEN bir iş yapıldıysa: uygulama açılışında kuyruk
  /// zaten boşsa kutlama yapılmaz, gürültü olur.
  void _durumDegisti(SyncBannerState yeni) {
    final calisiyordu =
        _oncekiDurum == SyncBannerState.syncing ||
        _oncekiDurum == SyncBannerState.waiting ||
        _oncekiDurum == SyncBannerState.offline;

    if (calisiyordu && yeni == SyncBannerState.hidden) {
      _tamamlandiZamanlayici?.cancel();
      _tamamlandiGoster = true;
      _tamamlandiZamanlayici = Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _tamamlandiGoster = false);
      });
    } else if (yeni != SyncBannerState.hidden && _tamamlandiGoster) {
      _tamamlandiZamanlayici?.cancel();
      _tamamlandiGoster = false;
    }

    _oncekiDurum = yeni;
  }

  @override
  Widget build(BuildContext context) {
    final cevrimici = ref.watch(isOnlineProvider).valueOrNull ?? true;
    final bekleyen = ref.watch(pendingSyncCountProvider).valueOrNull ?? 0;
    final servis = ref.watch(syncServiceProvider);

    return ValueListenableBuilder<bool>(
      valueListenable: servis.calisiyor,
      builder: (context, calisiyor, _) {
        final durum = syncBannerStateFor(
          online: cevrimici,
          pending: bekleyen,
          running: calisiyor,
        );

        // Yapı aşamasında setState çağrılamaz; durum geçişi kareden sonra
        // işlenir.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (durum != _oncekiDurum) setState(() => _durumDegisti(durum));
        });

        var gorunen = durum == SyncBannerState.hidden && _tamamlandiGoster
            ? SyncBannerState.done
            : durum;

        // "Tamamlandı" kutlaması zaten iki saniyelik; onu kapatma
        // kaydına takmanın anlamı yok.
        if (gorunen != SyncBannerState.done &&
            _kapaliKalmali(gorunen, bekleyen)) {
          gorunen = SyncBannerState.hidden;
        }

        return AnimatedSize(
          duration: AppMotion.base,
          curve: AppMotion.decelerate,
          alignment: Alignment.topCenter,
          child: gorunen == SyncBannerState.hidden
              ? const SizedBox(width: double.infinity)
              : Dismissible(
                  // Anahtar duruma bağlı: durum değişince Dismissible
                  // sıfırlanır ve yeni şerit kapanmış sayılmaz.
                  key: ValueKey<SyncBannerState>(gorunen),
                  direction: DismissDirection.horizontal,
                  onDismissed: (_) => setState(() {
                    _kapatilan = (durum: gorunen, bekleyen: bekleyen);
                  }),
                  child: _Serit(
                    durum: gorunen,
                    bekleyen: bekleyen,
                    onClose: () => setState(() {
                      _kapatilan = (durum: gorunen, bekleyen: bekleyen);
                    }),
                  ),
                ),
        );
      },
    );
  }
}

class _Serit extends StatelessWidget {
  const _Serit({required this.durum, required this.bekleyen, this.onClose});

  final SyncBannerState durum;
  final int bekleyen;

  /// Kapatma düğmesi. Verilmezse düğme çıkmaz ("tamamlandı" gibi kendi
  /// kendine kapanan durumlarda gereksiz).
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final palet = context.palette;

    final (zemin, cizgi, yazi, ikon, metin) = switch (durum) {
      SyncBannerState.offline => (
        palet.warningSoft,
        palet.warningLine,
        palet.warningText,
        TcIcons.cloudOff,
        bekleyen > 0
            ? 'Bağlantı yok — $bekleyen kayıt cihazda bekliyor'
            : 'Bağlantı yok — kayıtlar cihazda tutuluyor',
      ),
      SyncBannerState.syncing => (
        palet.accentSoft,
        palet.accentLine,
        palet.accentText,
        TcIcons.sync,
        bekleyen > 0 ? 'Eşitleniyor… $bekleyen kayıt' : 'Eşitleniyor…',
      ),
      SyncBannerState.waiting => (
        palet.warningSoft,
        palet.warningLine,
        palet.warningText,
        TcIcons.cloudOff,
        '$bekleyen kayıt gönderilmeyi bekliyor',
      ),
      SyncBannerState.done => (
        palet.successSoft,
        palet.successLine,
        palet.successText,
        TcIcons.cloudOk,
        'Tüm kayıtlar gönderildi',
      ),
      SyncBannerState.hidden => (
        palet.neutralSoft,
        palet.border,
        palet.textMuted,
        TcIcons.cloudOk,
        '',
      ),
    };

    return Material(
      color: zemin,
      child: Container(
        height: 36,
        width: double.infinity,
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: cizgi)),
        ),
        child: Row(
          children: [
            // Metnin kendisi Eşitleme Durumu ekranına götürür.
            Expanded(
              child: InkWell(
                onTap: () => _esitlemeDurumunaGit(context),
                child: Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.xl),
                  child: Row(
                    children: [
                      TcIcon(ikon, size: 18, color: yazi),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          metin,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.label.copyWith(color: yazi),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (onClose != null)
              // Dokunma hedefi 48dp; şerit 36dp olduğu için genişlikten
              // alınıyor. Eldivenli parmak küçük bir X'i tutturamıyor.
              Semantics(
                label: 'Şeridi kapat',
                button: true,
                child: InkWell(
                  onTap: onClose,
                  child: SizedBox(
                    width: AppSize.touch,
                    height: double.infinity,
                    child: Center(
                      child: TcIcon(TcIcons.x, size: 16, color: yazi),
                    ),
                  ),
                ),
              )
            else
              const SizedBox(width: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}

/// "Bekleyen N kayıt" rozeti — liste ekranlarının üst çubuğunda durur.
///
/// Sayı 0 olunca TAMAMEN kaybolur. "0 bekliyor" yazmak gürültüdür ve
/// kullanıcıyı sürekli bir uyarıya alıştırır.
class PendingBadge extends ConsumerWidget {
  const PendingBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bekleyen = ref.watch(pendingSyncCountProvider).valueOrNull ?? 0;
    if (bekleyen == 0) return const SizedBox.shrink();

    final palet = context.palette;

    return Semantics(
      label: '$bekleyen kayıt gönderilmeyi bekliyor',
      button: true,
      child: InkWell(
        onTap: () => _esitlemeDurumunaGit(context),
        borderRadius: AppRadius.pill,
        child: Container(
          height: AppSize.touch,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: palet.warningSoft,
            borderRadius: AppRadius.pill,
            border: Border.all(color: palet.warningLine),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TcIcon(TcIcons.cloudOff, size: 16, color: palet.warningText),
              const SizedBox(width: AppSpacing.xs + 2),
              Text(
                '$bekleyen',
                style: AppTypography.mono.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: palet.warningText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bir kaydın "cihaza yazıldı ama gönderilmedi" olduğunu söyleyen alt satır.
///
/// Kart ve detay ekranlarında kullanılır. Eşitlenmiş kayda hiçbir şey
/// eklenmez; bu satır YALNIZCA bekleyen kayıtta çıkar.
class PendingRecordNote extends StatelessWidget {
  const PendingRecordNote({super.key, this.detayli = false});

  /// Detay ekranında daha açık bir cümle kurulur.
  final bool detayli;

  @override
  Widget build(BuildContext context) {
    final palet = context.palette;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TcIcon(TcIcons.cloudOff, size: 15, color: palet.warningText),
        const SizedBox(width: AppSpacing.xs + 2),
        Flexible(
          child: Text(
            detayli
                ? 'Cihaza kaydedildi, bağlantı gelince gönderilecek'
                : 'Cihazda · gönderilmedi',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption.copyWith(color: palet.warningText),
          ),
        ),
      ],
    );
  }
}
