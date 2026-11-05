/// Pure-Dart offline financial and numerical formatting utilities.
class AppFormatters {
  AppFormatters._();

  /// Formats an integer minor-units balance (scaled by 100) into a readable string
  /// with thousand separators (e.g. 125000000 -> "1,250,000.00" or "1,250,000").
  static String formatMinorUnits(
    int minorUnits, {
    bool includeDecimals = false,
  }) {
    final isNegative = minorUnits < 0;
    final absVal = minorUnits.abs();
    final integerPart = absVal ~/ 100;
    final decimalPart = (absVal % 100).toString().padLeft(2, '0');

    final formattedInt = integerPart
        .toString()
        .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

    final sign = isNegative ? '-' : '';
    if (includeDecimals) {
      return '$sign$formattedInt.$decimalPart';
    }
    return '$sign$formattedInt';
  }

  /// Formats an amount with currency symbol.
  static String formatCurrency(
    int minorUnits, {
    String currencySymbol = 'ر.ي',
    bool includeDecimals = false,
  }) {
    return '${formatMinorUnits(minorUnits, includeDecimals: includeDecimals)} $currencySymbol';
  }
}
