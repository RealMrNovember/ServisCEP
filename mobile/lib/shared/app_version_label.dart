import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Yüklü sürümü gösteren küçük, sessiz etiket — "hangi güncellemedeyim?"
/// sorusunun cevabı. Menünün en altında, dikkat çekmeden durur.
///
/// Sürüm derleme anında pubspec'ten gelir (elle güncellenen bir sabit
/// DEĞİLDİR) — böylece gösterilen değer her zaman gerçekten yüklü olan
/// sürümdür.
class AppVersionLabel extends StatelessWidget {
  const AppVersionLabel({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final info = snapshot.data;
        // Yüklenene kadar (veya okunamazsa) yer kaplamaz — layout zıplamaz.
        if (info == null) return const SizedBox(height: 16);

        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Center(
            child: Text(
              'Sürüm ${info.version} (${info.buildNumber})',
              style: TextStyle(
                fontSize: 11.5,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ),
        );
      },
    );
  }
}
