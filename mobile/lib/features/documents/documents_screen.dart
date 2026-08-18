import 'package:flutter/material.dart';

/// Belge Merkezi — bkz. docs/03 § Belge Merkezi.
///
/// NOT: PDF üretim motoru henüz bağlanmadı (bkz. ROADMAP.md — M10, sonraki
/// oturum). Bu ekran, teklif/proforma/servis formu/fatura gibi belgelerin
/// listeleneceği yeri şimdiden ayırır.
class DocumentsScreen extends StatelessWidget {
  const DocumentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Belgeler')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.folder_outlined, size: 56, color: scheme.onSurfaceVariant),
              const SizedBox(height: 16),
              Text(
                'Henüz belge yok',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                'Teklif, proforma, servis formu ve faturaların burada toplanacak.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
