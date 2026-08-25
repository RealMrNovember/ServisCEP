import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/services/app_version_service.dart';
import '../../core/services/update_prompt.dart';
import '../../core/sync/sync_status.dart';
import '../../shared/brand_footer.dart';
import '../auth/data/session_controller.dart';
import 'company_settings_screen.dart';
import 'job_types_screen.dart';
import 'notification_settings_screen.dart';
import 'personnel_screen.dart';
import 'profile_screen.dart';
import 'sync_status_screen.dart';

/// Ayarlar — hesap, işletme ve uygulama ayarları tek yerde.
///
/// "Daha Fazla" menüsü modüller (Takvim, Finans, Stok…) ve ayarları
/// birlikte barındırıp uzayınca aranan şey kaybolmaya başlamıştı; ayarlar
/// buraya toplandı, menüde yalnızca tek bir giriş kaldı.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final session = ref.watch(sessionControllerProvider).valueOrNull;
    final isOwner = session?.isOwner ?? false;

    final pending = ref.watch(pendingSyncCountProvider).valueOrNull ?? 0;
    final failed = ref.watch(failedSyncCountProvider).valueOrNull ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _SectionTitle('Hesabım'),
          ListTile(
            leading: const Icon(Icons.person_outline_rounded),
            title: const Text('Profilim'),
            subtitle: const Text('Ad, telefon, parola'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const ProfileScreen())),
          ),

          if (isOwner) ...[
            _SectionTitle('İşletme'),
            ListTile(
              leading: const Icon(Icons.business_outlined),
              title: const Text('Şirket ayarları'),
              subtitle: const Text('Ünvan, işletme türü, IBAN'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const CompanySettingsScreen(),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.people_alt_outlined),
              title: const Text('Kullanıcılar ve yetkiler'),
              subtitle: const Text('Personel ekle, rollerini belirle'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PersonnelScreen()),
              ),
            ),
          ],

          _SectionTitle('Uygulama'),
          ListTile(
            leading: const Icon(Icons.category_outlined),
            title: const Text('İş türleri'),
            subtitle: const Text('Kendi türlerini ekle'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const JobTypesScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Bildirimler'),
            subtitle: const Text('Hatırlatma süresi'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const NotificationSettingsScreen(),
              ),
            ),
          ),
          ListTile(
            leading: Icon(
              (pending > 0 || failed > 0)
                  ? Icons.cloud_sync_rounded
                  : Icons.cloud_done_outlined,
              color: failed > 0 ? scheme.error : null,
            ),
            title: const Text('Senkron durumu'),
            subtitle: Text(
              failed > 0
                  ? '$failed kayıt gönderilemedi'
                  : pending > 0
                  ? '$pending kayıt bekliyor'
                  : 'Her şey eşitlendi',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SyncStatusScreen())),
          ),
          const _UpdateTile(),

          const BrandFooter(),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
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
      leading: const Icon(Icons.system_update_alt_rounded),
      title: const Text('Güncellemeleri kontrol et'),
      subtitle: Text(_version == null ? 'Sürüm okunuyor…' : 'Sürüm $_version'),
      trailing: _checking
          ? const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.chevron_right),
      onTap: _checking ? null : _check,
    );
  }
}
