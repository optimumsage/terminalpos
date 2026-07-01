import 'package:flutter_test/flutter_test.dart';
import 'package:terminalpos/core/enums.dart';
import 'package:terminalpos/core/money.dart';

void main() {
  test('default PKR formatting: Rs. prefix, comma/dot', () {
    const f = MoneyFormatter();
    expect(f.format(10), 'Rs. 10.00');
    expect(f.format(1234.5), 'Rs. 1,234.50');
    expect(f.format(1234567.89), 'Rs. 1,234,567.89');
  });

  test('dot/comma separator', () {
    const f = MoneyFormatter(separator: AmountSeparator.dotComma);
    expect(f.formatNumber(1234567.89), '1.234.567,89');
  });

  test('space/dot separator', () {
    const f = MoneyFormatter(separator: AmountSeparator.spaceDot);
    expect(f.formatNumber(1234567.89), '1 234 567.89');
  });

  test('no thousands separator', () {
    const f = MoneyFormatter(separator: AmountSeparator.none);
    expect(f.formatNumber(1234567.89), '1234567.89');
  });

  test('symbol placement after', () {
    const f = MoneyFormatter(placement: CurrencyPlacement.after);
    expect(f.format(50), '50.00 Rs.');
  });

  test('custom decimals and negative', () {
    const f = MoneyFormatter(decimals: 0);
    expect(f.formatNumber(-1500), '-1,500');
  });

  test('quantity trims trailing zeros', () {
    const f = MoneyFormatter();
    expect(f.formatQuantity(2), '2');
    expect(f.formatQuantity(2.5), '2.5');
  });
}
