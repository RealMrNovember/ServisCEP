import 'package:flutter/material.dart';

/// TeknikCEP tasarım sistemi renk kümesi — 45 token.
///
/// Kaynak: docs/19-tasarim-sistemi.md § 2 (v2.0, 25 Ağustos 2026).
///
/// Koyu tema açık temanın renk çevrimi DEĞİLDİR; iki değer de elle
/// seçilmiştir. Koyu temada gölge yerine kenarlık + yüzey merdiveni
/// kullanılır, açık temada gölge kullanılır.
///
/// İki aksan tokeni bilinçlidir: marka rengi 0xFF3B82F6 beyaz yazı altında
/// 3.68:1 verir ve WCAG AA eşiğini (4.5:1) geçmez. Bu yüzden beyaz yazı
/// taşıyan dolgular [accentSolid] kullanır; [accent] yalnızca ikon,
/// kenarlık ve seçili çubuk gibi 3:1 eşiğine tabi öğeler içindir.
///
/// Aynı ayrım durum renklerinde de geçerlidir: [success], [warning] ve
/// [danger] DOLGU renkleridir; zemin üstüne yazılan metin daima
/// [successText] / [warningText] / [dangerText] kullanır, dolgunun
/// ÜSTÜNE yazılan metin ise [onSuccess] / [onWarning] / [onDanger].
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
    required this.onSuccess,
    required this.warning,
    required this.warningText,
    required this.warningSoft,
    required this.warningLine,
    required this.onWarning,
    required this.danger,
    required this.dangerText,
    required this.dangerSoft,
    required this.dangerLine,
    required this.onDanger,
    required this.neutralSoft,
    required this.navBg,
    required this.scrim,
    required this.skeleton,
    required this.skeletonSheen,
    required this.pressOverlay,
    required this.disabledBg,
    required this.disabledText,
    required this.disabledBorder,
    required this.shadowCard,
    required this.shadowRaise,
    required this.shadowSheet,
    required this.shadowDialog,
  });

  // --- Yüzeyler ---

  /// Ekran zemini (Scaffold).
  final Color bg;

  /// Gömük bölge — liste altı, ayırıcı alan.
  final Color bgSunken;

  /// Kart, alt sayfa, diyalog yüzeyi.
  final Color surface;

  /// Form alanı, gömük kart.
  final Color surfaceAlt;

  /// İlerleme oluğu, pasif anahtar.
  final Color surfaceHi;

  /// Kart ve ayırıcı çizgi.
  final Color border;

  /// İkincil buton, alt sayfa üstü.
  final Color borderStrong;

  // --- Metin ---

  /// Başlık ve gövde.
  final Color text;

  /// Alt açıklama, etiket.
  final Color textMuted;

  /// Placeholder, meta.
  final Color textFaint;

  // --- Aksan ---

  /// Marka rengi. İkon, kenarlık, seçili çizgi. Beyaz yazı TAŞIMAZ.
  final Color accent;

  /// Beyaz yazı taşıyan dolgular: buton, FAB, seçili çip, anahtar.
  final Color accentSolid;

  /// Zemin üstünde aksan renkli yazı.
  final Color accentText;

  /// Vurgu kart zemini.
  final Color accentSoft;

  /// Vurgu kart çerçevesi.
  final Color accentLine;

  /// Odak halkası, FAB gölgesi.
  final Color accentGlow;

  /// Birincil buton yazısı.
  final Color onAccent;

  // --- Durum: başarı ---

  /// Tamamlandı dolgusu (nokta, çubuk, ikon).
  final Color success;

  /// Normal zemin üstünde başarı yazısı.
  final Color successText;

  /// Başarı rozeti zemini.
  final Color successSoft;

  /// Başarı kenarlığı.
  final Color successLine;

  /// Yeşil DOLGU üstüne yazılan metin.
  final Color onSuccess;

  // --- Durum: uyarı ---

  /// Bekleyen / çevrimdışı dolgusu.
  final Color warning;

  /// Normal zemin üstünde uyarı yazısı.
  final Color warningText;

  /// Uyarı rozeti zemini.
  final Color warningSoft;

  /// Uyarı kenarlığı.
  final Color warningLine;

  /// Sarı DOLGU üstüne yazılan metin.
  final Color onWarning;

  // --- Durum: tehlike ---

  /// Acil, borç, silme dolgusu.
  final Color danger;

  /// Normal zemin üstünde tehlike yazısı.
  final Color dangerText;

  /// Tehlike rozeti zemini.
  final Color dangerSoft;

  /// Tehlike kenarlığı.
  final Color dangerLine;

  /// Kırmızı DOLGU üstüne yazılan metin.
  final Color onDanger;

  // --- Diğer ---

  /// Nötr rozet zemini.
  final Color neutralSoft;

  /// Alt gezinme çubuğu zemini.
  final Color navBg;

  /// Alt sayfa ve diyalog arkasındaki perde.
  final Color scrim;

  /// Yükleniyor iskeleti.
  final Color skeleton;

  /// İskelet üzerinde gezinen parıltı.
  final Color skeletonSheen;

  /// Basılı durum katmanı — dokunulan öğenin üstüne biner.
  final Color pressOverlay;

  /// Devre dışı öğe zemini.
  final Color disabledBg;

  /// Devre dışı öğe yazısı.
  final Color disabledText;

  /// Devre dışı öğe kenarlığı.
  final Color disabledBorder;

  // --- Gölgeler ---
  //
  // Renk değil, gölge listesi. Koyu temada kart gölgesi YOKTUR: yüzey
  // merdiveni ve kenarlık aynı işi yapar, gölge koyu zeminde kirli görünür.

  /// Kart gölgesi. Koyu temada boş liste.
  final List<BoxShadow> shadowCard;

  /// Alt eylem çubuğu gölgesi (yukarı doğru).
  final List<BoxShadow> shadowRaise;

  /// Alt sayfa gölgesi.
  final List<BoxShadow> shadowSheet;

  /// Diyalog gölgesi.
  final List<BoxShadow> shadowDialog;

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
    onSuccess: Color(0xFF052E16),
    warning: Color(0xFFFBBF24),
    warningText: Color(0xFFFBD268),
    warningSoft: Color(0x29FBBF24),
    warningLine: Color(0x5CFBBF24),
    onWarning: Color(0xFF3A2A03),
    danger: Color(0xFFF87171),
    dangerText: Color(0xFFFCA5A5),
    dangerSoft: Color(0x29F87171),
    dangerLine: Color(0x5CF87171),
    onDanger: Color(0xFF3A0A0A),
    neutralSoft: Color(0x2498A2B0),
    navBg: Color(0xFF0E1014),
    scrim: Color(0xA8000000),
    skeleton: Color(0xFF1F232B),
    skeletonSheen: Color(0xFF2C313C),
    pressOverlay: Color(0x1AFFFFFF),
    disabledBg: Color(0xFF181B21),
    disabledText: Color(0xFF5A6371),
    disabledBorder: Color(0xFF262A33),
    shadowCard: <BoxShadow>[],
    shadowRaise: <BoxShadow>[
      BoxShadow(
        color: Color(0x8C000000),
        offset: Offset(0, -8),
        blurRadius: 24,
      ),
    ],
    shadowSheet: <BoxShadow>[
      BoxShadow(
        color: Color(0x99000000),
        offset: Offset(0, -16),
        blurRadius: 40,
      ),
    ],
    shadowDialog: <BoxShadow>[
      BoxShadow(
        color: Color(0xA8000000),
        offset: Offset(0, 24),
        blurRadius: 60,
      ),
    ],
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
    onSuccess: Color(0xFFFFFFFF),
    warning: Color(0xFF9A5B06),
    warningText: Color(0xFF7C4805),
    warningSoft: Color(0xFFFCEFDA),
    warningLine: Color(0xFFE8C089),
    onWarning: Color(0xFFFFFFFF),
    danger: Color(0xFFB3231E),
    dangerText: Color(0xFF8F1B17),
    dangerSoft: Color(0xFFFBE7E6),
    dangerLine: Color(0xFFEFAFAC),
    onDanger: Color(0xFFFFFFFF),
    neutralSoft: Color(0xFFE7ECF2),
    navBg: Color(0xFFFFFFFF),
    scrim: Color(0x7A0C1016),
    skeleton: Color(0xFFE7ECF2),
    skeletonSheen: Color(0xFFF6F8FA),
    pressOverlay: Color(0x140C1016),
    disabledBg: Color(0xFFEDF0F4),
    disabledText: Color(0xFF98A2AF),
    disabledBorder: Color(0xFFDFE4EA),
    shadowCard: <BoxShadow>[
      BoxShadow(color: Color(0x0F0C1016), offset: Offset(0, 1), blurRadius: 2),
      BoxShadow(color: Color(0x0F0C1016), offset: Offset(0, 6), blurRadius: 16),
    ],
    shadowRaise: <BoxShadow>[
      BoxShadow(
        color: Color(0x1A0C1016),
        offset: Offset(0, -6),
        blurRadius: 20,
      ),
    ],
    shadowSheet: <BoxShadow>[
      BoxShadow(
        color: Color(0x290C1016),
        offset: Offset(0, -16),
        blurRadius: 40,
      ),
    ],
    shadowDialog: <BoxShadow>[
      BoxShadow(
        color: Color(0x380C1016),
        offset: Offset(0, 24),
        blurRadius: 60,
      ),
    ],
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
      onError: onDanger,
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
    Color? onSuccess,
    Color? warning,
    Color? warningText,
    Color? warningSoft,
    Color? warningLine,
    Color? onWarning,
    Color? danger,
    Color? dangerText,
    Color? dangerSoft,
    Color? dangerLine,
    Color? onDanger,
    Color? neutralSoft,
    Color? navBg,
    Color? scrim,
    Color? skeleton,
    Color? skeletonSheen,
    Color? pressOverlay,
    Color? disabledBg,
    Color? disabledText,
    Color? disabledBorder,
    List<BoxShadow>? shadowCard,
    List<BoxShadow>? shadowRaise,
    List<BoxShadow>? shadowSheet,
    List<BoxShadow>? shadowDialog,
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
      onSuccess: onSuccess ?? this.onSuccess,
      warning: warning ?? this.warning,
      warningText: warningText ?? this.warningText,
      warningSoft: warningSoft ?? this.warningSoft,
      warningLine: warningLine ?? this.warningLine,
      onWarning: onWarning ?? this.onWarning,
      danger: danger ?? this.danger,
      dangerText: dangerText ?? this.dangerText,
      dangerSoft: dangerSoft ?? this.dangerSoft,
      dangerLine: dangerLine ?? this.dangerLine,
      onDanger: onDanger ?? this.onDanger,
      neutralSoft: neutralSoft ?? this.neutralSoft,
      navBg: navBg ?? this.navBg,
      scrim: scrim ?? this.scrim,
      skeleton: skeleton ?? this.skeleton,
      skeletonSheen: skeletonSheen ?? this.skeletonSheen,
      pressOverlay: pressOverlay ?? this.pressOverlay,
      disabledBg: disabledBg ?? this.disabledBg,
      disabledText: disabledText ?? this.disabledText,
      disabledBorder: disabledBorder ?? this.disabledBorder,
      shadowCard: shadowCard ?? this.shadowCard,
      shadowRaise: shadowRaise ?? this.shadowRaise,
      shadowSheet: shadowSheet ?? this.shadowSheet,
      shadowDialog: shadowDialog ?? this.shadowDialog,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;

    Color mix(Color a, Color b) => Color.lerp(a, b, t) ?? a;
    List<BoxShadow> mixShadow(List<BoxShadow> a, List<BoxShadow> b) =>
        BoxShadow.lerpList(a, b, t) ?? a;

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
      onSuccess: mix(onSuccess, other.onSuccess),
      warning: mix(warning, other.warning),
      warningText: mix(warningText, other.warningText),
      warningSoft: mix(warningSoft, other.warningSoft),
      warningLine: mix(warningLine, other.warningLine),
      onWarning: mix(onWarning, other.onWarning),
      danger: mix(danger, other.danger),
      dangerText: mix(dangerText, other.dangerText),
      dangerSoft: mix(dangerSoft, other.dangerSoft),
      dangerLine: mix(dangerLine, other.dangerLine),
      onDanger: mix(onDanger, other.onDanger),
      neutralSoft: mix(neutralSoft, other.neutralSoft),
      navBg: mix(navBg, other.navBg),
      scrim: mix(scrim, other.scrim),
      skeleton: mix(skeleton, other.skeleton),
      skeletonSheen: mix(skeletonSheen, other.skeletonSheen),
      pressOverlay: mix(pressOverlay, other.pressOverlay),
      disabledBg: mix(disabledBg, other.disabledBg),
      disabledText: mix(disabledText, other.disabledText),
      disabledBorder: mix(disabledBorder, other.disabledBorder),
      shadowCard: mixShadow(shadowCard, other.shadowCard),
      shadowRaise: mixShadow(shadowRaise, other.shadowRaise),
      shadowSheet: mixShadow(shadowSheet, other.shadowSheet),
      shadowDialog: mixShadow(shadowDialog, other.shadowDialog),
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
