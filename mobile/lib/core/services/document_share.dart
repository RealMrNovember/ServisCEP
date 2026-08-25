import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/theme.dart';

/// Üretilmiş bir PDF'i müşteriye ulaştırma seçenekleri.
///
/// Kasıtlı olarak "WhatsApp'a gönder" diye ayrı bir düğme yok: Android'de
/// bir dosyayı belirli bir uygulamaya doğrudan yollamanın desteklenen bir
/// yolu yok; sistem paylaşım menüsü zaten WhatsApp ve e-posta
/// uygulamalarını dosya ekli olarak listeliyor. Sahte bir "WhatsApp"
/// düğmesi koyup arkasında yine aynı menüyü açmak kullanıcıyı yanıltırdı.
///
/// "Telefona indir", yazdırma diyalogundaki "PDF olarak kaydet" seçeneğine
/// bağlanır — Android'de bir uygulamanın İndirilenler klasörüne doğrudan
/// yazmadan dosyayı kullanıcının erişebileceği bir yere bırakmasının
/// standart yolu budur.
Future<void> showDocumentShareSheet(
  BuildContext context, {
  required File file,
  required String title,
  required String shareText,
}) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              0,
              AppSpacing.xl,
              AppSpacing.sm,
            ),
            child: Text(
              title,
              style: Theme.of(sheetContext).textTheme.titleLarge,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.send_outlined),
            title: const Text('Gönder'),
            subtitle: const Text('WhatsApp, e-posta ve diğer uygulamalar'),
            onTap: () async {
              Navigator.pop(sheetContext);
              await SharePlus.instance.share(
                ShareParams(files: [XFile(file.path)], text: shareText),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: const Text('Telefona indir'),
            subtitle: const Text('Yazdırma ekranında "PDF olarak kaydet"'),
            onTap: () async {
              Navigator.pop(sheetContext);
              final bytes = await file.readAsBytes();
              await Printing.layoutPdf(
                onLayout: (_) async => bytes,
                name: title,
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.visibility_outlined),
            title: const Text('Önizle'),
            subtitle: const Text('Göndermeden önce belgeyi kontrol et'),
            onTap: () async {
              Navigator.pop(sheetContext);
              await OpenFilex.open(file.path);
            },
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    ),
  );
}
