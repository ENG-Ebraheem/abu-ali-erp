import 'payment_allocation_model.dart';

/// Model representing a payment voucher (Receipt or Disbursement).
class PaymentModel {
  final String id;
  final String organizationId;
  final String partyId;
  final String cashBankAccountId;
  final String? journalEntryId;
  final String paymentType; // 'RECEIPT' or 'PAYMENT'
  final String paymentNumber;
  final String paymentDate; // YYYY-MM-DD
  final String paymentMethod; // 'CASH', 'BANK_TRANSFER', 'CHEQUE'
  final String currencyCode;
  final int exchangeRateScaled; // Scale 1,000,000 = 1.000000
  final int amount; // Minor units (scale 100)
  final int allocatedAmount; // Minor units (scale 100)
  final int unallocatedAmount; // Minor units (scale 100)
  final String? referenceNumber;
  final String status; // 'DRAFT', 'POSTED', 'VOIDED'
  final String? notes;
  final String createdAt;
  final String updatedAt;
  final List<PaymentAllocationModel> allocations;

  // Joined display fields
  final String? partyNameAr;
  final String? partyCode;
  final String? cashBankAccountNameAr;

  const PaymentModel({
    required this.id,
    required this.organizationId,
    required this.partyId,
    required this.cashBankAccountId,
    this.journalEntryId,
    required this.paymentType,
    required this.paymentNumber,
    required this.paymentDate,
    this.paymentMethod = 'CASH',
    required this.currencyCode,
    required this.exchangeRateScaled,
    required this.amount,
    this.allocatedAmount = 0,
    required this.unallocatedAmount,
    this.referenceNumber,
    this.status = 'DRAFT',
    this.notes,
    this.createdAt = '',
    this.updatedAt = '',
    this.allocations = const [],
    this.partyNameAr,
    this.partyCode,
    this.cashBankAccountNameAr,
  });

  bool get isReceipt => paymentType == 'RECEIPT';
  bool get isPayment => paymentType == 'PAYMENT';

  bool get isPosted => status == 'POSTED';
  bool get isDraft => status == 'DRAFT';
  bool get isVoided => status == 'VOIDED';

  bool get isFullyAllocated => unallocatedAmount == 0;
  bool get hasUnallocated => unallocatedAmount > 0;

  double get amountDouble => amount / 100.0;
  double get allocatedDouble => allocatedAmount / 100.0;
  double get unallocatedDouble => unallocatedAmount / 100.0;
  double get exchangeRateDouble => exchangeRateScaled / 1000000.0;

  String get typeLabel => isReceipt ? 'سند قبض' : 'سند صرف';

  String get methodLabel {
    switch (paymentMethod) {
      case 'CASH':
        return 'نقداً';
      case 'BANK_TRANSFER':
        return 'تحويل بنكي';
      case 'CHEQUE':
        return 'شيك';
      default:
        return paymentMethod;
    }
  }

  String get statusLabel {
    switch (status) {
      case 'POSTED':
        return 'مرحّل';
      case 'DRAFT':
        return 'مسودة';
      case 'VOIDED':
        return 'ملغي / معكوس';
      default:
        return status;
    }
  }

  factory PaymentModel.fromMap(
    Map<String, dynamic> map, {
    List<PaymentAllocationModel> allocations = const [],
  }) {
    return PaymentModel(
      id: map['id'] as String,
      organizationId: map['organization_id'] as String,
      partyId: map['party_id'] as String,
      cashBankAccountId: map['cash_bank_account_id'] as String,
      journalEntryId: map['journal_entry_id'] as String?,
      paymentType: map['payment_type'] as String,
      paymentNumber: map['payment_number'] as String,
      paymentDate: map['payment_date'] as String,
      paymentMethod: map['payment_method'] as String? ?? 'CASH',
      currencyCode: map['currency_code'] as String,
      exchangeRateScaled: (map['exchange_rate_scaled'] as num).toInt(),
      amount: (map['amount'] as num).toInt(),
      allocatedAmount: (map['allocated_amount'] as num?)?.toInt() ?? 0,
      unallocatedAmount: (map['unallocated_amount'] as num).toInt(),
      referenceNumber: map['reference_number'] as String?,
      status: map['status'] as String? ?? 'DRAFT',
      notes: map['notes'] as String?,
      createdAt: map['created_at'] as String? ?? '',
      updatedAt: map['updated_at'] as String? ?? '',
      allocations: allocations,
      partyNameAr: map['party_name_ar'] as String?,
      partyCode: map['party_code'] as String?,
      cashBankAccountNameAr: map['cash_bank_account_name_ar'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'organization_id': organizationId,
      'party_id': partyId,
      'cash_bank_account_id': cashBankAccountId,
      'journal_entry_id': journalEntryId,
      'payment_type': paymentType,
      'payment_number': paymentNumber,
      'payment_date': paymentDate,
      'payment_method': paymentMethod,
      'currency_code': currencyCode,
      'exchange_rate_scaled': exchangeRateScaled,
      'amount': amount,
      'allocated_amount': allocatedAmount,
      'unallocated_amount': unallocatedAmount,
      'reference_number': referenceNumber,
      'status': status,
      'notes': notes,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  PaymentModel copyWith({
    String? id,
    String? organizationId,
    String? partyId,
    String? cashBankAccountId,
    String? journalEntryId,
    String? paymentType,
    String? paymentNumber,
    String? paymentDate,
    String? paymentMethod,
    String? currencyCode,
    int? exchangeRateScaled,
    int? amount,
    int? allocatedAmount,
    int? unallocatedAmount,
    String? referenceNumber,
    String? status,
    String? notes,
    String? createdAt,
    String? updatedAt,
    List<PaymentAllocationModel>? allocations,
    String? partyNameAr,
    String? partyCode,
    String? cashBankAccountNameAr,
  }) {
    return PaymentModel(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      partyId: partyId ?? this.partyId,
      cashBankAccountId: cashBankAccountId ?? this.cashBankAccountId,
      journalEntryId: journalEntryId ?? this.journalEntryId,
      paymentType: paymentType ?? this.paymentType,
      paymentNumber: paymentNumber ?? this.paymentNumber,
      paymentDate: paymentDate ?? this.paymentDate,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      currencyCode: currencyCode ?? this.currencyCode,
      exchangeRateScaled: exchangeRateScaled ?? this.exchangeRateScaled,
      amount: amount ?? this.amount,
      allocatedAmount: allocatedAmount ?? this.allocatedAmount,
      unallocatedAmount: unallocatedAmount ?? this.unallocatedAmount,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      allocations: allocations ?? this.allocations,
      partyNameAr: partyNameAr ?? this.partyNameAr,
      partyCode: partyCode ?? this.partyCode,
      cashBankAccountNameAr:
          cashBankAccountNameAr ?? this.cashBankAccountNameAr,
    );
  }
}
