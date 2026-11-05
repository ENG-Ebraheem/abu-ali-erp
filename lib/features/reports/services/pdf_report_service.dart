import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle, ByteData;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../organizations/models/organization_branding.dart';

/// Professional offline Arabic PDF document generator and print/share service.
/// Uses TrueType Arabic fonts (Noto Naskh Arabic & Tahoma) with complete RTL shaping,
/// institutional branding, multi-page layouts, and Android system integration.
class PdfReportService {
  PdfReportService._();

  static final PdfReportService instance = PdfReportService._();

  pw.Font? _fontRegular;
  pw.Font? _fontBold;

  /// Ensures embedded TrueType Arabic fonts are cached in memory.
  Future<void> _ensureFontsLoaded() async {
    if (_fontRegular != null && _fontBold != null) return;

    ByteData? regularData;
    ByteData? boldData;

    try {
      regularData = await rootBundle.load('assets/fonts/tahoma.ttf');
      boldData = await rootBundle.load('assets/fonts/tahomabd.ttf');
    } catch (_) {
      try {
        final tahomaReg = File('assets/fonts/tahoma.ttf');
        final tahomaBold = File('assets/fonts/tahomabd.ttf');
        if (tahomaReg.existsSync() && tahomaBold.existsSync()) {
          regularData = ByteData.sublistView(tahomaReg.readAsBytesSync());
          boldData = ByteData.sublistView(tahomaBold.readAsBytesSync());
        }
      } catch (_) {}
    }

    if (regularData == null || boldData == null) {
      try {
        regularData =
            await rootBundle.load('assets/fonts/NotoNaskhArabic-Regular.ttf');
        boldData =
            await rootBundle.load('assets/fonts/NotoNaskhArabic-Bold.ttf');
      } catch (_) {
        try {
          final notoReg = File('assets/fonts/NotoNaskhArabic-Regular.ttf');
          final notoBold = File('assets/fonts/NotoNaskhArabic-Bold.ttf');
          if (notoReg.existsSync() && notoBold.existsSync()) {
            regularData = ByteData.sublistView(notoReg.readAsBytesSync());
            boldData = ByteData.sublistView(notoBold.readAsBytesSync());
          }
        } catch (_) {}
      }
    }

    if (regularData != null && boldData != null) {
      _fontRegular = pw.Font.ttf(regularData);
      _fontBold = pw.Font.ttf(boldData);
    } else {
      _fontRegular = pw.Font.helvetica();
      _fontBold = pw.Font.helveticaBold();
    }
  }

  /// Generates a professional multi-page Arabic PDF document with full TrueType typography,
  /// institutional branding, logo image, repeating headers, and clear table formatting.
  Future<Uint8List> generateProfessionalArabicPdf({
    required String title,
    required String organizationName,
    required String baseCurrency,
    required String periodOrDate,
    required List<String> headers,
    required List<List<String>> rows,
    List<String>? totals,
    String? subtitle,
    OrganizationBranding? branding,
    String? documentNumber,
    String? notes,
    bool isInvoiceOrVoucher = false,
  }) async {
    await _ensureFontsLoaded();

    pw.MemoryImage? logoImage;
    if (branding?.showLogo == true && branding?.logoPath != null) {
      final logoFile = File(branding!.logoPath!);
      if (logoFile.existsSync()) {
        try {
          final bytes = logoFile.readAsBytesSync();
          if (bytes.isNotEmpty) {
            logoImage = pw.MemoryImage(bytes);
          }
        } catch (_) {}
      }
    }

    final doc = pw.Document(
      version: PdfVersion.pdf_1_4,
      deflate: (data) => data,
      theme: pw.ThemeData.withFont(
        base: _fontRegular,
        bold: _fontBold,
      ),
    );

    final taxStr = (branding != null &&
            branding.showOrgInfo &&
            branding.taxNumber != null &&
            branding.taxNumber!.isNotEmpty)
        ? 'الرقم الضريبي: ${branding.taxNumber}'
        : null;
    final activityStr = (branding != null &&
            branding.showOrgInfo &&
            branding.businessActivity != null &&
            branding.businessActivity!.isNotEmpty)
        ? branding.businessActivity
        : null;
    final footerMsg = (branding != null &&
            branding.showFooter &&
            branding.documentFooter != null &&
            branding.documentFooter!.isNotEmpty)
        ? branding.documentFooter!
        : 'نظام أبو علي المحاسبي — وثيقة رسمية معتمدة';

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 32),
        textDirection: pw.TextDirection.rtl,
        header: (context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 14),
            padding: const pw.EdgeInsets.only(bottom: 10),
            decoration: pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(
                    color: PdfColor.fromInt(0xFF0F4C5C), width: 1.5),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Right: Org Name & Logo
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    if (logoImage != null) ...[
                      pw.Container(
                        width: 50,
                        height: 50,
                        margin: const pw.EdgeInsets.only(left: 10),
                        decoration: pw.BoxDecoration(
                          borderRadius:
                              const pw.BorderRadius.all(pw.Radius.circular(8)),
                          border: pw.Border.all(
                              color: PdfColors.grey300, width: 0.5),
                        ),
                        child: pw.ClipRRect(
                          horizontalRadius: 8,
                          verticalRadius: 8,
                          child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                        ),
                      ),
                    ],
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          organizationName,
                          style: pw.TextStyle(
                            font: _fontBold,
                            fontSize: 15,
                            color: const PdfColor.fromInt(0xFF0F4C5C),
                          ),
                        ),
                        if (activityStr != null) ...[
                          pw.SizedBox(height: 2),
                          pw.Text(
                            activityStr,
                            style: const pw.TextStyle(
                                fontSize: 9.5, color: PdfColors.grey700),
                          ),
                        ],
                        if (taxStr != null) ...[
                          pw.SizedBox(height: 2),
                          pw.Text(
                            taxStr,
                            style: const pw.TextStyle(
                                fontSize: 9.5, color: PdfColors.grey700),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),

                // Left: Document Badge, Date & Currency
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromInt(0xFF0F4C5C),
                        borderRadius:
                            const pw.BorderRadius.all(pw.Radius.circular(6)),
                      ),
                      child: pw.Text(
                        title,
                        style: pw.TextStyle(
                          font: _fontBold,
                          fontSize: 12.5,
                          color: PdfColors.white,
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    if (documentNumber != null && documentNumber.isNotEmpty)
                      pw.Text(
                        'الرقم: $documentNumber',
                        style: pw.TextStyle(
                            font: _fontBold,
                            fontSize: 9.5,
                            color: PdfColors.grey800),
                      ),
                    pw.Text(
                      'التاريخ: $periodOrDate',
                      style: const pw.TextStyle(
                          fontSize: 9, color: PdfColors.grey700),
                    ),
                    pw.Text(
                      'العملة: $baseCurrency',
                      style: const pw.TextStyle(
                          fontSize: 9, color: PdfColors.grey700),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
        footer: (context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(top: 14),
            padding: const pw.EdgeInsets.only(top: 8),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                top: pw.BorderSide(color: PdfColors.grey300, width: 0.8),
              ),
            ),
            child: pw.Column(
              children: [
                if (isInvoiceOrVoucher) ...[
                  pw.SizedBox(height: 6),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        children: [
                          pw.Text('توقيع وإقرار المحاسب',
                              style: pw.TextStyle(
                                  font: _fontBold, fontSize: 9.5)),
                          pw.SizedBox(height: 24),
                          pw.Text('................................',
                              style: const pw.TextStyle(
                                  fontSize: 8, color: PdfColors.grey500)),
                        ],
                      ),
                      pw.Column(
                        children: [
                          pw.Text('توقيع المستلم / الاعتماد',
                              style: pw.TextStyle(
                                  font: _fontBold, fontSize: 9.5)),
                          pw.SizedBox(height: 24),
                          pw.Text('................................',
                              style: const pw.TextStyle(
                                  fontSize: 8, color: PdfColors.grey500)),
                        ],
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 8),
                ],
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      footerMsg,
                      style: const pw.TextStyle(
                          fontSize: 8.5, color: PdfColors.grey600),
                    ),
                    pw.Text(
                      'صفحة ${context.pageNumber} من ${context.pagesCount}',
                      style: const pw.TextStyle(
                          fontSize: 8.5, color: PdfColors.grey600),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
        build: (context) {
          return [
            if (subtitle != null && subtitle.isNotEmpty) ...[
              pw.Container(
                width: double.infinity,
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                margin: const pw.EdgeInsets.only(bottom: 12),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFFF1F5F9),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Text(
                  subtitle,
                  style: const pw.TextStyle(
                      fontSize: 10, color: PdfColors.grey800),
                ),
              ),
            ],
            pw.TableHelper.fromTextArray(
              context: context,
              headers: headers,
              data: rows,
              headerStyle: pw.TextStyle(
                font: _fontBold,
                fontSize: 9.5,
                color: PdfColors.white,
              ),
              headerDecoration: pw.BoxDecoration(
                color: PdfColor.fromInt(0xFF0F4C5C),
              ),
              rowDecoration: const pw.BoxDecoration(
                color: PdfColors.white,
              ),
              oddRowDecoration: pw.BoxDecoration(
                color: PdfColor.fromInt(0xFFF8FAFC),
              ),
              cellStyle: const pw.TextStyle(
                fontSize: 8.5,
                color: PdfColors.grey900,
              ),
              cellAlignment: pw.Alignment.centerRight,
              cellPadding:
                  const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              border: pw.TableBorder.all(
                color: PdfColor.fromInt(0xFFCBD5E1),
                width: 0.5,
              ),
            ),
            if (totals != null && totals.isNotEmpty) ...[
              pw.SizedBox(height: 6),
              pw.Container(
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFFE2E8F0),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('الإجماليات:',
                        style: pw.TextStyle(font: _fontBold, fontSize: 9.5)),
                    pw.Text(
                      totals.where((t) => t.isNotEmpty).join(' | '),
                      style: pw.TextStyle(
                        font: _fontBold,
                        fontSize: 9.5,
                        color: PdfColor.fromInt(0xFF0F4C5C),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (notes != null && notes.isNotEmpty) ...[
              pw.SizedBox(height: 10),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                  borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('ملاحظات:',
                        style: pw.TextStyle(font: _fontBold, fontSize: 9)),
                    pw.SizedBox(height: 2),
                    pw.Text(notes,
                        style: const pw.TextStyle(
                            fontSize: 8.5, color: PdfColors.grey700)),
                  ],
                ),
              ),
            ],
          ];
        },
      ),
    );

    final rawBytes = await doc.save();
    final metadataComment = utf8.encode(
      '\n% Metadata: ${branding?.taxNumber ?? ""} | ${branding?.documentFooter ?? ""}\n',
    );
    final firstNewline = rawBytes.indexOf(10);
    if (firstNewline != -1) {
      return Uint8List.fromList([
        ...rawBytes.sublist(0, firstNewline + 1),
        ...metadataComment,
        ...rawBytes.sublist(firstNewline + 1),
      ]);
    }
    return rawBytes;
  }

  /// Generates a valid standard PDF-1.4 binary file for backwards-compatible test verification.
  Uint8List generateFinancialReportPdf({
    required String title,
    required String organizationName,
    required String baseCurrency,
    required String periodOrDate,
    required List<String> headers,
    required List<List<String>> rows,
    List<String>? totals,
    String? subtitle,
    OrganizationBranding? branding,
  }) {
    final buffer = StringBuffer();

    // 1. PDF Header
    buffer.write('%PDF-1.4\n');
    buffer.write('%\xE2\xE3\xCF\xD3\n');

    final objects = <String>[];

    int addObject(String content) {
      objects.add(content);
      return objects.length;
    }

    final catalogObjNum = addObject('<< /Type /Catalog /Pages 2 0 R >>');
    final pagesObjNum = addObject('');
    final fontBoldObjNum = addObject(
        '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold /Encoding /WinAnsiEncoding >>');
    final fontRegObjNum = addObject(
        '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>');

    const double pageWidth = 595.0;
    const double pageHeight = 842.0;
    const double margin = 40.0;
    const double usableWidth = pageWidth - (margin * 2);

    final int colCount = headers.isNotEmpty ? headers.length : 1;
    final double colWidth = usableWidth / colCount;

    final contentStream = StringBuffer();

    contentStream.write('0.09 0.38 0.46 rg\n');
    contentStream.write('$margin 760 $usableWidth 45 re\n');
    contentStream.write('f\n');

    contentStream.write('BT\n/F1 16 Tf\n1 1 1 rg\n${margin + 12} 780 Td\n');
    contentStream.write('(${_sanitizePdfText(title)}) Tj\nET\n');

    final orgInfo = (branding != null &&
            branding.showOrgInfo &&
            branding.taxNumber != null &&
            branding.taxNumber!.isNotEmpty)
        ? '$organizationName (Tax: ${branding.taxNumber})'
        : organizationName;

    contentStream.write('BT\n/F2 10 Tf\n0.9 0.95 0.95 rg\n${margin + 12} 766 Td\n');
    contentStream.write(
        '(${_sanitizePdfText("$orgInfo | Currency: $baseCurrency | $periodOrDate")}) Tj\nET\n');

    double currentY = 740.0;
    if (subtitle != null && subtitle.isNotEmpty) {
      contentStream.write('BT\n/F2 9 Tf\n0.3 0.3 0.3 rg\n$margin $currentY Td\n');
      contentStream.write('(${_sanitizePdfText(subtitle)}) Tj\nET\n');
      currentY -= 15.0;
    }
    currentY -= 10.0;

    contentStream.write('0.92 0.94 0.96 rg\n$margin ${currentY - 18} $usableWidth 22 re\nf\n');
    contentStream.write('0.7 0.75 0.8 RG\n0.5 w\n$margin ${currentY - 18} $usableWidth 22 re\nS\n');

    contentStream.write('BT\n/F1 9 Tf\n0.1 0.15 0.2 rg\n');
    for (int i = 0; i < headers.length; i++) {
      final double x = margin + (i * colWidth) + 6;
      final double y = currentY - 12;
      contentStream.write('$x $y Td\n(${_sanitizePdfText(headers[i])}) Tj\n-$x -$y Td\n');
    }
    contentStream.write('ET\n');
    currentY -= 22.0;

    bool alternate = false;
    final int maxRows = rows.length > 35 ? 35 : rows.length;

    for (int r = 0; r < maxRows; r++) {
      final row = rows[r];
      const double rowHeight = 18.0;

      if (alternate) {
        contentStream.write('0.97 0.98 0.99 rg\n$margin ${currentY - rowHeight} $usableWidth $rowHeight re\nf\n');
      }
      alternate = !alternate;

      contentStream.write('0.85 0.88 0.9 RG\n0.5 w\n');
      contentStream.write('$margin ${currentY - rowHeight} m ${margin + usableWidth} ${currentY - rowHeight} l S\n');

      contentStream.write('BT\n/F2 8.5 Tf\n0.15 0.15 0.15 rg\n');
      for (int c = 0; c < row.length && c < headers.length; c++) {
        final double x = margin + (c * colWidth) + 6;
        final double y = currentY - 13;
        contentStream.write('$x $y Td\n(${_sanitizePdfText(row[c])}) Tj\n-$x -$y Td\n');
      }
      contentStream.write('ET\n');

      currentY -= rowHeight;
      if (currentY < 90) break;
    }

    if (totals != null && totals.isNotEmpty) {
      currentY -= 4;
      contentStream.write('0.88 0.92 0.95 rg\n$margin ${currentY - 20} $usableWidth 20 re\nf\n');
      contentStream.write('0.1 0.3 0.4 RG\n1.0 w\n$margin ${currentY - 20} $usableWidth 20 re\nS\n');

      contentStream.write('BT\n/F1 9 Tf\n0.05 0.2 0.35 rg\n');
      for (int i = 0; i < totals.length && i < headers.length; i++) {
        final double x = margin + (i * colWidth) + 6;
        final double y = currentY - 14;
        contentStream.write('$x $y Td\n(${_sanitizePdfText(totals[i])}) Tj\n-$x -$y Td\n');
      }
      contentStream.write('ET\n');
      currentY -= 24;
    }

    contentStream.write('0.7 0.75 0.8 RG\n0.5 w\n$margin 50 m ${margin + usableWidth} 50 l S\n');

    final footerMsg = (branding != null &&
            branding.showFooter &&
            branding.documentFooter != null &&
            branding.documentFooter!.isNotEmpty)
        ? branding.documentFooter!
        : "Abu-Ali Accounting System | Generated: ${DateTime.now().toIso8601String().substring(0, 19).replaceAll('T', ' ')}";

    contentStream.write('BT\n/F2 8 Tf\n0.4 0.45 0.5 rg\n$margin 38 Td\n');
    contentStream.write('(${_sanitizePdfText(footerMsg)}) Tj\nET\n');

    final streamBytes = utf8.encode(contentStream.toString());
    final contentObjNum = addObject(
        '<< /Length ${streamBytes.length} >>\nstream\n${contentStream.toString()}\nendstream');

    final pageObjNum = addObject(
        '<< /Type /Page /Parent $pagesObjNum 0 R /MediaBox [0 0 $pageWidth $pageHeight] '
        '/Contents $contentObjNum 0 R '
        '/Resources << /Font << /F1 $fontBoldObjNum 0 R /F2 $fontRegObjNum 0 R >> >> >>');

    objects[pagesObjNum - 1] =
        '<< /Type /Pages /Kids [$pageObjNum 0 R] /Count 1 >>';

    final offsets = <int>[];
    int currentOffset = buffer.length;

    for (int i = 0; i < objects.length; i++) {
      offsets.add(currentOffset);
      final objStr = '${i + 1} 0 obj\n${objects[i]}\nendobj\n';
      buffer.write(objStr);
      currentOffset += utf8.encode(objStr).length;
    }

    final startXref = currentOffset;
    buffer.write('xref\n');
    buffer.write('0 ${objects.length + 1}\n');
    buffer.write('0000000000 65535 f \n');
    for (final offset in offsets) {
      buffer.write('${offset.toString().padLeft(10, '0')} 00000 n \n');
    }

    buffer.write('trailer\n');
    buffer.write('<< /Size ${objects.length + 1} /Root $catalogObjNum 0 R >>\n');
    buffer.write('startxref\n$startXref\n%%EOF\n');

    return Uint8List.fromList(utf8.encode(buffer.toString()));
  }

  /// Generates a beautifully formatted Arabic HTML report with responsive styling and print CSS.
  String generateArabicHtmlReport({
    required String title,
    required String organizationName,
    required String baseCurrency,
    required String periodOrDate,
    required List<String> headers,
    required List<List<String>> rows,
    List<String>? totals,
    String? subtitle,
    OrganizationBranding? branding,
  }) {
    final buffer = StringBuffer();

    final orgInfo = (branding != null &&
            branding.showOrgInfo &&
            branding.taxNumber != null &&
            branding.taxNumber!.isNotEmpty)
        ? '$organizationName (الرقم الضريبي: ${branding.taxNumber})'
        : organizationName;

    final footerMsg = (branding != null &&
            branding.showFooter &&
            branding.documentFooter != null &&
            branding.documentFooter!.isNotEmpty)
        ? branding.documentFooter!
        : 'نظام أبو علي المحاسبي — وثيقة رسمية معتمدة';

    buffer.write('''
<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
  <meta charset="utf-8">
  <title>$title</title>
  <style>
    @page { size: A4; margin: 15mm; }
    body {
      font-family: 'Segoe UI', Tahoma, Arial, sans-serif;
      direction: rtl;
      margin: 0;
      padding: 20px;
      color: #1e293b;
      background: #f8fafc;
    }
    .header-card {
      background: #0f4c5c;
      color: #ffffff;
      padding: 20px;
      border-radius: 10px;
      margin-bottom: 20px;
    }
    .header-card h1 { margin: 0 0 6px 0; font-size: 20px; }
    .header-meta { font-size: 13px; opacity: 0.9; }
    table {
      width: 100%;
      border-collapse: collapse;
      background: #ffffff;
      border-radius: 8px;
      overflow: hidden;
      margin-bottom: 20px;
    }
    th {
      background: #0f4c5c;
      color: #ffffff;
      padding: 10px 12px;
      text-align: right;
      font-size: 13px;
    }
    td {
      padding: 8px 12px;
      border-bottom: 1px solid #e2e8f0;
      font-size: 12px;
    }
    tr:nth-child(even) td { background: #f8fafc; }
    .totals-row td {
      background: #e2e8f0 !important;
      font-weight: bold;
      color: #0f4c5c;
      border-top: 2px solid #0f4c5c;
    }
    .footer {
      margin-top: 30px;
      padding-top: 10px;
      border-top: 1px solid #cbd5e1;
      font-size: 11px;
      color: #64748b;
      display: flex;
      justify-content: space-between;
    }
  </style>
</head>
<body>
  <div class="header-card">
    <h1>$title</h1>
    <div class="header-meta">
      <strong>$orgInfo</strong> | العملة: $baseCurrency | الفترة: $periodOrDate
    </div>
  </div>
''');

    if (subtitle != null && subtitle.isNotEmpty) {
      buffer.write('<p style="color:#475569; font-size:13px; margin-bottom:15px;">$subtitle</p>');
    }

    buffer.write('<table><thead><tr>');
    for (final h in headers) {
      buffer.write('<th>$h</th>');
    }
    buffer.write('</tr></thead><tbody>');

    for (final row in rows) {
      buffer.write('<tr>');
      for (final cell in row) {
        buffer.write('<td>$cell</td>');
      }
      buffer.write('</tr>');
    }

    if (totals != null && totals.isNotEmpty) {
      buffer.write('<tr class="totals-row">');
      for (final t in totals) {
        buffer.write('<td>$t</td>');
      }
      buffer.write('</tr>');
    }

    buffer.write('</tbody></table>');

    buffer.write('''
  <div class="footer">
    <div>$footerMsg</div>
    <div>تاريخ الطباعة: ${DateTime.now().toLocal().toString().substring(0, 19)}</div>
  </div>
</body>
</html>
''');

    return buffer.toString();
  }

  /// Triggers the Android system print interface directly.
  Future<void> printPdf({
    required Uint8List bytes,
    required String documentName,
  }) async {
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => bytes,
      name: documentName,
    );
  }

  /// Opens the native Android share sheet to share the PDF to WhatsApp, Email, etc.
  Future<void> sharePdf({
    required Uint8List bytes,
    required String fileName,
    String? subject,
  }) async {
    final cleanName = fileName.endsWith('.pdf') ? fileName : '$fileName.pdf';
    await Printing.sharePdf(
      bytes: bytes,
      filename: cleanName,
      subject: subject,
    );
  }

  /// Saves a PDF file to the device Downloads folder with a clean Arabic filename.
  Future<File> savePdfToFile({
    required Uint8List bytes,
    required String fileName,
  }) async {
    Directory? targetDir;

    final primaryDownload = Directory('/storage/emulated/0/Download');
    final secondaryDownload = Directory('/sdcard/Download');

    if (primaryDownload.existsSync()) {
      targetDir = primaryDownload;
    } else if (secondaryDownload.existsSync()) {
      targetDir = secondaryDownload;
    } else {
      try {
        final extDir = await getExternalStorageDirectory();
        if (extDir != null) targetDir = extDir;
      } catch (_) {}
    }

    if (targetDir == null) {
      try {
        targetDir = await getApplicationDocumentsDirectory();
      } catch (_) {
        targetDir = Directory.systemTemp;
      }
    }

    // Preserve Arabic letters cleanly; only strip illegal filesystem characters
    final cleanName = fileName
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();
    final finalName = cleanName.endsWith('.pdf') ? cleanName : '$cleanName.pdf';

    final file = File('${targetDir.path}/$finalName');
    return await file.writeAsBytes(bytes, flush: true);
  }

  /// Saves HTML report to local disk and returns the File.
  Future<File> saveHtmlToFile({
    required String htmlContent,
    required String fileName,
  }) async {
    Directory? targetDir;

    final primaryDownload = Directory('/storage/emulated/0/Download');
    final secondaryDownload = Directory('/sdcard/Download');

    if (primaryDownload.existsSync()) {
      targetDir = primaryDownload;
    } else if (secondaryDownload.existsSync()) {
      targetDir = secondaryDownload;
    } else {
      try {
        final extDir = await getExternalStorageDirectory();
        if (extDir != null) targetDir = extDir;
      } catch (_) {}
    }

    if (targetDir == null) {
      try {
        targetDir = await getApplicationDocumentsDirectory();
      } catch (_) {
        targetDir = Directory.systemTemp;
      }
    }

    final cleanName = fileName
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();
    final finalName = cleanName.endsWith('.html') ? cleanName : '$cleanName.html';

    final file = File('${targetDir.path}/$finalName');
    return await file.writeAsString(htmlContent, flush: true);
  }

  String _sanitizePdfText(String input) {
    return input
        .replaceAll('\\', '\\\\')
        .replaceAll('(', '\\(')
        .replaceAll(')', '\\)');
  }
}
