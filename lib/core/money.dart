import 'enums.dart';

/// Formats money and quantities according to the user's currency and
/// amount-separator settings. Pure functions — no Flutter or IO dependency, so
/// they are trivially unit-testable.
class MoneyFormatter {
  const MoneyFormatter({
    this.symbol = 'Rs.',
    this.code = 'PKR',
    this.placement = CurrencyPlacement.before,
    this.separator = AmountSeparator.commaDot,
    this.decimals = 2,
  });

  final String symbol;
  final String code;
  final CurrencyPlacement placement;
  final AmountSeparator separator;
  final int decimals;

  /// "1234.5" -> "1,234.50" (grouping + decimal per [separator]).
  String formatNumber(num value) {
    final negative = value < 0;
    final fixed = value.abs().toStringAsFixed(decimals);
    final parts = fixed.split('.');
    final intPart = parts[0];
    final fracPart = parts.length > 1 ? parts[1] : '';

    final grouped = _group(intPart, separator.thousands);
    final buffer = StringBuffer();
    if (negative) buffer.write('-');
    buffer.write(grouped);
    if (decimals > 0) {
      buffer
        ..write(separator.decimal)
        ..write(fracPart);
    }
    return buffer.toString();
  }

  /// Adds the currency symbol in the configured position, e.g. "Rs. 1,234.50".
  String format(num value) {
    final number = formatNumber(value);
    if (symbol.isEmpty) return number;
    return placement == CurrencyPlacement.before
        ? '$symbol $number'
        : '$number $symbol';
  }

  /// Quantities render without currency and trim trailing zeros (2 -> "2",
  /// 2.5 -> "2.5").
  String formatQuantity(num value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value
        .toString()
        .replaceFirst('.', separator.decimal == ',' ? ',' : '.');
  }

  static String _group(String digits, String sep) {
    if (sep.isEmpty || digits.length <= 3) return digits;
    final buffer = StringBuffer();
    final firstGroup = digits.length % 3;
    var index = 0;
    if (firstGroup > 0) {
      buffer.write(digits.substring(0, firstGroup));
      index = firstGroup;
    }
    while (index < digits.length) {
      if (buffer.isNotEmpty) buffer.write(sep);
      buffer.write(digits.substring(index, index + 3));
      index += 3;
    }
    return buffer.toString();
  }
}
