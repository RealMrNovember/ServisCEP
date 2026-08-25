import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme.dart';
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

    final info = await ref.read(appVersionServiceProvider).check();
    if (info == null || !info.hasUpdate || !mounted) return;

    final accepted = await showDialog<bool>(
      context: context,
      // Zorunlu güncellemede pencere kapatılamaz.
      barrierDismissible: !info.isMandatory,
      builder: (context) => PopScope(
        canPop: !info.isMandatory,
        child: _UpdateDialog(info: info),
      ),
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

class _UpdateDialog extends StatelessWidget {
  const _UpdateDialog({required this.info});

  final AppVersionInfo info;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final notes = info.notes?.trim();

    return AlertDialog(
      icon: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.system_update_alt_rounded,
          color: scheme.onPrimaryContainer,
          size: 28,
        ),
      ),
      title: Text(
        info.latestVersion == null
            ? 'Yeni sürüm hazır'
            : 'Yeni sürüm hazır (${info.latestVersion})',
        textAlign: TextAlign.center,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            info.isMandatory
                ? 'Devam edebilmek için uygulamayı güncellemen gerekiyor.'
                : 'TeknikCEP\'in yeni bir sürümü var.',
            textAlign: TextAlign.center,
          ),
          if (notes != null && notes.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: AppRadius.field,
              ),
              child: Text(
                notes,
                style: const TextStyle(fontSize: 13, height: 1.45),
              ),
            ),
          ],
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        if (!info.isMandatory)
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Sonra'),
          ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Şimdi güncelle'),
        ),
      ],
    );
  }
}
