import 'package:flutter_test/flutter_test.dart';
import 'package:terminalpos/core/calc.dart';
import 'package:terminalpos/core/enums.dart';
import 'package:terminalpos/models/invoice.dart';

Invoice _invoice(List<InvoiceItem> items,
    {DiscountKind kind = DiscountKind.none,
    double value = 0,
    bool tax = false,
    double rate = 0}) {
  final now = DateTime(2026, 7, 1);
  return Invoice(
    id: 'i1',
    name: 'test',
    number: 'INV-0001',
    templateId: 'preset-classic',
    createdAt: now,
    updatedAt: now,
    discountKind: kind,
    discountValue: value,
    taxEnabled: tax,
    taxRate: rate,
    items: items,
  );
}

InvoiceItem _item(double qty, double price,
        {DiscountKind kind = DiscountKind.none, double value = 0}) =>
    InvoiceItem(
      id: 'x',
      name: 'item',
      quantity: qty,
      unitPrice: price,
      discountKind: kind,
      discountValue: value,
    );

void main() {
  const calc = InvoiceCalculator();

  test('subtotal sums line nets', () {
    final t = calc.compute(_invoice([_item(2, 100), _item(1, 50)]));
    expect(t.subtotal, 250);
    expect(t.grandTotal, 250);
    expect(t.itemCount, 2);
    expect(t.totalQuantity, 3);
  });

  test('per-line percent discount', () {
    final t = calc.compute(
        _invoice([_item(1, 100, kind: DiscountKind.percent, value: 10)]));
    expect(t.subtotal, 90);
  });

  test('per-line fixed discount never goes negative', () {
    final t = calc.compute(
        _invoice([_item(1, 100, kind: DiscountKind.fixed, value: 150)]));
    expect(t.subtotal, 0);
  });

  test('invoice percent discount applied after subtotal', () {
    final t = calc.compute(
        _invoice([_item(1, 200)], kind: DiscountKind.percent, value: 25));
    expect(t.invoiceDiscount, 50);
    expect(t.taxable, 150);
    expect(t.grandTotal, 150);
  });

  test('invoice fixed discount clamped to subtotal', () {
    final t = calc.compute(
        _invoice([_item(1, 80)], kind: DiscountKind.fixed, value: 200));
    expect(t.invoiceDiscount, 80);
    expect(t.grandTotal, 0);
  });

  test('tax only applied when enabled, on the discounted amount', () {
    final noTax = calc.compute(_invoice([_item(1, 100)], rate: 10));
    expect(noTax.tax, 0);

    final withTax = calc.compute(_invoice([_item(1, 100)],
        kind: DiscountKind.percent, value: 10, tax: true, rate: 10));
    expect(withTax.taxable, 90);
    expect(withTax.tax, closeTo(9, 1e-9));
    expect(withTax.grandTotal, closeTo(99, 1e-9));
  });
}
