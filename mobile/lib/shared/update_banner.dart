import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/services/update_checker.dart';

/// Yeni sürüm bulunduğunda gösterilen bildirim şeridi — bkz. docs/06 §
/// Mobil Uygulama Otomatik Güncelleme.
class UpdateBanner extends ConsumerWidget {
  const UpdateBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final updateAsync = ref.watch(updateInfoProvider);
    final update = updateAsync.valueOrNull;
    if (update == null) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;

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
                      'Yeni sürüm indirilebilir',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: scheme.onPrimaryContainer),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () =>
                  launchUrl(Uri.parse(update.downloadUrl), mode: LaunchMode.externalApplication),
              child: const Text('Güncelle'),
            ),
          ),
        ],
      ),
    );
  }
}
