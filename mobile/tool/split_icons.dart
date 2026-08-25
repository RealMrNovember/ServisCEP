// TeknikCEP ikon seti bölücüsü.
//
// Tasarımcı ikonları tek bir SVG "sprite" dosyasında teslim ediyor:
// her ikon bir <symbol id="tc-ad"> öğesi. flutter_svg sprite içindeki
// <use href="#id"> başvurularını çözemediği için her sembol ayrı bir SVG
// dosyasına çıkarılır.
//
// Çalıştırma (mobile/ dizininden):
//   dart run tool/split_icons.dart
//
// Girdi : assets/icons/teknikcep-icons.svg
// Çıktı : assets/icons/tc/<ad>.svg
//         lib/shared/tc_icon_names.dart  (elle düzenlenmez)
//
// Tasarımcı yeni bir sprite teslim ettiğinde bu betik yeniden çalıştırılır;
// çıktı dizini her seferinde sıfırlanır.

import 'dart:io';

const _kaynak = 'assets/icons/teknikcep-icons.svg';
const _hedefDizin = 'assets/icons/tc';

/// Sprite içindeki `<symbol ...>` ... `</symbol>` bloklarını yakalar.
final _sembolDeseni = RegExp(
  r'<symbol\s+([^>]*?)>(.*?)</symbol>',
  dotAll: true,
);

/// Sembol etiketindeki nitelikleri ayrıştırır.
final _nitelikDeseni = RegExp(r'([a-zA-Z-]+)="([^"]*)"');

int main() {
  final kaynak = File(_kaynak);
  if (!kaynak.existsSync()) {
    stderr.writeln('Kaynak bulunamadı: $_kaynak');
    return 1;
  }

  final icerik = kaynak.readAsStringSync();
  final eslesmeler = _sembolDeseni.allMatches(icerik).toList();

  if (eslesmeler.isEmpty) {
    stderr.writeln('Sprite içinde <symbol> bulunamadı.');
    return 1;
  }

  final hedef = Directory(_hedefDizin);
  if (hedef.existsSync()) {
    hedef.deleteSync(recursive: true);
  }
  hedef.createSync(recursive: true);

  final adlar = <String>[];

  for (final eslesme in eslesmeler) {
    final nitelikMetni = eslesme.group(1) ?? '';
    final govde = (eslesme.group(2) ?? '').trim();

    final nitelikler = <String, String>{};
    for (final n in _nitelikDeseni.allMatches(nitelikMetni)) {
      nitelikler[n.group(1)!] = n.group(2)!;
    }

    final kimlik = nitelikler.remove('id');
    if (kimlik == null) {
      stderr.writeln('id niteliği olmayan bir <symbol> atlandı.');
      continue;
    }

    // "tc-home" -> "home"
    final ad = kimlik.startsWith('tc-') ? kimlik.substring(3) : kimlik;
    adlar.add(ad);

    // viewBox yoksa tasarım ızgarası varsayılır.
    nitelikler.putIfAbsent('viewBox', () => '0 0 24 24');

    final nitelikDizisi = nitelikler.entries
        .map((e) => '${e.key}="${e.value}"')
        .join(' ');

    final svg = StringBuffer()
      ..writeln('<svg xmlns="http://www.w3.org/2000/svg" $nitelikDizisi>')
      ..writeln(govde)
      ..writeln('</svg>');

    File('$_hedefDizin/$ad.svg').writeAsStringSync(svg.toString());
  }

  adlar.sort();
  _adlariYaz(adlar);

  stdout.writeln('${adlar.length} ikon yazıldı -> $_hedefDizin');
  stdout.writeln('Adlar -> $_adDosyasi');
  return 0;
}

const _adDosyasi = 'lib/shared/tc_icon_names.dart';

/// İkon adlarını Dart sabitleri olarak yazar; çağrı yerlerinde yazım
/// hatası derleme zamanında yakalansın diye.
void _adlariYaz(List<String> adlar) {
  final tampon = StringBuffer()
    ..writeln('// BU DOSYA ÜRETİLMİŞTİR — elle düzenleme.')
    ..writeln('// Üreten: tool/split_icons.dart')
    ..writeln('// Kaynak: $_kaynak')
    ..writeln()
    ..writeln('/// Tasarım sistemi ikon setindeki adlar.')
    ..writeln('///')
    ..writeln('/// Kullanım: TcIcon(TcIcons.home)')
    ..writeln('abstract final class TcIcons {');

  for (final ad in adlar) {
    tampon.writeln("  static const $ad = '$ad';");
  }

  tampon
    ..writeln()
    ..writeln('  /// Sette bulunan tüm adlar.')
    ..writeln('  static const hepsi = <String>[');
  for (final ad in adlar) {
    tampon.writeln("    '$ad',");
  }
  tampon
    ..writeln('  ];')
    ..writeln('}');

  File(_adDosyasi).writeAsStringSync(tampon.toString());
}
