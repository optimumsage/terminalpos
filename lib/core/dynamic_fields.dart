import 'package:intl/intl.dart';

/// Named date/time format options exposed in printer settings. Each maps to an
/// [intl] skeleton so the actual rendering respects the device locale.
class NamedFormat {
  const NamedFormat(this.id, this.label, this.pattern);
  final String id;
  final String label;

  /// Explicit pattern (not a skeleton) so previews are deterministic in tests.
  final String pattern;

  String format(DateTime dt) => DateFormat(pattern).format(dt);
}

const List<NamedFormat> dateFormats = [
  NamedFormat('yMMMd', 'Jul 1, 2026', 'MMM d, y'),
  NamedFormat('yMd', '7/1/2026', 'M/d/y'),
  NamedFormat('dMy', '01/07/2026', 'dd/MM/y'),
  NamedFormat('ymd', '2026-07-01', 'y-MM-dd'),
  NamedFormat('yMMMMd', 'July 1, 2026', 'MMMM d, y'),
];

const List<NamedFormat> timeFormats = [
  NamedFormat('jm', '2:30 PM', 'h:mm a'),
  NamedFormat('Hm', '14:30', 'HH:mm'),
  NamedFormat('jms', '2:30:05 PM', 'h:mm:ss a'),
  NamedFormat('Hms', '14:30:05', 'HH:mm:ss'),
];

NamedFormat dateFormatById(String id) =>
    dateFormats.firstWhere((f) => f.id == id, orElse: () => dateFormats.first);

NamedFormat timeFormatById(String id) =>
    timeFormats.firstWhere((f) => f.id == id, orElse: () => timeFormats.first);

/// Default name for a freshly created invoice: "Invoice 2026-07-01 14:30".
String defaultInvoiceName(DateTime now) =>
    'Invoice ${DateFormat('y-MM-dd HH:mm').format(now)}';
