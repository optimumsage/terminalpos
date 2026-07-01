/// Shared enums for the domain layer and settings.
///
/// Kept in one place so the persistence layer (JSON serialization) and the UI
/// reference a single source of truth.
library;

enum PrinterInterface { bluetooth, usb, lan }

enum PrinterLanguage { escpos, zpl, cpcl }

/// Raster print method for ESC/POS printers.
enum PrintMethod {
  auto('Auto'),
  gsv0('GS v 0'),
  esc33('ESC * 33 (Epson)'),
  star('ESC/Star (Star Micronics)');

  const PrintMethod(this.label);
  final String label;
}

enum CutMode { full, partial, none }

/// How thousands/decimal groups are rendered for money values.
enum AmountSeparator {
  commaDot('1,234.56', ',', '.'),
  dotComma('1.234,56', '.', ','),
  spaceDot('1 234.56', ' ', '.'),
  none('1234.56', '', '.');

  const AmountSeparator(this.example, this.thousands, this.decimal);
  final String example;
  final String thousands;
  final String decimal;
}

enum CurrencyPlacement { before, after }

/// Discount applied to a line or to the whole invoice.
enum DiscountKind { none, percent, fixed }

enum InvoiceStatus { draft, finalized, printed }

/// Sections that a template can render, in order. Reordering/toggling these is
/// how templates are customized.
enum TemplateSection {
  logo('Logo'),
  business('Business info'),
  meta('Invoice # / date'),
  billTo('Bill to'),
  items('Item table'),
  totals('Totals'),
  notes('Notes'),
  footer('Footer'),
  qr('QR code');

  const TemplateSection(this.label);
  final String label;
}

enum TemplateAlignment { left, center }
