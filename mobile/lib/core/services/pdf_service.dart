import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../database/app_database.dart';
import '../utils/customer_display.dart';
import '../utils/money.dart';

/// PDF Motoru — bkz. docs/03 § PDF Motoru.
///
/// Belge düzeni, Türkiye'de kullanılan klasik "teklif formu" evrakını
/// izler — ortada belge başlığı, solda antet, "Sayın …" hitabı ve giriş
/// metni, numaralı malzeme tablosu, ödeme/teslim şartları ve altta
/// kaşe-imza kutuları. Amaç müşterinin alışkın olduğu evrakı vermek;
/// tipografi ve hizalama ise modern tutulur.
///
/// Tutarların hesabı burada YAPILMAZ — [LineAmounts] / [DocumentTotals]
/// kullanılır (bkz. core/utils/money.dart). Form ekranındaki canlı
/// önizleme ile PDF'in aynı sayıyı göstermesinin tek garantisi budur.
abstract final class PdfService {
  static final _shortDateFormat = DateFormat('dd.MM.yyyy');

  static const _accent = PdfColor.fromInt(0xFF1D4ED8);
  static const _accentSoft = PdfColor.fromInt(0xFFEFF4FF);
  static const _ink = PdfColor.fromInt(0xFF15181F);
  static const _muted = PdfColor.fromInt(0xFF5F6875);
  static const _line = PdfColor.fromInt(0xFFD8DEE7);
  static const _zebra = PdfColor.fromInt(0xFFF7F9FC);

  static pw.ThemeData? _cachedTheme;
  static pw.Font? _mediumFont;

  /// Gömülü Roboto ile tema. Yerleşik PDF fontları Türkçe ş/ğ/İ içermediği
  /// için belge onlarla bozuk çıkar (bkz. assets/fonts/LICENSE.txt).
  ///
  /// Asset okunamazsa (ör. binding'siz bir birim testi) belge üretimi
  /// tamamen çökmek yerine varsayılan fontla devam eder — bozuk karakter,
  /// hiç belge olmamasından iyidir.
  static Future<pw.ThemeData> _theme() async {
    final cached = _cachedTheme;
    if (cached != null) return cached;

    pw.ThemeData theme;
    try {
      Future<pw.Font> load(String name) async =>
          pw.Font.ttf(await rootBundle.load('assets/fonts/$name.ttf'));

      final regular = await load('Roboto-Regular');
      final medium = await load('Roboto-Medium');
      final bold = await load('Roboto-Bold');
      theme =
          pw.ThemeData.withFont(
            base: regular,
            bold: bold,
            italic: regular,
            boldItalic: bold,
          ).copyWith(
            defaultTextStyle: pw.TextStyle(font: regular, color: _ink),
          );
      _mediumFont = medium;
    } on Object {
      theme = pw.ThemeData.base();
    }

    _cachedTheme = theme;
    return theme;
  }

  /// Türkçe büyük harf.
  ///
  /// Dart'ın `toUpperCase()` metodu 'i' harfini 'I' yapar; belgede
  /// "TEKLIF" ve "ÖDEME BILGISI" yazıyordu. Belge başlığı müşterinin
  /// gördüğü ilk şey — orada yanlış harf kabul edilemez.
  static String _upperTr(String value) =>
      value.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();

  static Future<File> _save(String fileName, pw.Document doc) async {
    final dir = await getApplicationDocumentsDirectory();
    final outDir = Directory(p.join(dir.path, 'serviscep_media', 'pdf'));
    if (!await outDir.exists()) await outDir.create(recursive: true);
    final file = File(p.join(outDir.path, fileName));
    await file.writeAsBytes(await doc.save());
    return file;
  }

  static Future<pw.MemoryImage?> _image(String? path) async {
    if (path == null || path.isEmpty) return null;
    final file = File(path);
    if (!await file.exists()) return null;
    try {
      return pw.MemoryImage(await file.readAsBytes());
    } on Object {
      // Bozuk/yarım kopyalanmış bir görsel yüzünden belge üretilememesi
      // kabul edilemez; logo olmadan devam edilir.
      return null;
    }
  }

  /// Logoyu KENDİ ORANINDA yerleştirir.
  ///
  /// Sabit kare kutu, yatay logoları (simge + yazı) küçücük bırakıyordu:
  /// 3:1 bir logo 62pt'lik kareye sığdırılınca 62×21 çiziliyor, kutunun
  /// yarısı boş kalıyordu. Burada yükseklik sabit, genişlik orandan
  /// hesaplanır ve bir üst sınırla kesilir.
  static pw.Widget _logoBox(
    pw.MemoryImage logo, {
    required double maxHeight,
    required double maxWidth,
  }) {
    // `MemoryImage` boyutları nullable; okunamazsa kareye düşülür.
    final w = logo.width ?? 0;
    final h = logo.height ?? 0;
    final ratio = (w <= 0 || h <= 0) ? 1.0 : w / h;

    var height = maxHeight;
    var width = height * ratio;
    if (width > maxWidth) {
      width = maxWidth;
      height = width / ratio;
    }

    return pw.SizedBox(
      width: width,
      height: height,
      child: pw.Image(logo, fit: pw.BoxFit.contain),
    );
  }

  static pw.TextStyle _style({
    double size = 9,
    PdfColor color = _ink,
    bool bold = false,
    bool medium = false,
    double? letterSpacing,
    double? height,
  }) {
    return pw.TextStyle(
      fontSize: size,
      color: color,
      fontWeight: bold ? pw.FontWeight.bold : null,
      font: medium && !bold ? _mediumFont : null,
      letterSpacing: letterSpacing,
      lineSpacing: height,
    );
  }

  static pw.TextStyle get _capsLabel =>
      _style(size: 7.5, color: _muted, medium: true, letterSpacing: 1.2);

  // ---------------------------------------------------------------------
  // Antet
  // ---------------------------------------------------------------------

  /// Sayfanın en üstü: ince marka şeridi ve ortada belge adı.
  static pw.Widget _titleBand(String documentTitle) {
    return pw.Column(
      children: [
        pw.Container(height: 3.5, color: _accent),
        pw.SizedBox(height: 11),
        pw.Center(
          child: pw.Text(
            _upperTr(documentTitle),
            style: _style(
              size: 18,
              bold: true,
              color: _ink,
              letterSpacing: 3.5,
            ),
          ),
        ),
        pw.SizedBox(height: 10),
      ],
    );
  }

  /// Logo + firma iletişim bilgileri (sol) ve belge künyesi (sağ).
  static pw.Widget _letterhead({
    required Company company,
    required pw.MemoryImage? logo,
    required String code,
    required DateTime date,
    DateTime? validUntil,
    String? preparedBy,
  }) {
    final contactRows = <(String, String)>[
      if (company.address?.trim().isNotEmpty == true)
        ('Adres', company.address!.trim()),
      if (company.phone?.trim().isNotEmpty == true)
        ('Telefon', company.phone!.trim()),
      if (company.email?.trim().isNotEmpty == true)
        ('E-posta', company.email!.trim()),
      if (company.taxInfo?.trim().isNotEmpty == true)
        ('Vergi D./No', company.taxInfo!.trim()),
    ];

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (logo != null) ...[
          _logoBox(logo, maxHeight: 60, maxWidth: 150),
          pw.SizedBox(width: 14),
        ],
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(company.name, style: _style(size: 12.5, bold: true)),
              pw.SizedBox(height: 4),
              for (final (label, value) in contactRows)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 1.5),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.SizedBox(
                        width: 52,
                        child: pw.Text(
                          label,
                          style: _style(size: 8, color: _muted, medium: true),
                        ),
                      ),
                      pw.Expanded(
                        child: pw.Text(value, style: _style(size: 8.2)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        pw.SizedBox(width: 14),
        pw.Container(
          width: 156,
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: pw.BoxDecoration(
            color: _accentSoft,
            border: pw.Border.all(color: _line),
            borderRadius: pw.BorderRadius.circular(5),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _metaRow('Belge No', code),
              _metaRow('Tarih', _shortDateFormat.format(date)),
              if (validUntil != null)
                _metaRow('Geçerlilik', _shortDateFormat.format(validUntil)),
              if (preparedBy?.trim().isNotEmpty == true)
                _metaRow('Yetkili', preparedBy!.trim()),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _metaRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 54,
            child: pw.Text(
              label,
              style: _style(size: 8, color: _muted, medium: true),
            ),
          ),
          pw.Expanded(
            child: pw.Text(value, style: _style(size: 8.6, medium: true)),
          ),
        ],
      ),
    );
  }

  /// Muhatap kutusu — belgenin kime düzenlendiği.
  static pw.Widget _partyBox({
    required Customer customer,
    required pw.MemoryImage? logo,
  }) {
    final rows = <(String, String)>[
      if (customer.companyName?.trim().isNotEmpty == true &&
          customer.contactName?.trim().isNotEmpty == true)
        ('İlgili', customer.contactName!.trim()),
      if (customer.address?.trim().isNotEmpty == true)
        (
          'Adres',
          [
            customer.address!.trim(),
            [
              if (customer.ilce?.trim().isNotEmpty == true)
                customer.ilce!.trim(),
              if (customer.il?.trim().isNotEmpty == true) customer.il!.trim(),
            ].join(' / '),
          ].where((line) => line.isNotEmpty).join('  '),
        ),
      if (customer.phone?.trim().isNotEmpty == true)
        ('Telefon', customer.phone!.trim()),
      if (customer.email?.trim().isNotEmpty == true)
        ('E-posta', customer.email!.trim()),
      if (customer.taxInfo?.trim().isNotEmpty == true)
        ('Vergi D./No', customer.taxInfo!.trim()),
    ];

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _line),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('SAYIN', style: _capsLabel),
                pw.SizedBox(height: 3),
                pw.Text(
                  customer.displayName,
                  style: _style(size: 12.5, bold: true),
                ),
                pw.SizedBox(height: 5),
                for (final (label, value) in rows)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 1.5),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.SizedBox(
                          width: 52,
                          child: pw.Text(
                            label,
                            style: _style(size: 8, color: _muted, medium: true),
                          ),
                        ),
                        pw.Expanded(
                          child: pw.Text(value, style: _style(size: 8.2)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (logo != null) ...[
            pw.SizedBox(width: 12),
            _logoBox(logo, maxHeight: 52, maxWidth: 120),
          ],
        ],
      ),
    );
  }

  /// Hitap ve giriş metni — klasik teklif formlarının olmazsa olmazı.
  static pw.Widget _intro(String text) {
    return pw.Container(
      width: double.infinity,
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.justify,
        style: _style(size: 9, height: 3.2),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Kalemler ve toplamlar
  // ---------------------------------------------------------------------

  /// Kalem tablosu. `TableHelper` yerine elle kurulmuş bir tablo: zebra
  /// satırlar, sağa yaslı tutarlar ve sayfa taşmasında tekrar eden başlık
  /// için hücre biçimi üzerinde tam denetim gerekiyor.
  static pw.Widget _itemsTable({
    required List<PdfLineItem> items,
    required Currency currency,
    required VatMode vatMode,
  }) {
    pw.Widget cell(
      String text, {
      pw.Alignment align = pw.Alignment.centerLeft,
      pw.TextStyle? style,
    }) {
      return pw.Container(
        alignment: align,
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5.5),
        child: pw.Text(
          text,
          style: style ?? _style(size: 8.6),
          textAlign: align == pw.Alignment.centerRight
              ? pw.TextAlign.right
              : align == pw.Alignment.center
              ? pw.TextAlign.center
              : pw.TextAlign.left,
        ),
      );
    }

    final headerStyle = _style(
      size: 7.6,
      color: PdfColors.white,
      medium: true,
      letterSpacing: 0.7,
    );

    // İskonto sütunu YALNIZCA gerçekten iskonto varsa çıkar.
    //
    // Sebebi somut: bir belgede birim fiyat 3.500, tutar 3.000 yazıyordu
    // ve aradaki farkı açıklayan hiçbir şey yoktu — yalnızca en altta
    // küçük bir dipnot. Müşteri belgedeki aritmetiği takip edemiyorsa
    // belge güven vermez. Sütun olmadığında da tablo gereksiz yere
    // kalabalıklaşmasın diye koşullu.
    final iskontoVar = items.any((item) => item.discountMinor > 0);

    return pw.Table(
      border: pw.TableBorder.all(color: _line, width: 0.6),
      columnWidths: {
        0: const pw.FixedColumnWidth(24),
        1: pw.FlexColumnWidth(iskontoVar ? 3.6 : 4.2),
        2: const pw.FixedColumnWidth(38),
        3: const pw.FixedColumnWidth(40),
        4: const pw.FlexColumnWidth(1.6),
        if (iskontoVar) 5: const pw.FlexColumnWidth(1.4),
        (iskontoVar ? 6 : 5): const pw.FixedColumnWidth(32),
        (iskontoVar ? 7 : 6): const pw.FlexColumnWidth(1.8),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _accent),
          repeat: true,
          children: [
            cell('NO', align: pw.Alignment.center, style: headerStyle),
            cell('MALZEME / HİZMET AÇIKLAMASI', style: headerStyle),
            cell('ADET', align: pw.Alignment.center, style: headerStyle),
            cell('BİRİM', align: pw.Alignment.center, style: headerStyle),
            cell(
              'BİRİM FİYAT',
              align: pw.Alignment.centerRight,
              style: headerStyle,
            ),
            if (iskontoVar)
              cell(
                'İSKONTO',
                align: pw.Alignment.centerRight,
                style: headerStyle,
              ),
            cell('KDV', align: pw.Alignment.center, style: headerStyle),
            cell('TUTAR', align: pw.Alignment.centerRight, style: headerStyle),
          ],
        ),
        for (var i = 0; i < items.length; i++)
          pw.TableRow(
            decoration: i.isOdd ? const pw.BoxDecoration(color: _zebra) : null,
            children: [
              cell(
                '${i + 1}',
                align: pw.Alignment.center,
                style: _style(size: 8.4, color: _muted),
              ),
              cell(
                items[i].description,
                style: _style(size: 8.8, medium: true),
              ),
              cell('${items[i].quantity}', align: pw.Alignment.center),
              cell(items[i].unit, align: pw.Alignment.center),
              cell(
                Money.formatMinor(items[i].unitPriceMinor, currency: currency),
                align: pw.Alignment.centerRight,
              ),
              if (iskontoVar)
                cell(
                  items[i].discountMinor > 0
                      ? '-${Money.formatMinor(items[i].discountMinor, currency: currency)}'
                      : '—',
                  align: pw.Alignment.centerRight,
                ),
              cell('%${items[i].taxRate}', align: pw.Alignment.center),
              cell(
                // "+ KDV" belgede satır tutarı KDV'siz yazılır ve KDV altta
                // bir kez eklenir; "KDV dahil" belgede satır tutarı zaten
                // KDV'lidir. Böylece sütun toplamı alttaki Ara Toplam ile
                // birebir tutar — müşteri belgedeki aritmetiği takip
                // edebilmeli.
                Money.formatMinor(
                  vatMode == VatMode.included
                      ? items[i].amounts(vatMode).grossMinor
                      : items[i].amounts(vatMode).netMinor,
                  currency: currency,
                ),
                align: pw.Alignment.centerRight,
                style: _style(size: 8.8, medium: true),
              ),
            ],
          ),
      ],
    );
  }

  /// Belgede KDV'yi anlatan iki metin: toplam satırının etiketi ve toplam
  /// kutusunun solundaki açıklama cümlesi.
  ///
  /// Oran satırlardan TÜRETİLİR, belge düzeyinde varsayılmaz. Kalem editörü
  /// satır başına oran seçtiriyor (%0, %1, %10, %20 — Türkiye'nin gerçek
  /// oranları); tek bir orandan söz eden bir belge, karma oranlı teklifte
  /// müşteriye yanlış bilgi verir. "KDV (%20)" yazan satırın altında
  /// gerçekte %10 ve %20 karışımı bir tutar durabiliyordu.
  ///
  /// [fallbackRate] yalnızca hiç kalem yokken kullanılır.
  static ({String rowLabel, String caption}) vatTexts({
    required List<PdfLineItem> items,
    required VatMode vatMode,
    int fallbackRate = 20,
  }) {
    final oranlar = items.map((item) => item.taxRate).toSet();

    final int? tekOran = switch (oranlar.length) {
      0 => fallbackRate,
      1 => oranlar.first,
      _ => null,
    };
    final tumuSifir = oranlar.isNotEmpty && oranlar.every((o) => o == 0);

    final String caption;
    if (vatMode == VatMode.included) {
      caption = 'Fiyatlarımıza KDV dahildir.';
    } else if (tumuSifir) {
      // "%0 KDV ilave edilecektir" anlamsız bir cümle.
      caption = 'Fiyatlarımıza KDV uygulanmamıştır.';
    } else if (tekOran == null) {
      caption =
          'Fiyatlarımıza KDV dahil değildir; her satırda belirtilen '
          'oranda KDV ilave edilecektir.';
    } else {
      caption =
          'Fiyatlarımıza KDV dahil değildir; %$tekOran KDV ilave '
          'edilecektir.';
    }

    return (
      rowLabel: tekOran == null ? 'KDV' : 'KDV (%$tekOran)',
      caption: caption,
    );
  }

  static pw.Widget _totalsPanel({
    required DocumentTotals totals,
    required Currency currency,
    required String vatRowLabel,
  }) {
    pw.Widget row(String label, int amount) {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: _line, width: 0.6)),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(label, style: _style(size: 8.8, color: _muted)),
            pw.Text(
              Money.formatMinor(amount, currency: currency),
              style: _style(size: 9, medium: true),
            ),
          ],
        ),
      );
    }

    return pw.Container(
      width: 246,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _line),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          row('Ara Toplam (KDV hariç)', totals.netMinor),
          row(vatRowLabel, totals.vatMinor),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const pw.BoxDecoration(color: _accent),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  'GENEL TOPLAM',
                  style: _style(
                    size: 9,
                    color: PdfColors.white,
                    medium: true,
                    letterSpacing: 0.9,
                  ),
                ),
                pw.Text(
                  Money.formatMinor(totals.grossMinor, currency: currency),
                  style: _style(size: 13, color: PdfColors.white, bold: true),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Toplam kutusunun solundaki açıklama — KDV kipi, para birimi ve
  /// yazıyla tutar. Boş kalan alanı bilgiyle doldurur.
  static pw.Widget _totalsCaption({
    required Currency currency,
    required String vatCaption,
  }) {
    final lines = <String>[
      vatCaption,
      'Tutarlar ${currency.label} (${currency.code}) cinsindendir.',
    ];

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        for (final line in lines)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 3),
            child: pw.Text(line, style: _style(size: 8.2, color: _muted)),
          ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Şartlar, notlar, imza
  // ---------------------------------------------------------------------

  /// Belgenin alt bölümü: solda şartlar + notlar, sağda ödeme bilgisi.
  ///
  /// Önce üç ayrı kutuydu (Şartlar / Notlar / Ödeme Bilgisi) ve alt alta
  /// dizilince belge ikinci sayfaya taşıyordu. Teklif formunun tek sayfada
  /// kalması pratikte bir tercih değil gerekliliktir: müşteri tek sayfayı
  /// okur, ikinci sayfaya bakmaz. İki sütun hem yeri yarıya indirir hem de
  /// "şartlar" ile "nereye ödeyeceğim" bilgisini yan yana getirir.
  static pw.Widget _bottomBlocks({
    required List<(String, String)> termRows,
    required String? notes,
    required Company company,
  }) {
    // Ödeme bloğu HER ZAMAN çıkar.
    //
    // Önceden yalnızca IBAN doluysa çiziliyordu; kullanıcı IBAN'ı
    // girmediğinde blok sessizce kayboluyor ve belge eksik olduğunu
    // söylemiyordu. Blok sabit durunca boşluk görünür oluyor.
    //
    // Yine de tamamen boş bir kutu müşterinin gözünde baskı hatası gibi
    // durur; IBAN yoksa elimizdeki iletişim bilgisiyle doldurulur.
    final iban = company.iban?.trim() ?? '';
    final hasIban = iban.isNotEmpty;

    pw.Widget panel({
      required String title,
      required List<pw.Widget> children,
    }) {
      return pw.Container(
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _line),
          borderRadius: pw.BorderRadius.circular(5),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 4.5,
              ),
              decoration: const pw.BoxDecoration(
                color: _zebra,
                border: pw.Border(
                  bottom: pw.BorderSide(color: _line, width: 0.6),
                ),
              ),
              child: pw.Text(_upperTr(title), style: _capsLabel),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.fromLTRB(10, 7, 10, 8),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisSize: pw.MainAxisSize.min,
                children: children,
              ),
            ),
          ],
        ),
      );
    }

    pw.Widget labelled(String label, String value) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 2.5),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 88,
              child: pw.Text(label, style: _style(size: 8.2, medium: true)),
            ),
            pw.Expanded(child: pw.Text(value, style: _style(size: 8.2))),
          ],
        ),
      );
    }

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          flex: 3,
          child: panel(
            title: 'Şartlar ve Notlar',
            children: [
              for (final (label, value) in termRows) labelled(label, value),
              if (notes?.trim().isNotEmpty == true) ...[
                if (termRows.isNotEmpty)
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 4),
                    child: pw.Container(height: 0.6, color: _line),
                  ),
                pw.Text(notes!.trim(), style: _style(size: 8.2, height: 2.4)),
              ],
            ],
          ),
        ),
        pw.SizedBox(width: 12),
        pw.Expanded(
          flex: 2,
          child: panel(
            title: 'Ödeme Bilgisi',
            children: [
              pw.Text(company.name, style: _style(size: 8.4, medium: true)),
              pw.SizedBox(height: 3),
              if (hasIban) ...[
                pw.Text('IBAN', style: _style(size: 7.6, color: _muted)),
                pw.Text(
                  iban,
                  style: _style(size: 9, medium: true, letterSpacing: 0.3),
                ),
              ] else
                // IBAN girilmemiş. Kutuyu boş bırakmak yerine muhatabın
                // ödeme için ulaşabileceği bilgi yazılır.
                for (final satir in _paymentFallbackLines(company))
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 1.5),
                    child: pw.Text(satir, style: _style(size: 8.2)),
                  ),
            ],
          ),
        ),
      ],
    );
  }

  /// IBAN yokken ödeme bloğunu dolduran iletişim satırları.
  static List<String> _paymentFallbackLines(Company company) {
    final satirlar = <String>[
      if (company.phone?.trim().isNotEmpty == true) company.phone!.trim(),
      if (company.email?.trim().isNotEmpty == true) company.email!.trim(),
    ];

    // Hiçbir iletişim bilgisi yoksa kutu tek satırla yine de anlamlı kalır.
    if (satirlar.isEmpty) {
      return const ['Ödeme bilgisi için lütfen bizimle iletişime geçin.'];
    }
    return satirlar;
  }

  static pw.Widget _noteBlock(String title, String body) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _line),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(_upperTr(title), style: _capsLabel),
          pw.SizedBox(height: 4),
          pw.Text(body, style: _style(size: 8.6, height: 2.6)),
        ],
      ),
    );
  }

  /// Kaşe/imza kutuları — evrakın ıslak imzayla kapanan kısmı.
  static pw.Widget _signatureBoxes(String preparer, String approver) {
    pw.Widget box(String title, String name) {
      return pw.Expanded(
        child: pw.Container(
          height: 66,
          decoration: pw.BoxDecoration(border: pw.Border.all(color: _line)),
          child: pw.Column(
            children: [
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(vertical: 5),
                decoration: const pw.BoxDecoration(color: _zebra),
                child: pw.Center(
                  child: pw.Text(
                    _upperTr(title),
                    style: _style(size: 8.4, medium: true, letterSpacing: 0.8),
                  ),
                ),
              ),
              pw.Expanded(child: pw.SizedBox()),
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 6),
                child: pw.Text(
                  name,
                  textAlign: pw.TextAlign.center,
                  style: _style(size: 8, color: _muted),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return pw.Row(
      children: [
        box('Düzenleyen', '$preparer  ·  Ad Soyad / Kaşe / İmza'),
        pw.SizedBox(width: 14),
        box('Onaylayan', '$approver  ·  Ad Soyad / Kaşe / İmza'),
      ],
    );
  }

  static pw.Widget _footer(pw.Context context, Company company) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(height: 0.6, color: _line),
        pw.SizedBox(height: 5),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Text(
                'Bu belge ${company.name} tarafından düzenlenmiştir ve '
                'yalnızca muhatabına yöneliktir.',
                style: _style(size: 7, color: _muted),
              ),
            ),
            pw.Text(
              'Sayfa ${context.pageNumber} / ${context.pagesCount}',
              style: _style(size: 7, color: _muted),
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Belgeler
  // ---------------------------------------------------------------------

  /// Varsayılan giriş metni — kullanıcı kendi metnini girmediyse.
  ///
  /// Belge adı cümleye ek alarak gömülmez: "teklif formu" + "muz" gibi
  /// birleştirmeler Türkçede bozuk sonuç veriyor. Bunun yerine belgeye
  /// uygun hazır cümle seçilir.
  static String defaultIntro(String documentTitle) {
    final isProforma = documentTitle.toLowerCase().contains('proforma');
    final subject = isProforma
        ? 'düzenlediğimiz proforma faturamız'
        : 'hazırladığımız fiyat teklifimiz';

    return 'Sayın Yetkili,\n'
        'Talebiniz doğrultusunda $subject aşağıda bilgilerinize '
        'sunulmuştur. Belirtilen fiyatlar, geçerlilik tarihine kadar '
        'bağlayıcıdır. Konuyla ilgili sorularınız için her zaman '
        'ulaşabilirsiniz. Saygılarımızla.';
  }

  static Future<File> buildQuoteOrProformaPdf({
    required String documentTitle,
    required String code,
    required DateTime date,
    required Company company,
    required Customer customer,
    required List<PdfLineItem> items,
    String? notes,
    DateTime? validUntil,
    Currency currency = Currency.try_,
    VatMode vatMode = VatMode.excluded,
    int vatRate = 20,
    String? preparedBy,
    String? introText,
    String? paymentTerms,
    String? deliveryTime,
    String? warrantyTerms,
  }) async {
    final doc = await buildQuoteOrProformaDocument(
      documentTitle: documentTitle,
      code: code,
      date: date,
      company: company,
      customer: customer,
      items: items,
      notes: notes,
      validUntil: validUntil,
      currency: currency,
      vatMode: vatMode,
      vatRate: vatRate,
      preparedBy: preparedBy,
      introText: introText,
      paymentTerms: paymentTerms,
      deliveryTime: deliveryTime,
      warrantyTerms: warrantyTerms,
    );
    return _save('$code.pdf', doc);
  }

  /// Belgeyi kurar ama diske YAZMAZ.
  ///
  /// Ayrı durmasının sebebi: dosya sistemi `path_provider` üzerinden
  /// platform kanalı ister; belgenin kendisini bir testte üretip
  /// doğrulayabilmek (ve örnek çıktı alabilmek) için yazma adımından
  /// bağımsız bir giriş gerekiyor.
  static Future<pw.Document> buildQuoteOrProformaDocument({
    required String documentTitle,
    required String code,
    required DateTime date,
    required Company company,
    required Customer customer,
    required List<PdfLineItem> items,
    String? notes,
    DateTime? validUntil,
    Currency currency = Currency.try_,
    VatMode vatMode = VatMode.excluded,
    int vatRate = 20,
    String? preparedBy,
    String? introText,
    String? paymentTerms,
    String? deliveryTime,
    String? warrantyTerms,
  }) async {
    final doc = pw.Document(theme: await _theme());
    final companyLogo = await _image(company.logoPath);
    final customerLogo = await _image(customer.logoPath);

    final amounts = items.map((item) => item.amounts(vatMode)).toList();
    final totals = DocumentTotals.from(
      amounts,
      discountMinor: items.fold(0, (sum, item) => sum + item.discountMinor),
    );

    // KDV metinleri satırlardan türetilir; belge düzeyindeki [vatRate]
    // yalnızca hiç kalem yokken kullanılacak bir yedektir.
    final vatMetinleri = vatTexts(
      items: items,
      vatMode: vatMode,
      fallbackRate: vatRate,
    );

    final termRows = <(String, String)>[
      if (paymentTerms?.trim().isNotEmpty == true)
        ('Ödeme koşulları', paymentTerms!.trim()),
      if (deliveryTime?.trim().isNotEmpty == true)
        ('Teslim süresi', deliveryTime!.trim()),
      if (warrantyTerms?.trim().isNotEmpty == true)
        ('Garanti', warrantyTerms!.trim()),
      // Geçerlilik tarihi BİLİNÇLİ olarak burada tekrarlanmaz: künyede
      // zaten "Geçerlilik 09.09.2026" yazıyor. Aynı bilgiyi iki ayrı
      // biçimde ("09.09.2026" ve "9 Eylül 2026") iki ayrı yerde yazmak,
      // muhatapta hangisinin bağlayıcı olduğu sorusunu doğuruyordu.
    ];

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(34, 26, 34, 28),
        footer: (context) => _footer(context, company),
        header: (context) => context.pageNumber == 1
            ? pw.SizedBox()
            : pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 10),
                child: pw.Text(
                  '${_upperTr(documentTitle)} · $code',
                  style: _style(size: 8, color: _muted),
                ),
              ),
        // `build` bir kez çağrılır ve döndürülen liste sayfalara bölünür;
        // antet bu yüzden yalnızca ilk sayfada görünür, taşan sayfalara
        // yukarıdaki `header` düşer.
        build: (context) => [
          _titleBand(documentTitle),
          _letterhead(
            company: company,
            logo: companyLogo,
            code: code,
            date: date,
            validUntil: validUntil,
            preparedBy: preparedBy,
          ),
          pw.SizedBox(height: 10),
          _partyBox(customer: customer, logo: customerLogo),
          pw.SizedBox(height: 9),
          _intro(
            introText?.trim().isNotEmpty == true
                ? introText!.trim()
                : defaultIntro(documentTitle),
          ),
          pw.SizedBox(height: 10),
          _itemsTable(items: items, currency: currency, vatMode: vatMode),
          pw.SizedBox(height: 9),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: _totalsCaption(
                  currency: currency,
                  vatCaption: vatMetinleri.caption,
                ),
              ),
              pw.SizedBox(width: 14),
              _totalsPanel(
                totals: totals,
                currency: currency,
                vatRowLabel: vatMetinleri.rowLabel,
              ),
            ],
          ),
          if (termRows.isNotEmpty ||
              notes?.trim().isNotEmpty == true ||
              company.iban?.trim().isNotEmpty == true) ...[
            pw.SizedBox(height: 9),
            _bottomBlocks(termRows: termRows, notes: notes, company: company),
          ],
          pw.SizedBox(height: 10),
          _signatureBoxes(company.name, customer.displayName),
        ],
      ),
    );

    return doc;
  }

  static Future<File> buildServiceFormPdf({
    required Job job,
    required Company company,
    required Customer customer,
    required List<JobNote> notes,
    File? signatureFile,
    String? signerName,
  }) async {
    final doc = pw.Document(theme: await _theme());
    final companyLogo = await _image(company.logoPath);
    final customerLogo = await _image(customer.logoPath);

    pw.MemoryImage? signatureImage;
    if (signatureFile != null && await signatureFile.exists()) {
      signatureImage = pw.MemoryImage(await signatureFile.readAsBytes());
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(34, 26, 34, 28),
        footer: (context) => _footer(context, company),
        build: (context) => [
          _titleBand('Servis Formu'),
          _letterhead(
            company: company,
            logo: companyLogo,
            code: job.code,
            date: job.appointmentDate ?? job.createdAt,
          ),
          pw.SizedBox(height: 12),
          _partyBox(customer: customer, logo: customerLogo),
          pw.SizedBox(height: 10),
          _noteBlock(
            'İş / Talep',
            [
              job.title,
              if (job.description?.trim().isNotEmpty == true)
                job.description!.trim(),
            ].join('\n'),
          ),
          pw.SizedBox(height: 8),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _line),
              borderRadius: pw.BorderRadius.circular(5),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('YAPILAN İŞLEMLER', style: _capsLabel),
                pw.SizedBox(height: 4),
                if (notes.isEmpty)
                  pw.Text('—', style: _style(size: 8.6, color: _muted))
                else
                  for (final note in notes)
                    pw.Bullet(text: note.note, style: _style(size: 8.6)),
              ],
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Container(
              width: 246,
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 9,
              ),
              decoration: const pw.BoxDecoration(color: _accent),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'TOPLAM',
                    style: _style(
                      size: 9,
                      color: PdfColors.white,
                      medium: true,
                      letterSpacing: 0.9,
                    ),
                  ),
                  pw.Text(
                    Money.formatMinor(
                      job.actualPriceMinor ?? job.estimatedPriceMinor ?? 0,
                    ),
                    style: _style(size: 13, color: PdfColors.white, bold: true),
                  ),
                ],
              ),
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Container(
                  height: 88,
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: _line),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Container(
                        width: double.infinity,
                        padding: const pw.EdgeInsets.symmetric(vertical: 5),
                        decoration: const pw.BoxDecoration(color: _zebra),
                        child: pw.Center(
                          child: pw.Text(
                            'HİZMETİ VEREN',
                            style: _style(
                              size: 8.4,
                              medium: true,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ),
                      pw.Expanded(child: pw.SizedBox()),
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 6),
                        child: pw.Text(
                          company.name,
                          style: _style(size: 8, color: _muted),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 14),
              pw.Expanded(
                child: pw.Container(
                  height: 88,
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: _line),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Container(
                        width: double.infinity,
                        padding: const pw.EdgeInsets.symmetric(vertical: 5),
                        decoration: const pw.BoxDecoration(color: _zebra),
                        child: pw.Center(
                          child: pw.Text(
                            'HİZMETİ ALAN',
                            style: _style(
                              size: 8.4,
                              medium: true,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ),
                      pw.Expanded(
                        child: pw.Center(
                          child: signatureImage == null
                              ? pw.SizedBox()
                              : pw.Image(signatureImage, height: 40),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 6),
                        child: pw.Text(
                          signerName ?? customer.displayName,
                          style: _style(size: 8, color: _muted),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            'Bu belgedeki imza, resmi elektronik imza yerine geçmez; yalnızca '
            'servis kaydına bağlı bir onaydır.',
            style: _style(size: 7, color: _muted),
          ),
        ],
      ),
    );

    return _save('${job.code}.pdf', doc);
  }
}

/// PDF'e giden tek bir kalem. Tutarı kendisi hesaplamaz; [amounts] ile
/// ortak hesap motoruna devreder.
class PdfLineItem {
  const PdfLineItem({
    required this.description,
    required this.quantity,
    required this.unit,
    required this.unitPriceMinor,
    required this.taxRate,
    required this.discountMinor,
  });

  final String description;
  final int quantity;
  final String unit;
  final int unitPriceMinor;
  final int taxRate;
  final int discountMinor;

  LineAmounts amounts(VatMode vatMode) => LineAmounts.compute(
    quantity: quantity,
    unitPriceMinor: unitPriceMinor,
    discountMinor: discountMinor,
    vatRate: taxRate,
    vatMode: vatMode,
  );
}

extension QuoteItemToLine on QuoteItem {
  PdfLineItem toLineItem() => PdfLineItem(
    description: description,
    quantity: quantity,
    unit: unit,
    unitPriceMinor: unitPriceMinor,
    taxRate: taxRate,
    discountMinor: discountMinor,
  );
}

extension ProformaItemToLine on ProformaItem {
  PdfLineItem toLineItem() => PdfLineItem(
    description: description,
    quantity: quantity,
    unit: unit,
    unitPriceMinor: unitPriceMinor,
    taxRate: taxRate,
    discountMinor: discountMinor,
  );
}
