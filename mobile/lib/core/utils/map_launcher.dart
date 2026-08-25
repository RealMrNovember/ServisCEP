import 'package:url_launcher/url_launcher.dart';

/// "Haritada Aç" — bkz. docs/05 § Harita.
abstract final class MapLauncher {
  static Future<void> openAddress(String address) async {
    final uri = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': address,
    });
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
