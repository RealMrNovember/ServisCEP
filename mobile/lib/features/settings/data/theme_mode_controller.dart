import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';

/// Kullanıcının seçtiği tema kipi.
///
/// Varsayılan [ThemeMode.system]: uygulama açıldığında telefonun kendi
/// ayarına uyar. Kullanıcı isterse açık ya da koyuya sabitleyebilir —
/// saha kullanıcısının telefonu gün boyu güneş altında ve bazıları koyu
/// temayı okunmaz buluyor.
///
/// Depolama olarak güvenli depo kullanılıyor. Tercih gizli bir veri
/// değil; uygulamada zaten başka bir anahtar–değer deposu yok ve bunun
/// için ayrı bir şema göçü açmak tercihin ağırlığına göre fazla olurdu.
/// Depo bozulup sıfırlanırsa en kötü ihtimalle sistem ayarına dönülür.
class ThemeModeController extends StateNotifier<ThemeMode> {
  ThemeModeController(this._ref) : super(ThemeMode.system) {
    _oku();
  }

  final Ref _ref;

  static const _anahtar = 'tema_kipi';

  Future<void> _oku() async {
    final deger = await _ref.read(secureStorageProvider).read(key: _anahtar);
    if (!mounted) return;
    state = _coz(deger);
  }

  Future<void> ayarla(ThemeMode kip) async {
    state = kip;
    await _ref
        .read(secureStorageProvider)
        .write(key: _anahtar, value: kip.name);
  }

  static ThemeMode _coz(String? deger) => switch (deger) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
}

final themeModeControllerProvider =
    StateNotifierProvider<ThemeModeController, ThemeMode>(
      ThemeModeController.new,
    );

/// Ayarlar satırında gösterilen etiket.
String themeModeLabel(ThemeMode kip) => switch (kip) {
  ThemeMode.light => 'Açık',
  ThemeMode.dark => 'Koyu',
  ThemeMode.system => 'Sistem ayarına uy',
};
