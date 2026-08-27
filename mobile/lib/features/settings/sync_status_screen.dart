import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/sync/sync_status.dart';
import '../../core/sync/sync_trigger.dart';
import '../sync/data/sync_conflict_repository.dart';
import '../sync/sync_conflicts_screen.dart';

/// Senkron durumu — "verim sunucuya ulaştı mı?" sorusunun cevabı.
///
/// Offline-first bir uygulamada kullanıcı yazdığı verinin cihazda mı
/// kaldığını yoksa ofise de ulaştığını bilemez; bu belirsizlik güveni
/// zedeler. Bu ekran durumu açıkça gösterir ve elle senkron imkânı verir.
class SyncStatusScreen extends ConsumerWidget {
  const SyncStatusScreen({super.key});

  static String _relative(DateTime? at) {
    if (at == null) return 'Henüz senkronlanmadı';
    final diff = DateTime.now().difference(at);
    if (diff.inMinutes < 1) return 'Az önce';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dakika önce';
    if (diff.inHours < 24) return '${diff.inHours} saat önce';
    return DateFormat('d MMM y HH:mm', 'tr_TR').format(at);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final lastSync = ref.watch(lastSyncProvider).valueOrNull;
    final pending = ref.watch(pendingSyncCountProvider).valueOrNull ?? 0;
    final failed = ref.watch(failedSyncCountProvider).valueOrNull ?? 0;
    final conflicts = ref.watch(localConflictCountProvider).valueOrNull ?? 0;
    final online = ref.watch(isOnlineProvider).valueOrNull;

    // "Eşitlendi" demek için kuyruğun boş olması YETMEZ.
    //
    // Kuyruk boş olması yalnızca gönderilecek bir şey olmadığını gösterir;
    // sunucuya ulaşılıp ulaşılmadığını değil. Bir sürümde uygulama
    // saatlerce sunucuya hiç bağlanamadı ve bu ekran boyunca "her şey
    // eşitlendi" yazdı. Tek dürüst kanıt, son BAŞARILI senkronun ne kadar
    // yakın olduğu.
    final kuyrukTemiz = pending == 0 && failed == 0 && conflicts == 0;
    final taze =
        lastSync != null &&
        DateTime.now().difference(lastSync).abs() < syncFreshnessWindow;
    final allClear = kuyrukTemiz && taze;

    final (String baslik, IconData ikon) = switch ((kuyrukTemiz, taze)) {
      (true, true) => ('Her şey eşitlendi', Icons.cloud_done_rounded),
      (true, false) when lastSync == null => (
        'Henüz eşitlenmedi',
        Icons.cloud_off_rounded,
      ),
      (true, false) => ('Bir süredir eşitlenemedi', Icons.cloud_off_rounded),
      _ => ('Bekleyen değişiklikler var', Icons.cloud_sync_rounded),
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Senkron durumu')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: allClear
                  ? scheme.primaryContainer
                  : scheme.tertiaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Icon(
                  ikon,
                  size: 44,
                  color: allClear
                      ? scheme.onPrimaryContainer
                      : scheme.onTertiaryContainer,
                ),
                const SizedBox(height: 12),
                Text(
                  baslik,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: allClear
                        ? scheme.onPrimaryContainer
                        : scheme.onTertiaryContainer,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Son senkron: ${_relative(lastSync)}',
                  style: TextStyle(
                    fontSize: 13,
                    color:
                        (allClear
                                ? scheme.onPrimaryContainer
                                : scheme.onTertiaryContainer)
                            .withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          _StatusRow(
            icon: online == false ? Icons.wifi_off_rounded : Icons.wifi_rounded,
            label: 'Bağlantı',
            value: switch (online) {
              true => 'Çevrimiçi',
              false => 'Çevrimdışı',
              null => 'Kontrol ediliyor…',
            },
            warn: online == false,
          ),
          _StatusRow(
            icon: Icons.upload_rounded,
            label: 'Gönderilmeyi bekleyen',
            value: '$pending kayıt',
            warn: pending > 0,
          ),
          if (failed > 0)
            _StatusRow(
              icon: Icons.error_outline_rounded,
              label: 'Gönderilemeyen',
              value: '$failed kayıt — dokun, yeniden dene',
              warn: true,
              // Kalıcı hata almış kayıtlar için ARAYÜZDE HİÇBİR YOL YOKTU:
              // satır yalnızca sayıyı gösteriyor, dokunulamıyordu ve hiçbir
              // kod FAILED'i tekrar kuyruğa almıyordu (çakışma satırının
              // aksine). Kayıt kullanıcının telefonunda kalıcı mahsur
              // kalıyordu.
              onTap: () => _yenidenDene(context, ref),
            ),
          if (conflicts > 0)
            _StatusRow(
              icon: Icons.sync_problem_rounded,
              label: 'Çakışma',
              value: '$conflicts kayıt',
              warn: true,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SyncConflictsScreen()),
              ),
            ),

          const SizedBox(height: 20),
          const _SyncNowButton(),

          const SizedBox(height: 16),
          Text(
            switch ((pending > 0, taze)) {
              (true, _) =>
                'Bekleyen kayıtlar cihazında güvenle duruyor. Bağlantı '
                    'kurulduğunda otomatik gönderilir; uygulama kapalıyken de '
                    'arka planda düzenli olarak denenir.',
              (false, true) =>
                'Verilerin sunucuyla eşitlenmiş durumda. Uygulama bağlantı '
                    'geldiğinde, öne alındığında ve birkaç dakikada bir '
                    'otomatik senkronlanır.',
              (false, false) =>
                'Gönderilmeyi bekleyen bir kayıt yok, ancak bir süredir '
                    'sunucuya ulaşılamadı. Cihazın internete bağlı olması '
                    'sunucuya erişebildiği anlamına gelmez; ofisteki '
                    'değişiklikler bu telefona inmemiş olabilir.',
            },
            style: TextStyle(
              fontSize: 12.5,
              color: scheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.icon,
    required this.label,
    required this.value,
    this.warn = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool warn;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = warn ? scheme.error : scheme.onSurfaceVariant;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color, size: 22),
      title: Text(label, style: const TextStyle(fontSize: 14.5)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: warn ? scheme.error : scheme.onSurface,
            ),
          ),
          if (onTap != null) const Icon(Icons.chevron_right, size: 20),
        ],
      ),
      onTap: onTap,
    );
  }
}

/// Elle senkron düğmesi.
///
/// Sonucu BEKLER ve gerçekten olanı bildirir. Önceden koşulsuz "Senkron
/// başlatıldı" diyordu; sunucuya hiç ulaşılamadığında bile. Olmayan bir
/// başarıyı bildirmek, ekranın tamamına olan güveni zedeliyor.
/// Kalıcı hata almış kayıtları yeniden kuyruğa alır ve hemen bir tur başlatır.
Future<void> _yenidenDene(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  final adet = await ref.read(syncTriggerProvider).retryFailed();
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        adet > 0
            ? '$adet kayıt yeniden gönderim sırasına alındı.'
            : 'Yeniden denenecek kayıt yok.',
      ),
    ),
  );
}

class _SyncNowButton extends ConsumerStatefulWidget {
  const _SyncNowButton();

  @override
  ConsumerState<_SyncNowButton> createState() => _SyncNowButtonState();
}

class _SyncNowButtonState extends ConsumerState<_SyncNowButton> {
  bool _calisiyor = false;

  Future<void> _senkronla() async {
    setState(() => _calisiyor = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final basarili = await ref.read(syncTriggerProvider).syncNowAndWait();
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            basarili
                ? 'Senkron tamamlandı.'
                : 'Sunucuya ulaşılamadı. Bağlantını kontrol edip tekrar dene.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _calisiyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: _calisiyor ? null : _senkronla,
      icon: _calisiyor
          ? const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.sync_rounded),
      label: Text(_calisiyor ? 'Senkronlanıyor…' : 'Şimdi senkronla'),
    );
  }
}
