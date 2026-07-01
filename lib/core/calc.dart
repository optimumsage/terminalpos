import '../core/enums.dart';
import '../models/invoice.dart';

/// Derived totals for an invoice. All values are in the invoice currency and
/// already rounded to nothing — the formatter handles display rounding.
class InvoiceTotals {
  const InvoiceTotals({
    required this.subtotal,
    required this.invoiceDiscount,
    required this.taxable,
    required this.tax,
    required this.grandTotal,
    required this.itemCount,
    required this.totalQuantity,
  });

  final double subtotal;
  final double invoiceDiscount;
  final double taxable;
  final double tax;
  final double grandTotal;
  final int itemCount;
  final double totalQuantity;
}

/// Pure calculation engine. Order of operations:
///   line net = qty*price - line discount   (clamped >= 0)
///   subtotal = sum(line net)
///   after invoice discount = subtotal - invoice discount   (clamped >= 0)
///   tax = taxable * rate%   (only if enabled)
///   grand total = taxable + tax
class InvoiceCalculator {
  const InvoiceCalculator();

  InvoiceTotals compute(Invoice invoice) {
    var subtotal = 0.0;
    var quantity = 0.0;
    for (final item in invoice.items) {
      subtotal += item.net;
      quantity += item.quantity;
    }

    final invoiceDiscount = _discountAmount(
      subtotal,
      invoice.discountKind,
      invoice.discountValue,
    );
    final taxable = _clampToZero(subtotal - invoiceDiscount);
    final tax =
        invoice.taxEnabled ? taxable * (invoice.taxRate / 100) : 0.0;
    final grandTotal = taxable + tax;

    return InvoiceTotals(
      subtotal: subtotal,
      invoiceDiscount: invoiceDiscount,
      taxable: taxable,
      tax: tax,
      grandTotal: grandTotal,
      itemCount: invoice.items.length,
      totalQuantity: quantity,
    );
  }

  double _discountAmount(double base, DiscountKind kind, double value) {
    switch (kind) {
      case DiscountKind.none:
        return 0;
      case DiscountKind.percent:
        return base * (value / 100);
      case DiscountKind.fixed:
        return value > base ? base : value;
    }
  }

  double _clampToZero(double v) => v < 0 ? 0 : v;
}
