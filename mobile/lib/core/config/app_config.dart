/// Uygulama genelinde kullanılan derleme-zamanı ayarlar.
abstract final class AppConfig {
  /// `--dart-define=API_BASE_URL=...` ile staging/dev için değiştirilebilir.
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://serviscep.cicibyte.com/api/v1',
  );
}
