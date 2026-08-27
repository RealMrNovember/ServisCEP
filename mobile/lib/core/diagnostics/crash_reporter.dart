import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../config/app_config.dart';
import '../network/client_headers.dart';

/// Yakalanmamış hataları toplar ve sunucuya gönderir.
///
/// NEDEN VAR: uygulamada hiçbir global hata yakalayıcı yoktu.
/// `FlutterError.onError` ve `PlatformDispatcher.onError` kurulu
/// olmadığı için bir ekran çizim sırasında patladığında hata yalnızca
/// cihazın konsoluna yazılıyor ve orada kalıyordu. Kullanıcı "açılmıyor"
/// diyor, elimizde tek satır kanıt olmuyordu.
///
/// Sunucu tarafı zaten hazırdı (`POST /api/v1/diagnostics`): kimlik
/// doğrulaması istemiyor, hız sınırlı ve çevrimdışı üretilmiş kayıtlar
/// için `occurred_at` alanı var. Eksik olan yalnızca gönderen taraftı.
///
/// KİMLİK DOĞRULAMASI YOK — bilinçli. Kimlik doğrulamanın kendisi
/// bozulduğunda hata bildirmek de imkânsız hale gelirdi; oysa en çok o
/// anda gerekiyor.
abstract final class CrashReporter {
  /// Bekleyen kayıtların tutulduğu dosya (satır başına bir JSON).
  ///
  /// Drift tablosu YERİNE dosya: yeni bir tablo yeni bir şema göçü
  /// demek ve bu sürümde zaten bir göç var (v9→v10). Hata bildirimi
  /// uğruna ikinci bir göç riski alınmıyor.
  static const _dosyaAdi = 'bekleyen_hatalar.jsonl';

  /// Diskte tutulan en fazla kayıt.
  ///
  /// Bir çizim hatası her karede tekrarlanabiliyor; sınır olmadan dosya
  /// dakikalar içinde şişerdi.
  static const _azamiKayit = 20;

  /// Aynı hatanın art arda tekrarını bastırma penceresi.
  static const _tekrarPenceresi = Duration(seconds: 30);

  static String? _sonImza;
  static DateTime? _sonZaman;
  static bool _kurulu = false;

  /// Global yakalayıcıları kurar. `main()` içinde, `runApp`'ten önce.
  static void install() {
    if (_kurulu) return;
    _kurulu = true;

    final oncekiFlutterHatasi = FlutterError.onError;
    FlutterError.onError = (details) {
      // Önceki davranış korunuyor: hata ayıklama derlemesinde konsola
      // basılması hâlâ en hızlı geri bildirim yolu.
      oncekiFlutterHatasi?.call(details);
      _kaydet(
        details.exceptionAsString(),
        details.stack?.toString(),
        details.library,
      );
    };

    // Flutter dışı (isolate/asenkron) hatalar buraya düşer; runZonedGuarded
    // gerekmiyor (Flutter 3.3+).
    PlatformDispatcher.instance.onError = (error, stack) {
      _kaydet(error.toString(), stack.toString(), null);
      // false döndürmek hatayı "işlenmedi" sayar ve varsayılan davranış
      // devam eder — bilinçli: bildirimi topladık diye çökme gizlenmemeli.
      return false;
    };
  }

  /// Diskte bekleyen kayıtları gönderir. Uygulama açılışında çağrılır.
  ///
  /// Hiçbir hata dışarı sızmaz: tanılama göndermek uygulamanın açılışını
  /// engelleyemez.
  static Future<void> flush() async {
    try {
      final dosya = await _dosya();
      if (!dosya.existsSync()) return;

      final satirlar = dosya
          .readAsLinesSync()
          .where((s) => s.trim().isNotEmpty)
          .toList();
      if (satirlar.isEmpty) return;

      // Dosya ÖNCE siliniyor: gönderim sırasında yeni bir hata oluşursa
      // onun kaydı silinmesin. Gönderilemeyen kayıtlar aşağıda geri yazılır.
      dosya.deleteSync();

      final dio = Dio(
        BaseOptions(
          baseUrl: AppConfig.apiBaseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 15),
          headers: {'Accept': 'application/json'},
        ),
      );
      final basliklar = await ClientHeaders.read();

      final gonderilemeyen = <String>[];
      for (final satir in satirlar) {
        try {
          final govde = jsonDecode(satir) as Map<String, dynamic>;
          await dio.post<void>(
            '/diagnostics',
            data: govde,
            options: Options(headers: basliklar),
          );
        } on Object {
          gonderilemeyen.add(satir);
        }
      }

      if (gonderilemeyen.isNotEmpty) {
        dosya.writeAsStringSync('${gonderilemeyen.join('\n')}\n');
      }
    } on Object catch (e) {
      debugPrint('Tanılama gönderimi düştü: $e');
    }
  }

  static Future<File> _dosya() async {
    final dizin = await getApplicationSupportDirectory();
    return File('${dizin.path}/$_dosyaAdi');
  }

  /// Hatayı diske yazar. SENKRON yazılır — çökmekte olan bir uygulamada
  /// asenkron bir yazma tamamlanmadan süreç ölebilir.
  static void _kaydet(String mesaj, String? yigin, String? kaynak) {
    try {
      final imza = '$mesaj|${yigin?.split('\n').take(3).join()}';
      final simdi = DateTime.now();
      final son = _sonZaman;
      if (_sonImza == imza &&
          son != null &&
          simdi.difference(son) < _tekrarPenceresi) {
        return;
      }
      _sonImza = imza;
      _sonZaman = simdi;

      final kayit = jsonEncode({
        'level': 'error',
        // Sunucu 250 karakterle sınırlıyor; burada da kesiliyor ki
        // dosyada gereksiz yer kaplamasın.
        'message': mesaj.length > 250 ? mesaj.substring(0, 250) : mesaj,
        if (yigin != null)
          'detail': yigin.length > 4000 ? yigin.substring(0, 4000) : yigin,
        'screen': ?kaynak,
        'platform': Platform.isAndroid ? 'android' : 'ios',
        // Cihaz çevrimdışıyken oluşan kayıtlar sonradan gönderiliyor;
        // sunucu saati o anı yansıtmaz.
        'occurred_at': simdi.toUtc().toIso8601String(),
      });

      // `getApplicationSupportDirectory` asenkron olduğu için yol
      // önbellekleniyor; ilk hata öncesinde `prepare()` çağrılmış olmalı.
      final yol = _onbellekYol;
      if (yol == null) return;

      final dosya = File(yol);
      final mevcut = dosya.existsSync() ? dosya.readAsLinesSync() : <String>[];
      final tumu = [...mevcut, kayit];
      final kirpilmis = tumu.length > _azamiKayit
          ? tumu.sublist(tumu.length - _azamiKayit)
          : tumu;
      dosya.writeAsStringSync('${kirpilmis.join('\n')}\n');
    } on Object {
      // Hata bildirirken hata vermek, bildirilecek hatayı da gizler.
    }
  }

  static String? _onbellekYol;

  /// Dosya yolunu önceden çözer.
  ///
  /// `_kaydet` senkron çalışmak zorunda (çökmekte olan uygulama), ama yol
  /// çözümü asenkron. Yol açılışta bir kez okunup saklanıyor.
  static Future<void> prepare() async {
    try {
      _onbellekYol = (await _dosya()).path;
    } on Object catch (e) {
      debugPrint('Tanılama dosyası hazırlanamadı: $e');
    }
  }
}
