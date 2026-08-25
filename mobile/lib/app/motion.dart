import 'package:flutter/animation.dart';

/// TeknikCEP hareket spesifikasyonu.
///
/// Kaynak: docs/19-tasarim-sistemi.md § 9 (v2.0).
///
/// Süreler kısa tutulmuştur: kullanıcı sahada, ayakta ve acelededir.
/// Bekletilen bir animasyon burada "şık" değil, engel sayılır.
abstract final class AppMotion {
  // --- Süreler ---

  /// Basma geri bildirimi.
  static const micro = Duration(milliseconds: 90);

  /// Rozet ve çip değişimi.
  static const fast = Duration(milliseconds: 140);

  /// Sekme çizgisi, şerit.
  static const base = Duration(milliseconds: 200);

  /// İskeletten içeriğe geçiş.
  static const slow = Duration(milliseconds: 280);

  /// Sayfa geçişi.
  static const page = Duration(milliseconds: 260);

  /// Alt sayfa açılışı.
  static const sheetIn = Duration(milliseconds: 320);

  /// Alt sayfa kapanışı — açılıştan hızlıdır; kapanış beklenmemeli.
  static const sheetOut = Duration(milliseconds: 240);

  /// Diyalog açılışı.
  static const dialog = Duration(milliseconds: 200);

  /// Snackbar giriş/çıkışı.
  static const toast = Duration(milliseconds: 220);

  /// İskelet parıltısının bir tur süresi.
  static const shimmer = Duration(milliseconds: 1400);

  /// Buton içi spinner'ın bir turu.
  static const spinner = Duration(milliseconds: 900);

  // --- Eğriler ---

  /// Genel amaçlı.
  static const standard = Cubic(0.2, 0, 0, 1);

  /// Giriş — yavaşlayarak yerleşir.
  static const decelerate = Cubic(0.05, 0.7, 0.1, 1);

  /// Çıkış — hızlanarak kaybolur.
  static const accelerate = Cubic(0.3, 0, 0.8, 0.15);

  /// Vurgulu geçiş.
  static const emphasized = Cubic(0.16, 1, 0.3, 1);

  /// Sonsuz döngüler (parıltı, spinner).
  static const linear = Curves.linear;
}
