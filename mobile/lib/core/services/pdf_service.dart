import 'dart:io';

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
/// Her belge: firma bilgileri, müşteri bilgileri, belge numarası, tarih,
/// ürün/hizmet tablosu, KDV, toplam, IBAN, açıklama alanlarını destekler.
/// Tasarım sade/modern/kurumsal tutulur (docs/03 ilkesi).
abstract final class PdfService {
  static final _dateFormat = DateFormat('d MMMM y', 'tr_TR');
  static const _accent = PdfColor.fromInt(0xFF3B82F6);

  static Future<File> _save(String fileName, pw.Document doc) async {
    final dir = await getApplicationDocumentsDirectory();
    final outDir = Directory(p.join(dir.path, 'serviscep_media', 'pdf'));
    if (!await outDir.exists()) await outDir.create(recursive: true);
    final file = File(p.join(outDir.path, fileName));
    await file.writeAsBytes(await doc.save());
    return file;
  }

  static pw.Widget _header({
    required String documentTitle,
    required String code,
    required DateTime date,
    required Company company,
    required Customer customer,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  company.name,
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: _accent),
                ),
                if (company.iban?.isNotEmpty == true)
                  pw.Text('IBAN: ${company.iban}', style: const pw.TextStyle(fontSize: 9)),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  documentTitle,
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(code, style: const pw.TextStyle(fontSize: 10)),
                pw.Text(_dateFormat.format(date), style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 16),
        pw.Container(height: 1, color: PdfColors.grey300),
        pw.SizedBox(height: 16),
        pw.Text('Müşteri', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
        pw.Text(
          customer.displayName,
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
        if (customer.companyName?.isNotEmpty == true && customer.contactName?.isNotEmpty == true)
          pw.Text('Yetkili: ${customer.contactName}', style: const pw.TextStyle(fontSize: 10)),
        if (customer.address?.isNotEmpty == true)
          pw.Text(customer.address!, style: const pw.TextStyle(fontSize: 10)),
        if (customer.phone?.isNotEmpty == true)
          pw.Text(customer.phone!, style: const pw.TextStyle(fontSize: 10)),
        pw.SizedBox(height: 20),
      ],
    );
  }

  static pw.Widget _itemsTable(List<PdfLineItem> items) {
    return pw.TableHelper.fromTextArray(
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
      headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.center,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.center,
        4: pw.Alignment.centerRight,
      },
      headers: ['Açıklama', 'Miktar', 'Birim Fiyat', 'KDV', 'Tutar'],
      data: [
        for (final item in items)
          [
            item.description,
            '${item.quantity} ${item.unit}',
            Money.formatMinor(item.unitPriceMinor),
            '%${item.taxRate}',
            Money.formatMinor(item.lineTotalMinor),
          ],
      ],
    );
  }

  static pw.Widget _totalRow(String label, int amountMinor, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(fontSize: bold ? 12 : 10, fontWeight: bold ? pw.FontWeight.bold : null),
          ),
          pw.Text(
            Money.formatMinor(amountMinor),
            style: pw.TextStyle(fontSize: bold ? 12 : 10, fontWeight: bold ? pw.FontWeight.bold : null),
          ),
        ],
      ),
    );
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
  }) async {
    final doc = pw.Document();
    final total = items.fold<int>(0, (sum, i) => sum + i.lineTotalMinor);
    final subtotal = items.fold<int>(0, (sum, i) => sum + (i.quantity * i.unitPriceMinor - i.discountMinor));

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _header(documentTitle: documentTitle, code: code, date: date, company: company, customer: customer),
            if (validUntil != null)
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 12),
                child: pw.Text(
                  'Geçerlilik tarihi: ${_dateFormat.format(validUntil)}',
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ),
            _itemsTable(items),
            pw.SizedBox(height: 16),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.SizedBox(
                width: 220,
                child: pw.Column(
                  children: [
                    _totalRow('Ara Toplam', subtotal),
                    _totalRow('KDV Dahil Toplam', total, bold: true),
                  ],
                ),
              ),
            ),
            if (notes?.isNotEmpty == true) ...[
              pw.SizedBox(height: 24),
              pw.Text('Notlar', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              pw.Text(notes!, style: const pw.TextStyle(fontSize: 9)),
            ],
          ],
        ),
      ),
    );

    return _save('$code.pdf', doc);
  }

  static Future<File> buildServiceFormPdf({
    required Job job,
    required Company company,
    required Customer customer,
    required List<JobNote> notes,
    File? signatureFile,
    String? signerName,
  }) async {
    final doc = pw.Document();
    pw.MemoryImage? signatureImage;
    if (signatureFile != null && await signatureFile.exists()) {
      signatureImage = pw.MemoryImage(await signatureFile.readAsBytes());
    }

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _header(
              documentTitle: 'SERVİS FORMU',
              code: job.code,
              date: job.appointmentDate ?? job.createdAt,
              company: company,
              customer: customer,
            ),
            pw.Text('İş / Talep', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
            pw.Text(job.title, style: const pw.TextStyle(fontSize: 10)),
            if (job.description?.isNotEmpty == true) ...[
              pw.SizedBox(height: 4),
              pw.Text(job.description!, style: const pw.TextStyle(fontSize: 9)),
            ],
            pw.SizedBox(height: 16),
            pw.Text('Yapılan İşlemler', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            if (notes.isEmpty)
              pw.Text('-', style: const pw.TextStyle(fontSize: 9))
            else
              for (final note in notes)
                pw.Bullet(text: note.note, style: const pw.TextStyle(fontSize: 9)),
            pw.SizedBox(height: 16),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _totalRow(
                  'Tahmini Fiyat',
                  job.estimatedPriceMinor ?? 0,
                ),
              ],
            ),
            _totalRow('Toplam', job.actualPriceMinor ?? job.estimatedPriceMinor ?? 0, bold: true),
            pw.SizedBox(height: 32),
            pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (signatureImage != null)
                        pw.Container(height: 60, child: pw.Image(signatureImage))
                      else
                        pw.Container(height: 60),
                      pw.Container(height: 1, color: PdfColors.grey400),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        signerName != null ? 'Müşteri imzası — $signerName' : 'Müşteri imzası',
                        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              'Bu belgedeki imza, resmi elektronik imza yerine geçmez; yalnızca servis kaydına bağlı bir onaydır.',
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500),
            ),
          ],
        ),
      ),
    );

    return _save('${job.code}.pdf', doc);
  }
}

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

  int get lineTotalMinor {
    final subtotal = quantity * unitPriceMinor - discountMinor;
    return subtotal + (subtotal * taxRate / 100).round();
  }
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
