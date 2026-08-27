import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/palette.dart';
import '../../app/theme.dart';
import '../../shared/tc_icon.dart';
import '../../shared/ui.dart';
import '../sync/sync_status.dart';
import 'app_version_service.dart';
import 'play_update_service.dart';

/// Uygulama her açıldığında bir kez güncelleme kontrolü yapılmasını sağlar.
///
/// Kontrol KENDİ SUNUCUMUZA sorulur (bkz. [AppVersionService]). Play'in
/// kendi kontrolü, sürüm o cihaza yayılana kadar sessiz kalıyordu ve bu
/// saatler sürebiliyor; kullanıcı güncellemeden haberdar olmuyordu.
///
/// Tasarım kararı: hatırlatma "her açılışta" gösterilir ama normalde ASLA
/// zorunlu değildir. Kullanıcının işi acil olabilir; "Sonra" diyebilmeli.
/// Tek istisna, sunucunun `min_build` ile bildirdiği durumdur — o da
/// yalnızca sunucu sözleşmesi kırıldığında kullanılır.
///
/// "Sonra" seçimi KALICI OLARAK saklanmaz: kullanıcı güncellemeyi
/// atladığında bir dahaki açılışta yeniden sorulur (kullanıcı isteği).
/// Aynı oturum içinde ise tekrar tekrar sorulmaz.
class UpdatePromptState extends StateNotifier<bool> {
  UpdatePromptState() : super(false);

  bool _askedThisSession = false;

  bool get shouldAsk => !_askedThisSession;

  void markAsked() {
    _askedThisSession = true;
    state = true;
  }
}

final updatePromptProvider = StateNotifierProvider<UpdatePromptState, bool>((
  ref,
) {
  return UpdatePromptState();
});

/// Alt ağacı sarar; ilk çizimden sonra bir kez güncelleme kontrolü yapıp
/// gerekiyorsa kullanıcıya sorar.
class UpdatePromptGate extends ConsumerStatefulWidget {
  const UpdatePromptGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<UpdatePromptGate> createState() => _UpdatePromptGateState();
}

class _UpdatePromptGateState extends ConsumerState<UpdatePromptGate> {
  @override
  void initState() {
    super.initState();
    // İlk kare çizildikten sonra: açılış anında diyalog göstermek hem
    // görsel olarak sarsıcı hem de context henüz hazır olmayabilir.
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybePrompt());
  }

  Future<void> _maybePrompt() async {
    final controller = ref.read(updatePromptProvider.notifier);
    if (!controller.shouldAsk) return;
    controller.markAsked();

    final info = await ref.read(availableUpdateProvider.future);
    if (info == null || !info.hasUpdate || !mounted) return;

    // İsteğe bağlı güncellemede DİYALOG AÇILMAZ.
    //
    // Her açılışta çıkan bir pencere, sahada işe yetişmeye çalışan
    // kullanıcının önünü kesiyordu. Haber yine veriliyor ama araya
    // girmeyen bir şeritle (bkz. [UpdateBanner]).
    if (!info.isMandatory) return;

    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          PopScope(canPop: false, child: _UpdateDialog(info: info)),
    );

    if (accepted != true || !mounted) return;
    await startUpdate(context, ref, info);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Güncellemeyi başlatır.
///
/// Önce Play'in arka planda indirme akışı denenir — kullanıcı uygulamadan
/// çıkmadan güncellenebiliyorsa en iyisi budur. Play bunu sunamıyorsa
/// (sürüm cihaza henüz yayılmamış olabilir; sunucu zaten yayında diyor)
/// mağaza sayfası açılır. Android'de bir uygulamanın kendini güncellemesinin
/// başka yolu yok.
Future<void> startUpdate(
  BuildContext context,
  WidgetRef ref,
  AppVersionInfo info,
) async {
  final messenger = ScaffoldMessenger.of(context);

  final playResult = await playUpdateService.checkForUpdate();
  if (playResult == UpdateCheckResult.available) {
    await playUpdateService.checkAndStartFlexibleUpdate(
      onReadyToInstall: () =>
          ref.read(playUpdateReadyProvider.notifier).markReady(),
    );
    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          'Güncelleme arka planda indiriliyor. Uygulamayı kullanmaya '
          'devam edebilirsin.',
        ),
      ),
    );
    return;
  }

  final url = info.storeUrl;
  if (url == null || url.isEmpty) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Mağaza bağlantısı bulunamadı.')),
    );
    return;
  }

  final opened = await launchUrl(
    Uri.parse(url),
    mode: LaunchMode.externalApplication,
  );
  if (!opened) {
    messenger.showSnackBar(const SnackBar(content: Text('Mağaza açılamadı.')));
  }
}

/// Zorunlu güncelleme diyaloğu — tasarım teslimatı ekran 38.
///
/// Yalnızca sunucu `min_build` ile bu kurulumu dışarıda bıraktığında
/// çıkar. Kapatılamaz ve tek çıkış yolu mağaza; bu yüzden tehlike
/// tonunda. Kullanıcının ilk korkusu "cihazımdaki kayıtlar ne olacak"
/// olduğu için cevabı metnin içinde yazıyor.
class _UpdateDialog extends ConsumerWidget {
  const _UpdateDialog({required this.info});

  final AppVersionInfo info;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palet = context.palette;
    final bekleyen = ref.watch(pendingSyncCountProvider).valueOrNull ?? 0;

    return AlertDialog(
      icon: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: palet.dangerText.withValues(alpha: 0.14),
          shape: BoxShape.circle,
        ),
        child: TcIcon(TcIcons.download, color: palet.dangerText, size: 26),
      ),
      title: Text(
        info.latestVersion == null
            ? 'Güncelleme zorunlu'
            : 'Güncelleme zorunlu · ${info.latestVersion}',
        textAlign: TextAlign.center,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            bekleyen > 0
                ? 'Bu sürüm artık sunucuyla eşitlenemiyor. Cihazdaki '
                      '$bekleyen kaydın korunuyor; güncelledikten sonra '
                      'gönderilecek.'
                : 'Bu sürüm artık sunucuyla eşitlenemiyor. Devam edebilmek '
                      'için güncellemen gerekiyor.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Bu pencere kapatılamaz',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: palet.textMuted),
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Mağazaya Git'),
        ),
      ],
    );
  }
}

/// Açılışta yapılan güncelleme kontrolünün sonucu.
///
/// Hem şerit hem de zorunlu diyalog aynı sonucu okuyor; iki ayrı istek
/// atmak, uygulama her açıldığında sunucuya iki kez sormak demekti.
final availableUpdateProvider = FutureProvider<AppVersionInfo?>((ref) async {
  return ref.read(appVersionServiceProvider).check();
});

/// Bu oturumda şeridi kapattı mı?
///
/// Kalıcı saklanmıyor: kullanıcı bir dahaki açılışta yeniden görsün
/// isteniyor (kullanıcı isteği) ama aynı oturumda tekrar tekrar
/// çıkmasın.
final _seritKapatildiProvider = StateProvider<bool>((ref) => false);

/// İsteğe bağlı güncelleme şeridi — tasarım teslimatı ekran 37.
///
/// Diyalog DEĞİL şerit: her açılışta ortaya çıkan bir diyalog, sahada
/// işe yetişmeye çalışan kullanıcının önünü kesiyor ve "yine ne var"
/// tepkisi doğuruyor. Aksan tonunda, kapatılabilir ve işin akışını
/// kesmiyor. Zorunlu güncelleme bunun tersi: kapatılamayan diyalog
/// (bkz. [UpdatePromptGate]).
///
/// `shared/update_banner.dart` içindeki `UpdateBanner` ile KARIŞTIRMA: o,
/// Play dışı (GitHub sideload) kurulumlar için APK indiren eski akış ve
/// Play'den kurulmuş uygulamada kendini gizliyor. Bu ise Play In-App
/// Update akışını başlatıyor.
class UpdateNoticeBanner extends ConsumerWidget {
  const UpdateNoticeBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palet = context.palette;
    final info = ref.watch(availableUpdateProvider).valueOrNull;
    final kapatildi = ref.watch(_seritKapatildiProvider);

    // Zorunlu güncellemede şerit çizilmiyor: onu diyalog karşılıyor ve
    // ikisinin aynı anda görünmesi kullanıcıyı iki kez uyarırdı.
    if (info == null || !info.hasUpdate || info.isMandatory || kapatildi) {
      return const SizedBox.shrink();
    }

    final notlar = info.notes?.trim();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        0,
      ),
      child: AppCard(
        accent: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                TcIcon(TcIcons.sparkle, size: 18, color: palet.accent),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    info.latestVersion == null
                        ? 'Yeni sürüm hazır'
                        : 'Yeni sürüm hazır · ${info.latestVersion}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                SizedBox(
                  width: 28,
                  height: 28,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    iconSize: 16,
                    tooltip: 'Kapat',
                    icon: const TcIcon(TcIcons.x, size: 16),
                    onPressed: () =>
                        ref.read(_seritKapatildiProvider.notifier).state = true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              notlar == null || notlar.isEmpty
                  ? 'Uygun bir zamanda güncelle; işin yarıda kalmaz.'
                  : notlar,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: palet.textMuted),
            ),
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(
                onPressed: () => startUpdate(context, ref, info),
                child: const Text('Güncelle'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
