import 'package:flutter/material.dart';

import '../../shared/tc_icon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/palette.dart';
import '../../app/theme.dart';
import '../../core/database/app_database.dart';
import '../../core/sync/device_storage.dart';
import '../../core/sync/sync_status.dart';
import '../../shared/ui.dart';
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
    final palet = context.palette;
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

    // Başlık, sorunu ADIYLA söyler.
    //
    // Eskiden failed ve conflict, pending ile aynı torbaya atılıp
    // "Bekleyen değişiklikler var" deniyordu. Ekranda "Gönderilmeyi
    // bekleyen: 0 kayıt" yazarken başlığın "bekleyen değişiklik" demesi
    // kullanıcıyı neyin yanlış olduğunu aramaya bırakıyordu — üstelik
    // asıl sorun (gönderilemeyen kayıt) kendiliğinden düzelmiyor.
    final (String baslik, String ikon) = switch ((
      failed > 0,
      conflicts > 0,
      pending > 0,
      taze,
    )) {
      (true, _, _, _) => ('Gönderilemeyen kayıt var', TcIcons.alertCircle),
      (_, true, _, _) => ('Çakışma çözülmeyi bekliyor', TcIcons.syncProblem),
      (_, _, true, _) => ('Gönderilmeyi bekleyenler var', TcIcons.sync),
      (_, _, _, true) => ('Her şey eşitlendi', TcIcons.cloudOk),
      _ when lastSync == null => ('Henüz eşitlenmedi', TcIcons.cloudOff),
      _ => ('Bir süredir eşitlenemedi', TcIcons.cloudOff),
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Eşitleme durumu')),
      body: ListView(
        // Alt boşluk gezinme çubuğunu hesaba katıyor: bu ekran sekme
        // kabuğunun İÇİNDE açılıyor ve çubuk üstünde duruyor. 40dp'lik
        // sabit boşlukla son paragraf çubuğun altında kalıp kesiliyordu.
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.xl,
          AppSpacing.xl,
          AppSize.nav + AppSpacing.xxl,
        ),
        children: [
          AppCard(
            accent: allClear,
            child: Column(
              children: [
                TcIcon(
                  ikon,
                  size: 40,
                  color: allClear
                      ? palet.successText
                      : (failed > 0 || conflicts > 0
                            ? palet.dangerText
                            : palet.warningText),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(baslik, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Son eşitleme: ${_relative(lastSync)}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: palet.textMuted),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          _StatusRow(
            icon: online == false ? TcIcons.cloudOff : TcIcons.wifi,
            label: 'Bağlantı',
            value: switch (online) {
              true => 'Çevrimiçi',
              false => 'Çevrimdışı',
              null => 'Kontrol ediliyor…',
            },
            warn: online == false,
          ),
          _StatusRow(
            icon: TcIcons.upload,
            label: 'Gönderilmeyi bekleyen',
            value: '$pending kayıt',
            warn: pending > 0,
          ),
          if (failed > 0)
            _StatusRow(
              icon: TcIcons.alertCircle,
              label: 'Gönderilemeyen',
              value: '$failed kayıt',
              hint: 'Dokun, yeniden dene',
              warn: true,
              // Kalıcı hata almış kayıtlar için ARAYÜZDE HİÇBİR YOL YOKTU:
              // satır yalnızca sayıyı gösteriyor, dokunulamıyordu ve hiçbir
              // kod FAILED'i tekrar kuyruğa almıyordu (çakışma satırının
              // aksine). Kayıt kullanıcının telefonunda kalıcı mahsur
              // kalıyordu.
              onTap: () => _yenidenDene(context, ref),
            ),
          // Hangi kayıt, neden gönderilemedi. Yeniden denemekten başka
          // bilgisi olmayan kullanıcı, sorunun geçici mi kalıcı mı
          // olduğunu ayırt edemiyordu.
          if (failed > 0)
            ...ref
                .watch(failedSyncOperationsProvider)
                .maybeWhen(
                  data: (satirlar) =>
                      satirlar.map((satir) => _GonderilemeyenSatir(op: satir)),
                  orElse: () => const <Widget>[],
                ),

          if (conflicts > 0)
            _StatusRow(
              icon: TcIcons.syncProblem,
              label: 'Çakışma',
              value: '$conflicts kayıt',
              warn: true,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SyncConflictsScreen()),
              ),
            ),

          const SizedBox(height: AppSpacing.xxl),
          const SectionHeader(
            'Cihaz',
            subtitle: 'Verilerin bu telefonda ne kadar yer kaplıyor.',
          ),
          ref
              .watch(deviceStorageProvider)
              .when(
                loading: () => const _StatusRow(
                  icon: TcIcons.layers,
                  label: 'Yerel veritabanı',
                  value: 'hesaplanıyor…',
                ),
                error: (_, _) => const SizedBox.shrink(),
                data: (yer) => Column(
                  children: [
                    _StatusRow(
                      icon: TcIcons.layers,
                      label: 'Yerel veritabanı',
                      value: formatBytes(yer.databaseBytes),
                    ),
                    _StatusRow(
                      icon: TcIcons.image,
                      label: 'Fotoğraf ve imzalar',
                      value: formatBytes(yer.mediaBytes),
                    ),
                  ],
                ),
              ),

          const SizedBox(height: AppSpacing.xl),
          const _SyncNowButton(),

          const SizedBox(height: 16),
          Text(
            // Bu metin de başlıkla AYNI önceliği izliyor. Üç ayrı yerde
            // (şerit, başlık, bu metin) üç farklı durum hesaplanınca ekran
            // kendi kendisiyle çelişiyordu: şerit "Tüm kayıtlar
            // gönderildi", başlık "Bekleyen değişiklikler var", burası
            // "Verilerin sunucuyla eşitlenmiş durumda" diyordu — hepsi
            // aynı anda, bir kayıt gönderilememişken.
            switch ((failed > 0, conflicts > 0, pending > 0, taze)) {
              (true, _, _, _) =>
                'Bu kayıtlar kalıcı bir hata aldı ve kendiliğinden '
                    'gönderilmeyecek. Satıra dokunup yeniden dene; sorun '
                    'sürerse kayıt cihazında duruyor, kaybolmaz.',
              (_, true, _, _) =>
                'Aynı kayıt hem bu cihazda hem sunucuda değişmiş. Hangi '
                    'halin kalacağını sen seçene kadar hiçbir veri '
                    'üzerine yazılmaz.',
              (_, _, true, _) =>
                'Bekleyen kayıtlar cihazında güvenle duruyor. Bağlantı '
                    'kurulduğunda otomatik gönderilir; uygulama kapalıyken de '
                    'arka planda düzenli olarak denenir.',
              (_, _, _, true) =>
                'Verilerin sunucuyla eşitlenmiş durumda. Uygulama bağlantı '
                    'geldiğinde, öne alındığında ve birkaç dakikada bir '
                    'otomatik senkronlanır.',
              _ =>
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
    this.hint,
    this.warn = false,
    this.onTap,
  });

  /// [TcIcons] adı.
  final String icon;
  final String label;
  final String value;

  /// Değerin altına düşen kısa açıklama.
  final String? hint;
  final bool warn;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palet = context.palette;
    final color = warn ? palet.dangerText : palet.textMuted;

    // ListTile DEĞİL.
    //
    // ListTile, `trailing`e istediği genişliği verip `title`dan kırpıyor:
    // değer uzayınca etiket ("Gönderilemeyen") satır sonunda HECE
    // GÖZETMEDEN bölünüyordu ("Gönderilemeye / n"). Burada genişlik iki
    // taraf arasında paylaştırılıyor ve etiket asla bölünmüyor.
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TcIcon(icon, color: color, size: 22),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    value,
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: warn ? palet.dangerText : palet.text,
                    ),
                  ),
                  if (hint != null)
                    Text(
                      hint!,
                      textAlign: TextAlign.right,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: warn ? palet.dangerText : palet.textMuted,
                      ),
                    ),
                ],
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: AppSpacing.xs),
              TcIcon(TcIcons.chevronRight, size: 20, color: palet.textMuted),
            ],
          ],
        ),
      ),
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
          : const TcIcon(TcIcons.sync),
      label: Text(_calisiyor ? 'Senkronlanıyor…' : 'Şimdi senkronla'),
    );
  }
}

/// Türkçe varlık adları — kullanıcı 'service_request' okumamalı.
const _varlikAdlari = {
  'customer': 'Müşteri',
  'job': 'İş',
  'service_request': 'Servis talebi',
  'quote': 'Teklif',
  'proforma': 'Proforma',
  'payment': 'Tahsilat',
  'income_entry': 'Gelir kaydı',
  'expense_entry': 'Gider kaydı',
  'job_note': 'İş notu',
  'job_photo': 'İş fotoğrafı',
  'job_signature': 'İmza',
};

/// Gönderilemeyen tek bir kayıt.
class _GonderilemeyenSatir extends StatelessWidget {
  const _GonderilemeyenSatir({required this.op});

  final SyncOperation op;

  @override
  Widget build(BuildContext context) {
    final palet = context.palette;
    final ad = _varlikAdlari[op.entityType] ?? op.entityType;
    final eylem = switch (op.operation) {
      'CREATE' => 'oluşturma',
      'UPDATE' => 'güncelleme',
      'DELETE' => 'silme',
      'CONVERT' => 'işe çevirme',
      _ => op.operation.toLowerCase(),
    };

    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.x3l,
        bottom: AppSpacing.sm,
      ),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$ad — $eylem', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 2),
            Text(
              // Sunucunun kendi mesajı gösteriliyor: "bir hata oluştu"
              // demek, destek talebi geldiğinde nedeni bulmayı imkânsız
              // kılıyor. Mesaj Türkçe ve kullanıcıya dönük yazılıyor
              // (bkz. backend doğrulama mesajları).
              op.lastError?.trim().isNotEmpty == true
                  ? op.lastError!.trim()
                  : 'Sunucu bir sebep bildirmedi.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: palet.textMuted),
            ),
            if (op.attemptCount > 0) ...[
              const SizedBox(height: 2),
              Text(
                '${op.attemptCount} deneme',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: palet.textFaint),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
