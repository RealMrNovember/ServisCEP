import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serviscep/app/palette.dart';
import 'package:serviscep/app/theme.dart';
import 'package:serviscep/app/typography.dart';
import 'package:serviscep/shared/tc_icon_names.dart';

/// WCAG 2.1 kontrast oranı. [Color.computeLuminance] zaten WCAG'in
/// bağıl parlaklık tanımını uyguluyor.
double _kontrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final acik = la > lb ? la : lb;
  final koyu = la > lb ? lb : la;
  return (acik + 0.05) / (koyu + 0.05);
}

/// Yarı saydam rengi, arkasındaki zeminle birleştirir. Rozet zeminleri
/// alfa kanalı taşıdığı için kontrast bu birleşik renk üzerinden ölçülür.
Color _uzerine(Color ust, Color alt) => Color.alphaBlend(ust, alt);

void main() {
  group('Palet kontrastı', () {
    // Tasarım sisteminin § 2 tablosundaki iddialar. Bunlar bozulursa
    // uygulama güneş altında okunmaz hâle gelir; kaza eseri değişmesin.
    for (final (ad, palet) in <(String, AppPalette)>[
      ('koyu', AppPalette.dark),
      ('açık', AppPalette.light),
    ]) {
      test('$ad tema: gövde metni yüzey üstünde AA geçer', () {
        expect(_kontrast(palet.text, palet.surface), greaterThanOrEqualTo(4.5));
      });

      test('$ad tema: ikincil metin AA geçer', () {
        expect(
          _kontrast(palet.textMuted, palet.surface),
          greaterThanOrEqualTo(4.5),
        );
      });

      test('$ad tema: soluk metin AA geçer', () {
        expect(
          _kontrast(palet.textFaint, palet.surface),
          greaterThanOrEqualTo(4.5),
        );
      });

      test('$ad tema: birincil buton yazısı AA geçer', () {
        // Bu, iki aksan tokeninin var olma sebebi. Marka rengi 3B82F6
        // beyaz yazı altında 4.5:1'i geçmiyor; dolgular accentSolid
        // kullanmak zorunda.
        expect(
          _kontrast(palet.onAccent, palet.accentSolid),
          greaterThanOrEqualTo(4.5),
        );
      });

      test('$ad tema: aksan, arayüz öğesi olarak 3:1 geçer', () {
        expect(_kontrast(palet.accent, palet.bg), greaterThanOrEqualTo(3.0));
      });

      test('$ad tema: dolgu üstü yazılar AA geçer', () {
        // success/warning/danger DOLGU renkleridir. Üstlerine yazı
        // yazıldığında on* karşılığı kullanılır; bu tokenların var olma
        // sebebi de bu. Sarı dolgu üstünde beyaz yazı okunmaz.
        expect(_kontrast(palet.onSuccess, palet.success), greaterThanOrEqualTo(4.5));
        expect(_kontrast(palet.onWarning, palet.warning), greaterThanOrEqualTo(4.5));
        expect(_kontrast(palet.onDanger, palet.danger), greaterThanOrEqualTo(4.5));
      });

      test('$ad tema: gölge kullanımı temaya uygun', () {
        if (palet.isDark) {
          // Koyu temada kart gölgesi yoktur; yüzey merdiveni ve kenarlık
          // aynı işi yapar, gölge koyu zeminde kirli görünür.
          expect(palet.shadowCard, isEmpty);
        } else {
          expect(palet.shadowCard, isNotEmpty);
        }
        // Yükseltilmiş yüzeylerin gölgesi iki temada da vardır.
        expect(palet.shadowSheet, isNotEmpty);
        expect(palet.shadowDialog, isNotEmpty);
      });

      test('$ad tema: durum yazıları kendi rozet zemininde AA geçer', () {
        expect(
          _kontrast(palet.successText, _uzerine(palet.successSoft, palet.surface)),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          _kontrast(palet.warningText, _uzerine(palet.warningSoft, palet.surface)),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          _kontrast(palet.dangerText, _uzerine(palet.dangerSoft, palet.surface)),
          greaterThanOrEqualTo(4.5),
        );
      });
    }
  });

  group('Tema bağlantısı', () {
    test('renkler paletten geliyor, fromSeed türetmesinden değil', () {
      final koyu = AppTheme.dark();
      expect(koyu.colorScheme.surface, AppPalette.dark.surface);
      expect(koyu.colorScheme.primary, AppPalette.dark.accentSolid);
      expect(koyu.scaffoldBackgroundColor, AppPalette.dark.bg);

      final acik = AppTheme.light();
      expect(acik.colorScheme.surface, AppPalette.light.surface);
      expect(acik.scaffoldBackgroundColor, AppPalette.light.bg);
    });

    test('palet tema uzantısı olarak kayıtlı', () {
      expect(AppTheme.dark().extension<AppPalette>(), AppPalette.dark);
      expect(AppTheme.light().extension<AppPalette>(), AppPalette.light);
    });

    test('snackbar zemini her iki temada da koyu', () {
      // Eskiden koyu temada inverseSurface kullanılıyordu; M3'te bu AÇIK
      // bir renk olduğu için beyaz yazı görünmüyordu.
      for (final tema in [AppTheme.dark(), AppTheme.light()]) {
        final zemin = tema.snackBarTheme.backgroundColor;
        expect(zemin, isNotNull);
        expect(_kontrast(Colors.white, zemin!), greaterThanOrEqualTo(4.5));
      }
    });
  });

  group('Tipografi', () {
    test('başlıklar Archivo, gövde Barlow', () {
      final tema = AppTheme.dark().textTheme;
      expect(tema.headlineMedium?.fontFamily, AppTypography.displayFamily);
      expect(tema.titleLarge?.fontFamily, AppTypography.displayFamily);
      expect(tema.bodyMedium?.fontFamily, AppTypography.uiFamily);
      expect(tema.labelLarge?.fontFamily, AppTypography.uiFamily);
    });

    test('tutar stilinde yedek aile var', () {
      // JetBrains Mono'da ₺ (U+20BA) glifi yok. Yedek kaldırılırsa her
      // tutarda kutucuk çıkar.
      expect(AppTypography.mono.fontFamily, AppTypography.monoFamily);
      expect(AppTypography.mono.fontFamilyFallback, contains('Roboto'));
      expect(AppTypography.monoLarge.fontFamilyFallback, contains('Roboto'));
    });

    test('gövde metni 16sp altına inmiyor', () {
      expect(AppTypography.body.fontSize, greaterThanOrEqualTo(16));
      expect(AppTypography.bodyStrong.fontSize, greaterThanOrEqualTo(16));
    });

    test('tüm mono stilleri yedek aile taşıyor', () {
      for (final stil in [
        AppTypography.mono,
        AppTypography.monoSmall,
        AppTypography.monoLarge,
      ]) {
        expect(stil.fontFamilyFallback, contains('Roboto'));
      }
    });

    test('kullanılan her ağırlık pubspec içinde tanımlı', () {
      // Tanımsız bir ağırlık hata vermez; Flutter sessizce en yakın
      // ağırlığa düşer ve tasarım fark edilmeden bozulur.
      final pubspec = File('pubspec.yaml').readAsStringSync();

      final tanimli = <String, Set<int>>{};
      String? aile;
      for (final satir in pubspec.split('\n')) {
        final aileEslesme = RegExp(r'^\s*- family:\s*(\S+)').firstMatch(satir);
        if (aileEslesme != null) {
          aile = aileEslesme.group(1);
          tanimli[aile!] = <int>{};
          continue;
        }
        final agirlik = RegExp(r'^\s*weight:\s*(\d+)').firstMatch(satir);
        if (agirlik != null && aile != null) {
          tanimli[aile]!.add(int.parse(agirlik.group(1)!));
        }
      }

      const stiller = <String, TextStyle>{
        'display': AppTypography.display,
        'h1': AppTypography.h1,
        'h2': AppTypography.h2,
        'h3': AppTypography.h3,
        'body': AppTypography.body,
        'bodyStrong': AppTypography.bodyStrong,
        'label': AppTypography.label,
        'labelUp': AppTypography.labelUp,
        'caption': AppTypography.caption,
        'badge': AppTypography.badge,
        'navLabel': AppTypography.navLabel,
        'mono': AppTypography.mono,
        'monoSmall': AppTypography.monoSmall,
        'monoLarge': AppTypography.monoLarge,
      };

      for (final girdi in stiller.entries) {
        final stil = girdi.value;
        final agirlik = (stil.fontWeight?.value) ?? 400;
        expect(
          tanimli[stil.fontFamily],
          contains(agirlik),
          reason:
              '${girdi.key} stili ${stil.fontFamily} $agirlik istiyor ama '
              'pubspec içinde o ağırlık tanımlı değil',
        );
      }
    });
  });

  group('İkon seti', () {
    test('her ad için bir SVG dosyası var', () {
      final eksik = TcIcons.hepsi
          .where((ad) => !File('assets/icons/tc/$ad.svg').existsSync())
          .toList();
      expect(eksik, isEmpty, reason: 'SVG dosyası bulunamayan ikonlar');
    });

    test('dizindeki her SVG için bir ad sabiti var', () {
      final dizin = Directory('assets/icons/tc');
      final dosyalar = dizin
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.svg'))
          .map((f) => f.uri.pathSegments.last.replaceAll('.svg', ''))
          .toList();

      expect(dosyalar, isNotEmpty);
      for (final ad in dosyalar) {
        expect(
          TcIcons.hepsi,
          contains(ad),
          reason: 'tool/split_icons.dart yeniden çalıştırılmalı',
        );
      }
    });
  });

  group('Gömülü fontlar', () {
    test('pubspec içindeki font dosyaları diskte mevcut', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final yollar = RegExp(r'asset:\s*(assets/fonts/[^\s]+\.ttf)')
          .allMatches(pubspec)
          .map((m) => m.group(1)!)
          .toList();

      expect(yollar, isNotEmpty, reason: 'pubspec içinde font tanımı yok');
      for (final yol in yollar) {
        expect(File(yol).existsSync(), isTrue, reason: '$yol bulunamadı');
      }
    });
  });
}
