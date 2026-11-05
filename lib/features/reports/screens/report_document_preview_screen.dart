import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../../../core/constants/app_colors.dart';
import '../../organizations/models/organization_branding.dart';
import '../services/pdf_report_service.dart';

/// Screen providing professional Arabic PDF preview, local storage export,
/// Android system printing, and sharing via WhatsApp/applications.
class ReportDocumentPreviewScreen extends StatefulWidget {
  final String title;
  final String organizationName;
  final String baseCurrency;
  final String periodOrDate;
  final List<String> headers;
  final List<List<String>> rows;
  final List<String>? totals;
  final String? subtitle;
  final OrganizationBranding? branding;
  final String? documentNumber;
  final String? notes;
  final bool isInvoiceOrVoucher;

  const ReportDocumentPreviewScreen({
    super.key,
    required this.title,
    required this.organizationName,
    required this.baseCurrency,
    required this.periodOrDate,
    required this.headers,
    required this.rows,
    this.totals,
    this.subtitle,
    this.branding,
    this.documentNumber,
    this.notes,
    this.isInvoiceOrVoucher = false,
  });

  @override
  State<ReportDocumentPreviewScreen> createState() =>
      _ReportDocumentPreviewScreenState();
}

class _ReportDocumentPreviewScreenState
    extends State<ReportDocumentPreviewScreen> {
  final PdfReportService _pdfService = PdfReportService.instance;
  bool _isSaving = false;

  String _getArabicFileName() {
    final cleanTitle = widget.title
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '');
    final suffix = widget.documentNumber?.replaceAll(RegExp(r'\s+'), '_') ??
        DateTime.now().toIso8601String().substring(0, 10);
    return '${cleanTitle}_$suffix.pdf';
  }

  Future<Uint8List> _buildPdf() async {
    return await _pdfService.generateProfessionalArabicPdf(
      title: widget.title,
      organizationName: widget.organizationName,
      baseCurrency: widget.baseCurrency,
      periodOrDate: widget.periodOrDate,
      headers: widget.headers,
      rows: widget.rows,
      totals: widget.totals,
      subtitle: widget.subtitle,
      branding: widget.branding,
      documentNumber: widget.documentNumber,
      notes: widget.notes,
      isInvoiceOrVoucher: widget.isInvoiceOrVoucher,
    );
  }

  Future<void> _handleSaveToDownloads(Uint8List bytes) async {
    setState(() => _isSaving = true);
    try {
      final fileName = _getArabicFileName();
      final file = await _pdfService.savePdfToFile(
        bytes: bytes,
        fileName: fileName,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'تم حفظ المستند بنجاح في مجلد التنزيلات:\n${file.path}',
                    style: const TextStyle(fontSize: 12.5),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل حفظ المستند: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fileName = _getArabicFileName();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(
            widget.title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          actions: [
            if (_isSaving)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                ),
              ),
          ],
        ),
        body: PdfPreview(
          build: (format) => _buildPdf(),
          pdfFileName: fileName,
          canChangePageFormat: false,
          canChangeOrientation: false,
          canDebug: false,
          allowPrinting: true,
          allowSharing: true,
          scrollViewDecoration: const BoxDecoration(
            color: Color(0xFFF1F5F9),
          ),
          loadingWidget: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: AppColors.primary),
                SizedBox(height: 12),
                Text(
                  'جاري إعداد المستند وطباعة الخط العربي...',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.darkNavy,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            PdfPreviewAction(
              icon: const Icon(Icons.save_alt_rounded),
              onPressed: (context, build, pageFormat) async {
                final bytes = await build(pageFormat);
                await _handleSaveToDownloads(bytes);
              },
            ),
          ],
        ),
      ),
    );
  }
}
