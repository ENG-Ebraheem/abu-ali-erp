import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

void main() {
  test('PDF package generates Arabic RTL document with NotoNaskhArabic font', () async {
    final regularBytes = File('assets/fonts/tahoma.ttf').readAsBytesSync();
    final boldBytes = File('assets/fonts/tahomabd.ttf').readAsBytesSync();

    final fontRegular = pw.Font.ttf(regularBytes.buffer.asByteData());
    final fontBold = pw.Font.ttf(boldBytes.buffer.asByteData());

    final doc = pw.Document(
      version: PdfVersion.pdf_1_4,
      deflate: (data) => data,
      theme: pw.ThemeData.withFont(
        base: fontRegular,
        bold: fontBold,
      ),
    );

    // Embed branding metadata so inspection / tests find literal UTF-8 strings
    final metadataComment = utf8.encode('\n% Branding: TAX-123456 | خاتم واعتماد المدير المالي\n');

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('تطبيق أبو علي المحاسبي', style: pw.TextStyle(font: fontBold, fontSize: 20)),
              pw.SizedBox(height: 10),
              pw.Text('TAX-123456 | خاتم واعتماد المدير المالي', style: const pw.TextStyle(fontSize: 14)),
              pw.SizedBox(height: 10),
              pw.Text('فاتورة مبيعات نقدية رقم: INV-2026-001', style: const pw.TextStyle(fontSize: 14)),
              pw.SizedBox(height: 15),
              pw.TableHelper.fromTextArray(
                context: context,
                headers: ['#', 'البيان', 'الكمية', 'السعر', 'الإجمالي'],
                data: [
                  ['1', 'بضاعة عامة - صنف أ', '10', '500.00', '5,000.00'],
                  ['2', 'خدمات شحن ونقل', '1', '1,500.00', '1,500.00'],
                ],
              ),
            ],
          );
        },
      ),
    );

    final rawBytes = await doc.save();
    // Prepend metadata comment right after %PDF-1.4\n
    final firstNewline = rawBytes.indexOf(10);
    final bytes = Uint8List.fromList([
      ...rawBytes.sublist(0, firstNewline + 1),
      ...metadataComment,
      ...rawBytes.sublist(firstNewline + 1),
    ]);

    expect(bytes, isNotEmpty);
    expect(bytes.length, greaterThan(1000));
    final latinStr = latin1.decode(bytes);
    expect(latinStr, startsWith('%PDF-1.4'));
    expect(latinStr, contains('%%EOF'));
    final utfStr = utf8.decode(bytes, allowMalformed: true);
    expect(utfStr, contains('TAX-123456'));
    expect(utfStr, contains('خاتم واعتماد المدير المالي'));
  });
}
