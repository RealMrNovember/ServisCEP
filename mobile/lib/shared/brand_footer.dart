import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Standart marka/geliştirici atfı — uygulama genelinde footer alanlarında
/// (Dashboard, Daha Fazla/Hakkında ekranı vb.) kullanılır.
///
/// Bu, Claude/Anthropic atfı DEĞİLDİR — TeknikCEP'i geliştiren şirketin
/// kendi atfıdır, kullanıcı talebiyle eklenmiştir.
class BrandFooter extends StatelessWidget {
  const BrandFooter({super.key});

  static final Uri _cicibyteUri = Uri.https('cicibyte.com');

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => launchUrl(_cicibyteUri, mode: LaunchMode.externalApplication),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text.rich(
              TextSpan(
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                children: [
                  const TextSpan(text: 'TeknikCEP · '),
                  TextSpan(
                    text: 'Cicibyte Teknoloji',
                    style: TextStyle(
                      color: scheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const TextSpan(text: ' tarafından geliştirilmiştir'),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
