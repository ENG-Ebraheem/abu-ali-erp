/// Model representing the allocation of a payment against a specific invoice.
class PaymentAllocationModel {
  final String id;
  final String organizationId;
  final String paymentId;
  final String invoiceId;
  final int allocatedAmount; // Minor units (scale 100)
  final int realizedForexGainLoss; // Minor units (scale 100)
  final String allocationDate; // YYYY-MM-DD
  final String createdAt;

  // Joined display fields
  final String? invoiceNumber;
  final String? invoiceType;

  const PaymentAllocationModel({
    required this.id,
    required this.organizationId,
    required this.paymentId,
    required this.invoiceId,
    required this.allocatedAmount,
    this.realizedForexGainLoss = 0,
    required this.allocationDate,
    this.createdAt = '',
    this.invoiceNumber,
    this.invoiceType,
  });

  double get allocatedAmountDouble => allocatedAmount / 100.0;
  double get realizedForexDouble => realizedForexGainLoss / 100.0;

  factory PaymentAllocationModel.fromMap(Map<String, dynamic> map) {
    return PaymentAllocationModel(
      id: map['id'] as String,
      organizationId: map['organization_id'] as String,
      paymentId: map['payment_id'] as String,
      invoiceId: map['invoice_id'] as String,
      allocatedAmount: (map['allocated_amount'] as num).toInt(),
      realizedForexGainLoss:
          (map['realized_forex_gain_loss'] as num?)?.toInt() ?? 0,
      allocationDate: map['allocation_date'] as String,
      createdAt: map['created_at'] as String? ?? '',
      invoiceNumber: map['invoice_number'] as String?,
      invoiceType: map['invoice_type'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'organization_id': organizationId,
      'payment_id': paymentId,
      'invoice_id': invoiceId,
      'allocated_amount': allocatedAmount,
      'realized_forex_gain_loss': realizedForexGainLoss,
      'allocation_date': allocationDate,
      'created_at': createdAt,
    };
  }
}
