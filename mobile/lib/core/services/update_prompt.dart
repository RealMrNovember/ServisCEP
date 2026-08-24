import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'play_update_service.dart';

/// Uygulama her açıldığında bir kez güncelleme kontrolü yapılmasını sağlar.
///
/// Tasarım kararı: hatırlatma "her açılışta" gösterilir ama ASLA zorunlu
/// değildir. Kullanıcının işi acil olabilir; "Sonra" diyebilmeli ve
/// uygulamayı kullanmaya devam edebilmelidir. Zorunlu (immediate) güncelleme
/// akışı bilerek kullanılmıyor — saha çalışanını iş başındayken kilitler.
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

final updatePromptProvider =
    StateNotifierProvider<UpdatePromptState, bool>((ref) {
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

    final result = await playUpdateService.checkForUpdate();
    if (result != UpdateCheckResult.available || !mounted) return;

    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => const _UpdateDialog(),
    );

    if (accepted != true) return;

    await playUpdateService.checkAndStartFlexibleUpdate(
      onReadyToInstall: () {
        if (mounted) {
          ref.read(playUpdateReadyProvider.notifier).markReady();
        }
      },
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Güncelleme arka planda indiriliyor. Uygulamayı kullanmaya '
          'devam edebilirsin.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _UpdateDialog extends StatelessWidget {
  const _UpdateDialog();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

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
      title: const Text('Yeni sürüm hazır'),
      content: const Text(
        'TeknikCEP\'in yeni bir sürümü var. Güncelleme arka planda iner, '
        'çalışmana ara vermen gerekmez.',
        textAlign: TextAlign.center,
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
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
