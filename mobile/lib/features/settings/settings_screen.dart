import 'package:flutter/material.dart';

import '../../shared/tc_icon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../app/palette.dart';
import '../../core/services/app_version_service.dart';
import '../../core/services/update_prompt.dart';
import '../../core/sync/sync_status.dart';
import '../../core/utils/dis_baglanti.dart';
import '../../shared/brand_footer.dart';
import '../../shared/ui.dart';
import '../auth/data/session_controller.dart';
import '../feedback/feedback_screen.dart';
import '../subscription/destek.dart';
import 'company_settings_screen.dart';
import 'data/theme_mode_controller.dart';
import 'job_types_screen.dart';
import 'notification_settings_screen.dart';
import 'personnel_screen.dart';
import 'profile_screen.dart';
import 'sync_status_screen.dart';

/// Yasal belgelerin yayında olduğu adresler.
///
/// Play, bunlara uygulama İÇİNDEN de ulaşılabilmesini istiyor; mağaza
/// listesindeki bağlantı tek başına yeterli sayılmıyor.
///
/// Uzantısız biçim kullanılıyor — Play Console'a verilen adreslerle aynı
/// olsun diye. Sunucuda her ikisi de servis ediliyor (bkz. deploy/apply.sh).
const _yayinAlanAdi = 'serviscep.cicibyte.com';
final _gizlilikUri = Uri.https(_yayinAlanAdi, '/privacy');
final _kosullarUri = Uri.https(_yayinAlanAdi, '/terms');
final _hesapSilmeUri = Uri.https(_yayinAlanAdi, '/account-deletion');

/// Ayarlar — hesap, işletme ve uygulama ayarları tek yerde.
///
/// "Daha Fazla" menüsü modüller (Takvim, Finans, Stok…) ve ayarları
/// birlikte barındırıp uzayınca aranan şey kaybolmaya başlamıştı; ayarlar
/// buraya toplandı, menüde yalnızca tek bir giriş kaldı.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palet = context.palette;
    final session = ref.watch(sessionControllerProvider).valueOrNull;
    final isOwner = session?.isOwner ?? false;

    final pending = ref.watch(pendingSyncCountProvider).valueOrNull ?? 0;
    final failed = ref.watch(failedSyncCountProvider).valueOrNull ?? 0;
    final temaKipi = ref.watch(themeModeControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const UpdateNoticeBanner(),
          const MenuGroupHeader('Hesap'),
          ListTile(
            leading: const TcIcon(TcIcons.user),
            title: const Text('Profilim'),
            subtitle: Text(session?.fullName ?? 'Ad, telefon, parola'),
            trailing: const TcIcon(TcIcons.chevronRight),
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const ProfileScreen())),
          ),
          if (isOwner) ...[
            ListTile(
              leading: const TcIcon(TcIcons.building),
              title: const Text('Şirket ayarları'),
              subtitle: const Text('Antet, logo, vergi bilgileri, IBAN'),
              trailing: const TcIcon(TcIcons.chevronRight),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const CompanySettingsScreen(),
                ),
              ),
            ),
            ListTile(
              leading: const TcIcon(TcIcons.users),
              title: const Text('Kullanıcılar ve yetkiler'),
              subtitle: const Text('Personel ekle, rollerini belirle'),
              trailing: const TcIcon(TcIcons.chevronRight),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PersonnelScreen()),
              ),
            ),
          ],

          const MenuGroupHeader('Uygulama'),
          ListTile(
            leading: const TcIcon(TcIcons.category),
            title: const Text('İş türleri'),
            subtitle: const Text('Kendi türlerini ekle'),
            trailing: const TcIcon(TcIcons.chevronRight),
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const JobTypesScreen())),
          ),
          ListTile(
            leading: const TcIcon(TcIcons.bell),
            title: const Text('Bildirimler'),
            subtitle: const Text('Hatırlatma süresi'),
            trailing: const TcIcon(TcIcons.chevronRight),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const NotificationSettingsScreen(),
              ),
            ),
          ),
          ListTile(
            leading: TcIcon(
              (pending > 0 || failed > 0) ? TcIcons.sync : TcIcons.cloudOk,
              color: failed > 0 ? palet.dangerText : null,
            ),
            title: const Text('Senkron durumu'),
            subtitle: Text(
              failed > 0
                  ? '$failed kayıt gönderilemedi'
                  : pending > 0
                  ? '$pending kayıt bekliyor'
                  : 'Her şey eşitlendi',
            ),
            trailing: const TcIcon(TcIcons.chevronRight),
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SyncStatusScreen())),
          ),
          ListTile(
            leading: const TcIcon(TcIcons.sun),
            title: const Text('Tema'),
            subtitle: Text(themeModeLabel(temaKipi)),
            trailing: const TcIcon(TcIcons.chevronRight),
            onTap: () => _temaSec(context, ref, temaKipi),
          ),
          const _UpdateTile(),

          const MenuGroupHeader('Destek'),
          ListTile(
            leading: const TcIcon(TcIcons.mail),
            title: const Text('Bize yaz'),
            subtitle: const Text('Öneri, sorun ya da soru gönder'),
            trailing: const TcIcon(TcIcons.chevronRight),
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const FeedbackScreen())),
          ),
          const _WhatsappTile(),

          const MenuGroupHeader('Yasal'),
          _BelgeTile(
            ikon: TcIcons.shield,
            baslik: 'Gizlilik Politikası',
            uri: _gizlilikUri,
          ),
          _BelgeTile(
            ikon: TcIcons.file,
            baslik: 'Kullanım Koşulları',
            uri: _kosullarUri,
          ),
          _BelgeTile(
            ikon: TcIcons.trash,
            baslik: 'Hesap silme talebi',
            uri: _hesapSilmeUri,
          ),

          const BrandFooter(),
        ],
      ),
    );
  }

  /// Tema seçimi alt sayfası.
  ///
  /// Üç seçenek de tek dokunuşta uygulanır ve sayfa kapanır; "kaydet"
  /// düğmesi yok çünkü sonuç anında ekranda görünüyor.
  Future<void> _temaSec(
    BuildContext context,
    WidgetRef ref,
    ThemeMode secili,
  ) async {
    final secim = await showModalBottomSheet<ThemeMode>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final kip in ThemeMode.values)
              ListTile(
                title: Text(themeModeLabel(kip)),
                trailing: kip == secili ? const TcIcon(TcIcons.check) : null,
                onTap: () => Navigator.pop(sheetContext, kip),
              ),
          ],
        ),
      ),
    );
    if (secim != null) {
      await ref.read(themeModeControllerProvider.notifier).ayarla(secim);
    }
  }
}

/// Yasal belge satırı — tarayıcıda açılır.
///
/// Açılmazsa kullanıcı bunu ÖĞRENİR ve adres panoya kopyalanır: bu
/// bağlantılar Android 11 paket görünürlüğü yüzünden aylarca sessizce
/// ölü kaldı (bkz. core/utils/dis_baglanti.dart).
class _BelgeTile extends StatelessWidget {
  const _BelgeTile({
    required this.ikon,
    required this.baslik,
    required this.uri,
  });

  final String ikon;
  final String baslik;
  final Uri uri;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: TcIcon(ikon),
      title: Text(baslik),
      subtitle: const Text('Tarayıcıda açılır'),
      trailing: const TcIcon(TcIcons.arrowRight),
      onTap: () => context.disBaglantiAc(uri),
    );
  }
}

/// WhatsApp destek hattı.
///
/// "Bize yaz" formu bir kaydı kuyruğa alıp cevabı bekletiyor; sahada
/// işi duran kullanıcının istediği bu değil, anında birine ulaşmak.
/// Numara yönetici tarafından boşaltılmışsa satır hiç çıkmaz.
class _WhatsappTile extends ConsumerWidget {
  const _WhatsappTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final numara = ref.watch(destekWhatsappProvider);
    if (numara == null) return const SizedBox.shrink();

    return ListTile(
      leading: const TcIcon(TcIcons.send),
      title: const Text('WhatsApp ile yaz'),
      subtitle: const Text('Destek hattına doğrudan mesaj gönder'),
      trailing: const TcIcon(TcIcons.arrowRight),
      onTap: () => context.disBaglantiAc(
        destekWhatsappUri(
          numara,
          'Merhaba, TeknikCEP hakkında yardım almak istiyorum.',
        ),
        hataMesaji: 'WhatsApp açılamadı. Bağlantı panoya kopyalandı.',
      ),
    );
  }
}

/// Güncelleme kontrolü — Play In-App Update.
///
/// Güncellemeler zaten arka planda kontrol ediliyor; buradaki buton
/// kullanıcının "acaba güncel miyim?" sorusunu kendi başına
/// cevaplayabilmesi için var. Play dışı bir kurulumda (ör. doğrudan APK)
/// bu akış çalışmaz, o durum kullanıcıya açıkça söylenir.
class _UpdateTile extends ConsumerStatefulWidget {
  const _UpdateTile();

  @override
  ConsumerState<_UpdateTile> createState() => _UpdateTileState();
}

class _UpdateTileState extends ConsumerState<_UpdateTile> {
  bool _checking = false;
  String? _version;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) {
        setState(() => _version = '${info.version} (${info.buildNumber})');
      }
    });
  }

  /// Güncelleme kontrolü sunucudan yapılır (bkz. AppVersionService):
  /// Play'in kendi kontrolü, sürüm cihaza yayılana kadar "güncel" diyor
  /// ve kullanıcı yeni sürümden haberdar olmuyordu.
  Future<void> _check() async {
    setState(() => _checking = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final info = await ref.read(appVersionServiceProvider).check();
      if (!mounted) return;

      if (info == null) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Şu an kontrol edilemedi, bağlantını kontrol et.'),
          ),
        );
        return;
      }

      if (!info.hasUpdate) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Uygulaman güncel.')),
        );
        return;
      }

      await startUpdate(context, ref, info);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const TcIcon(TcIcons.download),
      title: const Text('Güncellemeleri kontrol et'),
      subtitle: Text(_version == null ? 'Sürüm okunuyor…' : 'Sürüm $_version'),
      trailing: _checking
          ? const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const TcIcon(TcIcons.chevronRight),
      onTap: _checking ? null : _check,
    );
  }
}
