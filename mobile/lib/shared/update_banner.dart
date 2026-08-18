import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/apk_updater.dart';
import '../core/services/update_checker.dart';

/// Yeni sürüm bulunduğunda gösterilen bildirim şeridi — bkz. docs/06 §
/// Mobil Uygulama Otomatik Güncelleme.
///
/// Güncelleme tamamen uygulama içinde indirilir ve Android yükleyicisi
/// doğrudan açılır — tarayıcıya/GitHub sayfasına yönlendirme YOK.
class UpdateBanner extends ConsumerStatefulWidget {
  const UpdateBanner({super.key});

  @override
  ConsumerState<UpdateBanner> createState() => _UpdateBannerState();
}

enum _DownloadState { idle, downloading, error }

class _UpdateBannerState extends ConsumerState<UpdateBanner> {
  _DownloadState _state = _DownloadState.idle;
  double _progress = 0;
  String? _errorMessage;

  Future<void> _startUpdate(UpdateInfo update) async {
    setState(() {
      _state = _DownloadState.downloading;
      _progress = 0;
      _errorMessage = null;
    });
    try {
      await apkUpdater.downloadAndInstall(
        update,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      if (mounted) setState(() => _state = _DownloadState.idle);
    } on ApkInstallException catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _DownloadState.error;
        _errorMessage = e.isPermissionDenied
            ? 'Yükleme için "bilinmeyen kaynaklardan yükleme" iznini onaylaman gerekiyor. '
                  'İzni verdikten sonra tekrar dene.'
            : 'İndirilen dosya açılamadı. Tekrar dene.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _state = _DownloadState.error;
        _errorMessage = 'İndirme başarısız oldu. Bağlantını kontrol edip tekrar dene.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final updateAsync = ref.watch(updateInfoProvider);
    final update = updateAsync.valueOrNull;
    if (update == null) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final isDownloading = _state == _DownloadState.downloading;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.system_update_alt_rounded, color: scheme.onPrimaryContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'v${update.version} çıktı',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.w600, color: scheme.onPrimaryContainer),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isDownloading ? 'İndiriliyor…' : 'Yeni sürüm indirilebilir',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: scheme.onPrimaryContainer),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_state == _DownloadState.error && _errorMessage != null) ...[
            const SizedBox(height: 10),
            Text(
              _errorMessage!,
              style: TextStyle(fontSize: 12, color: scheme.onPrimaryContainer),
            ),
          ],
          const SizedBox(height: 14),
          if (isDownloading)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _progress > 0 ? _progress : null,
                minHeight: 8,
                backgroundColor: scheme.onPrimaryContainer.withValues(alpha: 0.15),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => _startUpdate(update),
                child: Text(_state == _DownloadState.error ? 'Tekrar Dene' : 'Güncelle'),
              ),
            ),
        ],
      ),
    );
  }
}
