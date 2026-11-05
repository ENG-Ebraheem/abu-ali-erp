/// Model representing an exchange rate between two currencies on a given date.
class ExchangeRateModel {
  final String id;
  final String organizationId;
  final String fromCurrencyCode;
  final String toCurrencyCode;
  final int rateScaled; // Scale 1,000,000 = 1.000000
  final String rateDate; // YYYY-MM-DD
  final String createdAt;

  const ExchangeRateModel({
    required this.id,
    required this.organizationId,
    required this.fromCurrencyCode,
    required this.toCurrencyCode,
    required this.rateScaled,
    required this.rateDate,
    required this.createdAt,
  });

  /// The rate as a decimal number (e.g. 535.50)
  double get rateAsDouble => rateScaled / 1000000.0;

  /// Human-readable formatted rate
  String get formattedRate => rateAsDouble.toStringAsFixed(4);

  factory ExchangeRateModel.fromMap(Map<String, dynamic> map) {
    return ExchangeRateModel(
      id: map['id'] as String,
      organizationId: map['organization_id'] as String,
      fromCurrencyCode: map['from_currency_code'] as String,
      toCurrencyCode: map['to_currency_code'] as String,
      rateScaled: (map['rate_scaled'] as num).toInt(),
      rateDate: map['rate_date'] as String,
      createdAt: map['created_at'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'organization_id': organizationId,
      'from_currency_code': fromCurrencyCode,
      'to_currency_code': toCurrencyCode,
      'rate_scaled': rateScaled,
      'rate_date': rateDate,
      'created_at': createdAt,
    };
  }
}
