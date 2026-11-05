/// Model representing a single itemized line in an invoice.
class InvoiceLineModel {
  final String id;
  final String organizationId;
  final String invoiceId;
  final int lineNumber;
  final String accountId;
  final String itemDescription;
  final int quantityScaled; // Scale 1,000 = 1.000 units
  final int unitPrice; // Minor units (scale 100)
  final int discountAmount; // Minor units (scale 100)
  final int taxAmount; // Minor units (scale 100)
  final int lineTotal; // Minor units (scale 100)
  final String createdAt;

  // Joined display field
  final String? accountNameAr;

  const InvoiceLineModel({
    required this.id,
    required this.organizationId,
    required this.invoiceId,
    required this.lineNumber,
    required this.accountId,
    required this.itemDescription,
    this.quantityScaled = 1000,
    required this.unitPrice,
    this.discountAmount = 0,
    this.taxAmount = 0,
    required this.lineTotal,
    this.createdAt = '',
    this.accountNameAr,
  });

  double get quantityDouble => quantityScaled / 1000.0;
  double get unitPriceDouble => unitPrice / 100.0;
  double get discountDouble => discountAmount / 100.0;
  double get taxDouble => taxAmount / 100.0;
  double get lineTotalDouble => lineTotal / 100.0;

  factory InvoiceLineModel.fromMap(Map<String, dynamic> map) {
    return InvoiceLineModel(
      id: map['id'] as String,
      organizationId: map['organization_id'] as String,
      invoiceId: map['invoice_id'] as String,
      lineNumber: (map['line_number'] as num).toInt(),
      accountId: map['account_id'] as String,
      itemDescription: map['item_description'] as String,
      quantityScaled: (map['quantity_scaled'] as num?)?.toInt() ?? 1000,
      unitPrice: (map['unit_price'] as num).toInt(),
      discountAmount: (map['discount_amount'] as num?)?.toInt() ?? 0,
      taxAmount: (map['tax_amount'] as num?)?.toInt() ?? 0,
      lineTotal: (map['line_total'] as num).toInt(),
      createdAt: map['created_at'] as String? ?? '',
      accountNameAr: map['account_name_ar'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'organization_id': organizationId,
      'invoice_id': invoiceId,
      'line_number': lineNumber,
      'account_id': accountId,
      'item_description': itemDescription,
      'quantity_scaled': quantityScaled,
      'unit_price': unitPrice,
      'discount_amount': discountAmount,
      'tax_amount': taxAmount,
      'line_total': lineTotal,
      'created_at': createdAt,
    };
  }
}
