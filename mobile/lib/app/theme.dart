import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'palette.dart';
import 'typography.dart';

/// TeknikCEP marka renkleri.
/// Kaynak: docs/14-marka-kimligi.md — bu dosyayla senkron tutulmalıdır.
///
/// NOT: Yeni tasarım sistemiyle birlikte renklerin tek kaynağı [AppPalette]
/// oldu. Buradaki sabitler, palete geçişi tamamlanmamış birkaç çağrı yeri
/// için duruyor; yeni kodda [AppPalette] kullanılmalıdır.
abstract final class AppColors {
  static const accent = Color(0xFF3B82F6);
  static const darkBg = Color(0xFF131316);
  static const bezel = Color(0xFF3F3F46);
  static const screen = Color(0xFFFAFAFA);

  /// Durum renkleri — Material şemasından türetilmeyen, anlamı sabit olanlar.
  static const success = Color(0xFF16A34A);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFDC2626);
}

/// Ölçü belirteçleri — ekranlar arası tutarlılık için tek kaynak.
///
/// Her ekranın kendi boşluk/köşe değerlerini uydurması, uygulamanın
/// "derli toplu" görünmemesinin en yaygın sebebidir; burada toplandı.
abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 28.0;

  /// Büyük bölüm arası — tasarım sistemi § 4.
  static const x3l = 36.0;

  /// Ekran alt payı — tasarım sistemi § 4.
  static const x4l = 48.0;

  /// Ekran kenar boşluğu — liste ve form ekranlarında aynı olmalı.
  static const screenPadding = EdgeInsets.symmetric(horizontal: 20);
}

abstract final class AppRadius {
  static const sm = 10.0;
  static const md = 14.0;
  static const lg = 18.0;
  static const xl = 24.0;

  static BorderRadius get card => BorderRadius.circular(lg);
  static BorderRadius get field => BorderRadius.circular(md);
  static BorderRadius get pill => BorderRadius.circular(999);
  static BorderRadius get dialog => BorderRadius.circular(xl);
}

/// Sabit ölçüler (dp) — tasarım sistemi § 4.
///
/// Bu değerler saha kullanımından türemiştir: eldivenli parmak için
/// dokunma hedefi 48dp'nin altına inmez, ana eylemler tek elle
/// erişilebilsin diye ekranın altında sabit yükseklikte durur.
abstract final class AppSize {
  /// Birincil buton yüksekliği.
  static const btnPrimary = 52.0;

  /// İkincil buton yüksekliği.
  static const btnSecondary = 50.0;

  /// Form alanı yüksekliği.
  static const field = 56.0;

  /// Liste satırı minimum yüksekliği.
  static const rowMin = 72.0;

  /// Dokunma hedefi minimumu — eldivenli parmak.
  static const touch = 48.0;

  /// Alt gezinme çubuğu (sistem payı hariç).
  static const nav = 68.0;

  /// Üst çubuk.
  static const appBar = 60.0;

  /// Uzatılmış FAB.
  static const fab = 56.0;

  /// Liste satırındaki ikon kutusu.
  static const iconBox = 46.0;

  /// Liste satırındaki avatar.
  static const avatar = 46.0;

  /// Adım göstergesindeki daire.
  static const stepDot = 32.0;

  /// Tasarımın çizildiği referans ekran genişliği.
  ///
  /// Ölçüler dp cinsindendir; bu değer yalnızca artboard'daki oranı
  /// koda taşırken kıyas için kullanılır, düzen buna sabitlenmez.
  static const refScreenWidth = 390.0;

  /// Tasarımın çizildiği referans ekran yüksekliği.
  static const refScreenHeight = 844.0;
}

/// Saha kullanımına uygun (büyük dokunma alanları, yüksek kontrast) ama
/// modern ve şık bir Material 3 tema. Bkz. docs/06 § Mobil Tasarım
/// Prensipleri.
abstract final class AppTheme {
  static ThemeData light() => _base(AppPalette.light);

  static ThemeData dark() => _base(AppPalette.dark);

  static ThemeData _base(AppPalette palette) {
    final scheme = palette.toColorScheme();
    final isDark = palette.isDark;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      // Ekran zemini yüzeyden bir kademe koyudur; kartlar zeminden ayrışsın
      // diye. Koyu temada bu merdiven gölgenin yerini tutar.
      scaffoldBackgroundColor: palette.bg,
      visualDensity: VisualDensity.comfortable,
      // Stil verilmeyen metinler de arayüz ailesine düşsün.
      fontFamily: AppTypography.uiFamily,
      textTheme: AppTypography.toTextTheme(scheme),
      splashFactory: InkSparkle.splashFactory,
      extensions: [palette],

      appBarTheme: AppBarTheme(
        backgroundColor: palette.bg,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        // Kaydırınca başlık çubuğunun altına ince bir ayrım çizgisi
        // düşsün diye gölge yerine renk kullanılıyor (gölge, açık temada
        // kirli görünüyordu).
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        titleTextStyle: AppTypography.h1.copyWith(
          fontSize: 20,
          color: palette.text,
        ),
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        color: palette.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.card,
          side: BorderSide(color: palette.border),
        ),
        margin: EdgeInsets.zero,
      ),

      dividerTheme: DividerThemeData(
        color: palette.border,
        thickness: 1,
        space: 1,
      ),

      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.xs,
        ),
        titleTextStyle: TextStyle(
          fontSize: 15.5,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
        subtitleTextStyle: TextStyle(
          fontSize: 12.5,
          color: scheme.onSurfaceVariant,
          height: 1.35,
        ),
        iconColor: scheme.onSurfaceVariant,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.field),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(AppSize.btnPrimary),
          backgroundColor: palette.accentSolid,
          foregroundColor: palette.onAccent,
          disabledBackgroundColor: palette.disabledBg,
          disabledForegroundColor: palette.disabledText,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.field),
          textStyle: const TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(AppSize.btnSecondary),
          backgroundColor: palette.surface,
          foregroundColor: palette.text,
          disabledForegroundColor: palette.disabledText,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.field),
          side: BorderSide(color: palette.borderStrong),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surfaceAlt,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadius.field,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.field,
          borderSide: BorderSide(color: palette.border),
        ),
        // Odaklanınca kenarlık markanın rengine döner — kullanıcının hangi
        // alanda olduğunu gri tonlarından ayırt etmesi zordu. Burada
        // accentSolid değil accent kullanılır: kenarlık beyaz yazı taşımaz,
        // 3:1 eşiğine tabidir.
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.field,
          borderSide: BorderSide(color: palette.accent, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.field,
          borderSide: BorderSide(color: palette.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.field,
          borderSide: BorderSide(color: palette.danger, width: 1.6),
        ),
        labelStyle: TextStyle(color: palette.textMuted),
        hintStyle: TextStyle(color: palette.textFaint),
        helperStyle: TextStyle(fontSize: 11.5, color: palette.textMuted),
        errorStyle: TextStyle(fontSize: 12.5, color: palette.dangerText),
      ),

      chipTheme: ChipThemeData(
        side: BorderSide(color: palette.border),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.pill),
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        showCheckmark: false,
        selectedColor: palette.accentSolid,
        backgroundColor: palette.surfaceAlt,
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: palette.accentSolid,
        foregroundColor: palette.onAccent,
        elevation: 3,
        highlightElevation: 6,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.card),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        titleTextStyle: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w700,
          color: palette.text,
        ),
        contentTextStyle: TextStyle(
          fontSize: 14.5,
          height: 1.45,
          color: palette.textMuted,
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        insetPadding: const EdgeInsets.all(AppSpacing.lg),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.field),
        // Her iki temada da koyu bir çip: beyaz yazı ikisinde de okunur.
        // (Önceden koyu temada inverseSurface kullanılıyordu; M3'te bu
        // AÇIK bir renk olduğu için beyaz yazı görünmez hâle geliyordu.)
        backgroundColor: isDark ? palette.surfaceHi : const Color(0xFF1F2430),
        contentTextStyle: const TextStyle(fontSize: 14, color: Colors.white),
        actionTextColor: AppPalette.dark.accentText,
      ),

      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: AppRadius.field),
          textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: palette.accent,
        linearTrackColor: palette.surfaceHi,
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: palette.navBg,
        indicatorColor: palette.accentSoft,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: AppSize.nav,
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
