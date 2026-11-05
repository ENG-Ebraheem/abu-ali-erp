import 'invoice_line_model.dart';

/// Model representing an invoice header (Sales, Purchase, or Opening).
class InvoiceModel {
  final String id;
  final String organizationId;
  final String partyId;
  final String? journalEntryId;
  final String
      invoiceType; // 'SALES', 'PURCHASE', 'SALES_RETURN', 'PURCHASE_RETURN', 'OPENING_RECEIVABLE', 'OPENING_PAYABLE'
  final String invoiceNumber;
  final String issueDate; // YYYY-MM-DD
  final String dueDate; // YYYY-MM-DD
  final String currencyCode;
  final int exchangeRateScaled; // Scale 1,000,000 = 1.000000
  final int subtotal; // Minor units (scale 100)
  final int taxAmount; // Minor units (scale 100)
  final int discountAmount; // Minor units (scale 100)
  final int totalAmount; // Minor units (scale 100)
  final int paidAmount; // Minor units (scale 100)
  final String paymentStatus; // 'UNPAID', 'PARTIALLY_PAID', 'PAID'
  final String status; // 'DRAFT', 'POSTED', 'CANCELLED'
  final String? notes;
  final String createdAt;
  final String updatedAt;
  final List<InvoiceLineModel> lines;

  // Joined display fields
  final String? partyNameAr;
  final String? partyCode;

  const InvoiceModel({
    required this.id,
    required this.organizationId,
    required this.partyId,
    this.journalEntryId,
    required this.invoiceType,
    required this.invoiceNumber,
    required this.issueDate,
    required this.dueDate,
    required this.currencyCode,
    required this.exchangeRateScaled,
    this.subtotal = 0,
    this.taxAmount = 0,
    this.discountAmount = 0,
    this.totalAmount = 0,
    this.paidAmount = 0,
    this.paymentStatus = 'UNPAID',
    this.status = 'DRAFT',
    this.notes,
    this.createdAt = '',
    this.updatedAt = '',
    this.lines = const [],
    this.partyNameAr,
    this.partyCode,
  });

  bool get isSales =>
      invoiceType == 'SALES' || invoiceType == 'OPENING_RECEIVABLE';
  bool get isPurchase =>
      invoiceType == 'PURCHASE' || invoiceType == 'OPENING_PAYABLE';
  bool get isOpening =>
      invoiceType == 'OPENING_RECEIVABLE' || invoiceType == 'OPENING_PAYABLE';
  bool get isSalesReturn => invoiceType == 'SALES_RETURN';
  bool get isPurchaseReturn => invoiceType == 'PURCHASE_RETURN';
  bool get isReturn => isSalesReturn || isPurchaseReturn;

  bool get isPosted => status == 'POSTED';
  bool get isDraft => status == 'DRAFT';
  bool get isCancelled => status == 'CANCELLED';

  bool get isPaid => paymentStatus == 'PAID';
  bool get isPartiallyPaid => paymentStatus == 'PARTIALLY_PAID';
  bool get isUnpaid => paymentStatus == 'UNPAID';

  int get remainingAmount => totalAmount - paidAmount;

  double get subtotalDouble => subtotal / 100.0;
  double get taxDouble => taxAmount / 100.0;
  double get discountDouble => discountAmount / 100.0;
  double get totalDouble => totalAmount / 100.0;
  double get paidDouble => paidAmount / 100.0;
  double get remainingDouble => remainingAmount / 100.0;
  double get exchangeRateDouble => exchangeRateScaled / 1000000.0;

  String get typeLabel {
    switch (invoiceType) {
      case 'SALES':
        return 'فاتورة مبيعات';
      case 'PURCHASE':
        return 'فاتورة مشتريات';
      case 'SALES_RETURN':
        return 'مردود مبيعات';
      case 'PURCHASE_RETURN':
        return 'مردود مشتريات';
      case 'OPENING_RECEIVABLE':
        return 'رصيد افتتاحي (عميل)';
      case 'OPENING_PAYABLE':
        return 'رصيد افتتاحي (مورد)';
      default:
        return invoiceType;
    }
  }

  String get paymentStatusLabel {
    switch (paymentStatus) {
      case 'PAID':
        return 'مدفوعة بالكامل';
      case 'PARTIALLY_PAID':
        return 'مدفوعة جزئياً';
      case 'UNPAID':
        return 'غير مسددة';
      default:
        return paymentStatus;
    }
  }

  String get statusLabel {
    switch (status) {
      case 'POSTED':
        return 'مرحّلة';
      case 'DRAFT':
        return 'مسودة';
      case 'CANCELLED':
        return 'ملغية';
      default:
        return status;
    }
  }

  factory InvoiceModel.fromMap(
    Map<String, dynamic> map, {
    List<InvoiceLineModel> lines = const [],
  }) {
    return InvoiceModel(
      id: map['id'] as String,
      organizationId: map['organization_id'] as String,
      partyId: map['party_id'] as String,
      journalEntryId: map['journal_entry_id'] as String?,
      invoiceType: map['invoice_type'] as String,
      invoiceNumber: map['invoice_number'] as String,
      issueDate: map['issue_date'] as String,
      dueDate: map['due_date'] as String,
      currencyCode: map['currency_code'] as String,
      exchangeRateScaled: (map['exchange_rate_scaled'] as num).toInt(),
      subtotal: (map['subtotal'] as num?)?.toInt() ?? 0,
      taxAmount: (map['tax_amount'] as num?)?.toInt() ?? 0,
      discountAmount: (map['discount_amount'] as num?)?.toInt() ?? 0,
      totalAmount: (map['total_amount'] as num?)?.toInt() ?? 0,
      paidAmount: (map['paid_amount'] as num?)?.toInt() ?? 0,
      paymentStatus: map['payment_status'] as String? ?? 'UNPAID',
      status: map['status'] as String? ?? 'DRAFT',
      notes: map['notes'] as String?,
      createdAt: map['created_at'] as String? ?? '',
      updatedAt: map['updated_at'] as String? ?? '',
      lines: lines,
      partyNameAr: map['party_name_ar'] as String?,
      partyCode: map['party_code'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'organization_id': organizationId,
      'party_id': partyId,
      'journal_entry_id': journalEntryId,
      'invoice_type': invoiceType,
      'invoice_number': invoiceNumber,
      'issue_date': issueDate,
      'due_date': dueDate,
      'currency_code': currencyCode,
      'exchange_rate_scaled': exchangeRateScaled,
      'subtotal': subtotal,
      'tax_amount': taxAmount,
      'discount_amount': discountAmount,
      'total_amount': totalAmount,
      'paid_amount': paidAmount,
      'payment_status': paymentStatus,
      'status': status,
      'notes': notes,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  InvoiceModel copyWith({
    String? id,
    String? organizationId,
    String? partyId,
    String? journalEntryId,
    String? invoiceType,
    String? invoiceNumber,
    String? issueDate,
    String? dueDate,
    String? currencyCode,
    int? exchangeRateScaled,
    int? subtotal,
    int? taxAmount,
    int? discountAmount,
    int? totalAmount,
    int? paidAmount,
    String? paymentStatus,
    String? status,
    String? notes,
    String? createdAt,
    String? updatedAt,
    List<InvoiceLineModel>? lines,
    String? partyNameAr,
    String? partyCode,
  }) {
    return InvoiceModel(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      partyId: partyId ?? this.partyId,
      journalEntryId: journalEntryId ?? this.journalEntryId,
      invoiceType: invoiceType ?? this.invoiceType,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      issueDate: issueDate ?? this.issueDate,
      dueDate: dueDate ?? this.dueDate,
      currencyCode: currencyCode ?? this.currencyCode,
      exchangeRateScaled: exchangeRateScaled ?? this.exchangeRateScaled,
      subtotal: subtotal ?? this.subtotal,
      taxAmount: taxAmount ?? this.taxAmount,
      discountAmount: discountAmount ?? this.discountAmount,
      totalAmount: totalAmount ?? this.totalAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lines: lines ?? this.lines,
      partyNameAr: partyNameAr ?? this.partyNameAr,
      partyCode: partyCode ?? this.partyCode,
    );
  }
}
