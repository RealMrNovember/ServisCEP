import 'package:flutter/material.dart';

/// TeknikCEP tipografi ölçeği.
///
/// Kaynak: TeknikCEP-Tasarim-Sistemi.md § 3 (25 Ağustos 2026).
///
/// Aileler: Archivo (başlık), Barlow (arayüz), JetBrains Mono (tutar/kod).
/// Üçü de gömülüdür; çalışma anında indirilmez.
///
/// Gövde metni 16sp'nin altına inmez — kullanıcı kitlesi 45-55 yaş ve
/// ekrana güneş altında bakıyor. Tasarım sistemi 14sp gövde kullanmaz;
/// 14sp yalnızca etiket ve alt açıklama içindir.
abstract final class AppTypography {
  static const displayFamily = 'Archivo';
  static const uiFamily = 'Barlow';
  static const monoFamily = 'JetBrainsMono';

  /// JetBrains Mono'da ₺ (U+20BA) glifi bulunmuyor. Tutarlar bu ailede
  /// yazıldığı için para işareti yedek aileden alınır; aksi hâlde her
  /// tutarda kutucuk görünür. Roboto zaten PDF için gömülü.
  static const monoFallback = ['Roboto'];

  /// Karşılama başlığı.
  static const display = TextStyle(
    fontFamily: displayFamily,
    fontWeight: FontWeight.w700,
    fontSize: 32,
    height: 38 / 32,
    letterSpacing: -0.6,
  );

  /// Ekran başlığı.
  static const h1 = TextStyle(
    fontFamily: displayFamily,
    fontWeight: FontWeight.w700,
    fontSize: 24,
    height: 30 / 24,
    letterSpacing: -0.3,
  );

  /// Bölüm başlığı.
  static const h2 = TextStyle(
    fontFamily: displayFamily,
    fontWeight: FontWeight.w600,
    fontSize: 19,
    height: 26 / 19,
    letterSpacing: -0.2,
  );

  /// Kart ve liste satırı başlığı.
  static const h3 = TextStyle(
    fontFamily: uiFamily,
    fontWeight: FontWeight.w600,
    fontSize: 17,
    height: 24 / 17,
  );

  /// Okunan metin — tasarım sisteminin en küçük gövde puntosu.
  static const body = TextStyle(
    fontFamily: uiFamily,
    fontWeight: FontWeight.w400,
    fontSize: 16,
    height: 24 / 16,
  );

  /// Vurgulu gövde, değer.
  ///
  /// Tasarım sistemindeki adı `bodyS`; burada `bodyStrong` denmesinin
  /// sebebi, Dart tarafında `bodyS` okuyan birinin bunu "body small"
  /// sanmasıdır — oysa punto aynı, değişen yalnızca ağırlık.
  static const bodyStrong = TextStyle(
    fontFamily: uiFamily,
    fontWeight: FontWeight.w600,
    fontSize: 16,
    height: 24 / 16,
  );

  /// Form etiketi, çip.
  static const label = TextStyle(
    fontFamily: uiFamily,
    fontWeight: FontWeight.w600,
    fontSize: 14,
    height: 20 / 14,
  );

  /// Bölüm üst etiketi (büyük harf yazılır).
  ///
  /// DİKKAT: Bu stildeki metni Dart'ın [String.toUpperCase] metoduyla
  /// dönüştürme — varsayılan yerelde 'i' harfini 'I' yapar ve
  /// "BUGÜNÜN ÖZETI" gibi hatalı çıktı verir. Metni baştan büyük harfle
  /// yaz ya da Türkçe yerel veren bir yardımcı kullan.
  static const labelUp = TextStyle(
    fontFamily: uiFamily,
    fontWeight: FontWeight.w700,
    fontSize: 12,
    height: 16 / 12,
    letterSpacing: 0.8,
  );

  /// Alt açıklama, liste alt satırı.
  static const caption = TextStyle(
    fontFamily: uiFamily,
    fontWeight: FontWeight.w500,
    fontSize: 14,
    height: 19 / 14,
  );

  /// Rozet metni.
  static const badge = TextStyle(
    fontFamily: uiFamily,
    fontWeight: FontWeight.w700,
    fontSize: 13,
    height: 18 / 13,
  );

  /// Alt gezinme etiketi.
  ///
  /// Simge tek başına kullanılmadığı için bu etiket daima görünür;
  /// kullanıcı kitlesi simge tahmin etmiyor, yazı okuyor.
  static const navLabel = TextStyle(
    fontFamily: uiFamily,
    fontWeight: FontWeight.w600,
    fontSize: 13,
    height: 15 / 13,
  );

  /// Küçük kod, barkod.
  static const monoSmall = TextStyle(
    fontFamily: monoFamily,
    fontFamilyFallback: monoFallback,
    fontWeight: FontWeight.w500,
    fontSize: 14,
    height: 19 / 14,
    letterSpacing: 0.2,
  );

  /// Para ve belge numarası — rakam hizası tabular.
  static const mono = TextStyle(
    fontFamily: monoFamily,
    fontFamilyFallback: monoFallback,
    fontWeight: FontWeight.w600,
    fontSize: 18,
    height: 24 / 18,
  );

  /// Özet rakamı (ana sayfadaki büyük sayı gibi).
  static const monoLarge = TextStyle(
    fontFamily: monoFamily,
    fontFamilyFallback: monoFallback,
    fontWeight: FontWeight.w700,
    fontSize: 28,
    height: 34 / 28,
    letterSpacing: -0.5,
  );

  /// Material'in [TextTheme] yapısına eşlenmiş hâli.
  ///
  /// Bu eşleme AİLE, AĞIRLIK ve HARF ARALIĞINI tasarıma çeker; PUNTOLARI
  /// bilinçli olarak mevcut değerlerinde bırakır. Sebep: ekran tasarımları
  /// (artboard) henüz teslim edilmedi, 34 ekranın punto ölçeğini görmeden
  /// büyütmek taşma riski taşıyor. Ekranlar geldikçe her ekran kendi
  /// stillerini yukarıdaki sabitlerden alacak.
  static TextTheme toTextTheme(ColorScheme scheme) {
    final base = ThemeData(brightness: scheme.brightness).textTheme;

    // Yalnızca aile, ağırlık ve harf aralığı taşınır; punto ve renk
    // mevcut değerlerinde kalır.
    TextStyle? as(TextStyle? from, TextStyle spec) => from?.copyWith(
      fontFamily: spec.fontFamily,
      fontFamilyFallback: spec.fontFamilyFallback,
      fontWeight: spec.fontWeight,
      letterSpacing: spec.letterSpacing,
    );

    // TextTheme'in 15 yuvasının tamamı burada eşleniyor; bu yüzden sona
    // bir .apply(fontFamily: ...) EKLENMEMELİ — o çağrı başlıkların
    // Archivo ailesini de ezerdi.
    return base.copyWith(
      displayLarge: as(base.displayLarge, display),
      displayMedium: as(base.displayMedium, display),
      displaySmall: as(base.displaySmall, display),
      headlineLarge: as(base.headlineLarge, h1),
      headlineMedium: as(base.headlineMedium, h1),
      headlineSmall: as(base.headlineSmall, h1),
      titleLarge: as(base.titleLarge, h2),
      titleMedium: as(base.titleMedium, h3),
      titleSmall: as(base.titleSmall, label),
      bodyLarge: as(base.bodyLarge, body)?.copyWith(height: 1.45),
      bodyMedium: as(base.bodyMedium, body)?.copyWith(height: 1.45),
      bodySmall: as(
        base.bodySmall,
        caption,
      )?.copyWith(height: 1.4, color: scheme.onSurfaceVariant),
      labelLarge: as(base.labelLarge, label),
      labelMedium: as(base.labelMedium, label),
      labelSmall: as(base.labelSmall, labelUp),
    );
  }
}
