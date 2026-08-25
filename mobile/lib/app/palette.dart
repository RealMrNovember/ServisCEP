import 'package:flutter/material.dart';

/// TeknikCEP tasarım sistemi renk kümesi.
///
/// Kaynak: TeknikCEP-Tasarim-Sistemi.md § 2 (25 Ağustos 2026).
///
/// Koyu tema açık temanın renk çevrimi DEĞİLDİR; iki değer de elle
/// seçilmiştir. Koyu temada gölge yerine kenarlık + yüzey merdiveni
/// kullanılır, açık temada gölge kullanılır.
///
/// İki aksan tokeni bilinçlidir: marka rengi 0xFF3B82F6 beyaz yazı altında
/// 3.68:1 verir ve WCAG AA eşiğini (4.5:1) geçmez. Bu yüzden beyaz yazı
/// taşıyan dolgular [accentSolid] kullanır; [accent] yalnızca ikon,
/// kenarlık ve seçili çubuk gibi 3:1 eşiğine tabi öğeler içindir.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.bg,
    required this.bgSunken,
    required this.surface,
    required this.surfaceAlt,
    required this.surfaceHi,
    required this.border,
    required this.borderStrong,
    required this.text,
    required this.textMuted,
    required this.textFaint,
    required this.accent,
    required this.accentSolid,
    required this.accentText,
    required this.accentSoft,
    required this.accentLine,
    required this.accentGlow,
    required this.onAccent,
    required this.success,
    required this.successText,
    required this.successSoft,
    required this.successLine,
    required this.warning,
    required this.warningText,
    required this.warningSoft,
    required this.warningLine,
    required this.danger,
    required this.dangerText,
    required this.dangerSoft,
    required this.dangerLine,
    required this.neutralSoft,
    required this.navBg,
    required this.scrim,
    required this.skeleton,
  });

  /// Ekran zemini (Scaffold).
  final Color bg;

  /// Gömük zemin — liste altı, ayırıcı bölge.
  final Color bgSunken;

  /// Kart, alt sayfa, diyalog yüzeyi.
  final Color surface;

  /// Form alanı, gömük kart.
  final Color surfaceAlt;

  /// Progress oluğu, pasif switch.
  final Color surfaceHi;

  /// Kart ve ayırıcı çizgi.
  final Color border;

  /// İkincil buton, alt sayfa üstü.
  final Color borderStrong;

  /// Başlık ve gövde metni.
  final Color text;

  /// Alt açıklama, etiket.
  final Color textMuted;

  /// Placeholder, meta.
  final Color textFaint;

  /// İkon, kenarlık, seçili çubuk, imleç. Beyaz yazı TAŞIMAZ.
  final Color accent;

  /// Beyaz yazı taşıyan dolgular: buton, FAB, çip, switch.
  final Color accentSolid;

  /// Zemin üstünde aksan renkli yazı.
  final Color accentText;

  /// Vurgu kart zemini.
  final Color accentSoft;

  /// Vurgu kart çerçevesi.
  final Color accentLine;

  /// Odaklanmış form alanının halkası.
  final Color accentGlow;

  /// Birincil buton yazısı.
  final Color onAccent;

  /// Tamamlandı, tahsilat — DOLGU rengi (nokta, çubuk, ikon).
  final Color success;

  /// Zemin üstünde başarı yazısı.
  final Color successText;

  /// Başarı rozeti zemini.
  final Color successSoft;

  /// Başarı rozeti çerçevesi.
  final Color successLine;

  /// Bekleyen, çevrimdışı — DOLGU rengi.
  final Color warning;

  /// Zemin üstünde uyarı yazısı.
  final Color warningText;

  /// Uyarı rozeti zemini.
  final Color warningSoft;

  /// Uyarı rozeti çerçevesi.
  final Color warningLine;

  /// Acil, borç, silme — DOLGU rengi.
  final Color danger;

  /// Zemin üstünde tehlike yazısı.
  final Color dangerText;

  /// Tehlike rozeti zemini.
  final Color dangerSoft;

  /// Tehlike rozeti çerçevesi.
  final Color dangerLine;

  /// Nötr rozet zemini.
  final Color neutralSoft;

  /// Alt gezinme çubuğu zemini.
  final Color navBg;

  /// Alt sayfa ve diyalog arkasındaki perde.
  final Color scrim;

  /// Yükleniyor iskeleti.
  final Color skeleton;

  static const dark = AppPalette(
    bg: Color(0xFF0B0C0F),
    bgSunken: Color(0xFF07080A),
    surface: Color(0xFF14161B),
    surfaceAlt: Color(0xFF1B1E25),
    surfaceHi: Color(0xFF232732),
    border: Color(0xFF262A33),
    borderStrong: Color(0xFF39404D),
    text: Color(0xFFF4F6F9),
    textMuted: Color(0xFF98A2B0),
    textFaint: Color(0xFF7E8896),
    accent: Color(0xFF3B82F6),
    accentSolid: Color(0xFF2F72E4),
    accentText: Color(0xFF8FBCFC),
    accentSoft: Color(0x293B82F6),
    accentLine: Color(0x6B3B82F6),
    accentGlow: Color(0x473B82F6),
    onAccent: Color(0xFFFFFFFF),
    success: Color(0xFF22C55E),
    successText: Color(0xFF5BE08C),
    successSoft: Color(0x2922C55E),
    successLine: Color(0x5C22C55E),
    warning: Color(0xFFFBBF24),
    warningText: Color(0xFFFBD268),
    warningSoft: Color(0x29FBBF24),
    warningLine: Color(0x5CFBBF24),
    danger: Color(0xFFF87171),
    dangerText: Color(0xFFFCA5A5),
    dangerSoft: Color(0x29F87171),
    dangerLine: Color(0x5CF87171),
    neutralSoft: Color(0x2498A2B0),
    navBg: Color(0xFF0E1014),
    scrim: Color(0xA8000000),
    skeleton: Color(0xFF1F232B),
  );

  static const light = AppPalette(
    bg: Color(0xFFEEF1F5),
    bgSunken: Color(0xFFE3E8EE),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF3F6F9),
    surfaceHi: Color(0xFFE7ECF2),
    border: Color(0xFFD6DDE5),
    borderStrong: Color(0xFFAEB9C6),
    text: Color(0xFF0C1016),
    textMuted: Color(0xFF4A5563),
    textFaint: Color(0xFF68727F),
    accent: Color(0xFF1D5FD8),
    accentSolid: Color(0xFF1D5FD8),
    accentText: Color(0xFF174CB0),
    accentSoft: Color(0xFFE4EDFD),
    accentLine: Color(0xFF9CC0F7),
    accentGlow: Color(0x2E1D5FD8),
    onAccent: Color(0xFFFFFFFF),
    success: Color(0xFF12703A),
    successText: Color(0xFF0E5B2F),
    successSoft: Color(0xFFE1F4E8),
    successLine: Color(0xFF9BD4B1),
    warning: Color(0xFF9A5B06),
    warningText: Color(0xFF7C4805),
    warningSoft: Color(0xFFFCEFDA),
    warningLine: Color(0xFFE8C089),
    danger: Color(0xFFB3231E),
    dangerText: Color(0xFF8F1B17),
    dangerSoft: Color(0xFFFBE7E6),
    dangerLine: Color(0xFFEFAFAC),
    neutralSoft: Color(0xFFE7ECF2),
    navBg: Color(0xFFFFFFFF),
    scrim: Color(0x7A0C1016),
    skeleton: Color(0xFFE7ECF2),
  );

  bool get isDark => bg.computeLuminance() < 0.5;

  /// Paletten tam bir [ColorScheme] üretir.
  ///
  /// Uygulamada 90 yerde colorScheme üzerinden renk okunuyor; şema burada
  /// paletten beslendiği için ekranların tek tek dolaşılması gerekmiyor.
  ColorScheme toColorScheme() {
    return ColorScheme(
      brightness: isDark ? Brightness.dark : Brightness.light,

      // Birincil = beyaz yazı taşıyan dolgu rengi. Bilinçli olarak accent
      // değil accentSolid; bkz. sınıf açıklaması.
      primary: accentSolid,
      onPrimary: onAccent,
      primaryContainer: accentSoft,
      onPrimaryContainer: accentText,

      // İkincil, aksanın yazı taşımayan hâline eşlenir.
      secondary: accent,
      onSecondary: onAccent,
      secondaryContainer: accentSoft,
      onSecondaryContainer: accentText,

      tertiary: accent,
      onTertiary: onAccent,
      tertiaryContainer: accentSoft,
      onTertiaryContainer: accentText,

      error: danger,
      onError: onAccent,
      errorContainer: dangerSoft,
      onErrorContainer: dangerText,

      surface: surface,
      onSurface: text,
      onSurfaceVariant: textMuted,

      // Yüzey merdiveni — gömükten yükseltilmişe.
      surfaceContainerLowest: bgSunken,
      surfaceContainerLow: bg,
      surfaceContainer: surfaceAlt,
      surfaceContainerHigh: surface,
      surfaceContainerHighest: surfaceHi,
      surfaceDim: bgSunken,
      surfaceBright: surfaceHi,

      outline: borderStrong,
      outlineVariant: border,

      shadow: const Color(0xFF000000),
      scrim: scrim,

      // Ters yüzey yalnızca snackbar gibi zıt öğelerde kullanılır.
      inverseSurface: isDark ? light.surface : dark.surface,
      onInverseSurface: isDark ? light.text : dark.text,
      inversePrimary: isDark ? light.accent : dark.accent,

      // Yüzey tonlaması kapalı — tema her yerde surfaceTintColor'ı şeffafa
      // çekiyor, M3'ün otomatik tonlaması istenmiyor.
      surfaceTint: const Color(0x00000000),
    );
  }

  @override
  AppPalette copyWith({
    Color? bg,
    Color? bgSunken,
    Color? surface,
    Color? surfaceAlt,
    Color? surfaceHi,
    Color? border,
    Color? borderStrong,
    Color? text,
    Color? textMuted,
    Color? textFaint,
    Color? accent,
    Color? accentSolid,
    Color? accentText,
    Color? accentSoft,
    Color? accentLine,
    Color? accentGlow,
    Color? onAccent,
    Color? success,
    Color? successText,
    Color? successSoft,
    Color? successLine,
    Color? warning,
    Color? warningText,
    Color? warningSoft,
    Color? warningLine,
    Color? danger,
    Color? dangerText,
    Color? dangerSoft,
    Color? dangerLine,
    Color? neutralSoft,
    Color? navBg,
    Color? scrim,
    Color? skeleton,
  }) {
    return AppPalette(
      bg: bg ?? this.bg,
      bgSunken: bgSunken ?? this.bgSunken,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      surfaceHi: surfaceHi ?? this.surfaceHi,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      text: text ?? this.text,
      textMuted: textMuted ?? this.textMuted,
      textFaint: textFaint ?? this.textFaint,
      accent: accent ?? this.accent,
      accentSolid: accentSolid ?? this.accentSolid,
      accentText: accentText ?? this.accentText,
      accentSoft: accentSoft ?? this.accentSoft,
      accentLine: accentLine ?? this.accentLine,
      accentGlow: accentGlow ?? this.accentGlow,
      onAccent: onAccent ?? this.onAccent,
      success: success ?? this.success,
      successText: successText ?? this.successText,
      successSoft: successSoft ?? this.successSoft,
      successLine: successLine ?? this.successLine,
      warning: warning ?? this.warning,
      warningText: warningText ?? this.warningText,
      warningSoft: warningSoft ?? this.warningSoft,
      warningLine: warningLine ?? this.warningLine,
      danger: danger ?? this.danger,
      dangerText: dangerText ?? this.dangerText,
      dangerSoft: dangerSoft ?? this.dangerSoft,
      dangerLine: dangerLine ?? this.dangerLine,
      neutralSoft: neutralSoft ?? this.neutralSoft,
      navBg: navBg ?? this.navBg,
      scrim: scrim ?? this.scrim,
      skeleton: skeleton ?? this.skeleton,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;

    Color mix(Color a, Color b) => Color.lerp(a, b, t) ?? a;

    return AppPalette(
      bg: mix(bg, other.bg),
      bgSunken: mix(bgSunken, other.bgSunken),
      surface: mix(surface, other.surface),
      surfaceAlt: mix(surfaceAlt, other.surfaceAlt),
      surfaceHi: mix(surfaceHi, other.surfaceHi),
      border: mix(border, other.border),
      borderStrong: mix(borderStrong, other.borderStrong),
      text: mix(text, other.text),
      textMuted: mix(textMuted, other.textMuted),
      textFaint: mix(textFaint, other.textFaint),
      accent: mix(accent, other.accent),
      accentSolid: mix(accentSolid, other.accentSolid),
      accentText: mix(accentText, other.accentText),
      accentSoft: mix(accentSoft, other.accentSoft),
      accentLine: mix(accentLine, other.accentLine),
      accentGlow: mix(accentGlow, other.accentGlow),
      onAccent: mix(onAccent, other.onAccent),
      success: mix(success, other.success),
      successText: mix(successText, other.successText),
      successSoft: mix(successSoft, other.successSoft),
      successLine: mix(successLine, other.successLine),
      warning: mix(warning, other.warning),
      warningText: mix(warningText, other.warningText),
      warningSoft: mix(warningSoft, other.warningSoft),
      warningLine: mix(warningLine, other.warningLine),
      danger: mix(danger, other.danger),
      dangerText: mix(dangerText, other.dangerText),
      dangerSoft: mix(dangerSoft, other.dangerSoft),
      dangerLine: mix(dangerLine, other.dangerLine),
      neutralSoft: mix(neutralSoft, other.neutralSoft),
      navBg: mix(navBg, other.navBg),
      scrim: mix(scrim, other.scrim),
      skeleton: mix(skeleton, other.skeleton),
    );
  }
}

/// Palete kısa erişim: context.palette.accent
extension AppPaletteContext on BuildContext {
  /// Tema uzantısı tanımlı değilse parlaklığa göre varsayılan palete düşer;
  /// bu yüzden asla null döndürmez ve test ortamında da güvenlidir.
  AppPalette get palette {
    final theme = Theme.of(this);
    return theme.extension<AppPalette>() ??
        (theme.brightness == Brightness.dark
            ? AppPalette.dark
            : AppPalette.light);
  }
}
