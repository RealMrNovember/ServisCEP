import 'package:flutter/widgets.dart';

import 'dis_baglanti.dart';

/// "Haritada Aç" — bkz. docs/05 § Harita.
abstract final class MapLauncher {
  /// Harita uygulaması açılamazsa kullanıcı bunu öğrenir ve adres
  /// panoya kopyalanır; eskiden düğme sessizce hiçbir şey yapmıyordu.
  static Future<void> openAddress(
    BuildContext context,
    String address,
  ) async {
    final uri = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': address,
    });
    await context.disBaglantiAc(
      uri,
      hataMesaji: 'Harita açılamadı. Adres panoya kopyalandı.',
    );
  }
}
