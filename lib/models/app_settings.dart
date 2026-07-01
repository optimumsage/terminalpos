import '../core/enums.dart';
import '../core/money.dart';

/// All app-wide configuration: business identity, printer connection, print
/// behaviour, currency/formatting and the auto-increment invoice number. Stored
/// as a single JSON document in the key-value table.
class AppSettings {
  AppSettings({
    // Business identity / branding
    this.businessName = 'My Business',
    this.businessAddress = '',
    this.businessPhone = '',
    this.businessEmail = '',
    this.businessTaxId = '',
    this.logoPath = '',
    // Printer connection
    this.printerInterface = PrinterInterface.bluetooth,
    this.printerLanguage = PrinterLanguage.escpos,
    this.lastDeviceId = '',
    this.lastDeviceName = '',
    this.lanHost = '192.168.0.100',
    this.lanPort = 9100,
    this.autoConnect = true,
    // Paper / cut
    this.paperWidthMm = 58,
    this.cutMode = CutMode.partial,
    this.cutSpacing = 3,
    this.feedAfterPrint = 2,
    // Print behaviour
    this.printMethod = PrintMethod.auto,
    this.copies = 1,
    this.density = 8,
    this.codepage = 'CP437',
    this.beep = false,
    this.openCashDrawer = false,
    this.drawerPin = 0,
    // Currency / formatting
    this.currencySymbol = 'Rs.',
    this.currencyCode = 'PKR',
    this.currencyPlacement = CurrencyPlacement.before,
    this.amountSeparator = AmountSeparator.commaDot,
    this.decimalPlaces = 2,
    // Dynamic fields
    this.dateFormatId = 'yMMMd',
    this.timeFormatId = 'jm',
    this.invoicePrefix = 'INV-',
    this.invoiceNextNumber = 1,
    this.invoiceNumberPadding = 4,
    // Tax (optional, off by default)
    this.taxEnabledDefault = false,
    this.taxRateDefault = 0,
    this.taxLabel = 'Tax',
    // Theme
    this.seedColor = 0xFF3D5AFE,
    this.themeMode = 'system',
  });

  String businessName;
  String businessAddress;
  String businessPhone;
  String businessEmail;
  String businessTaxId;
  String logoPath;

  PrinterInterface printerInterface;
  PrinterLanguage printerLanguage;
  String lastDeviceId;
  String lastDeviceName;
  String lanHost;
  int lanPort;
  bool autoConnect;

  double paperWidthMm;
  CutMode cutMode;
  int cutSpacing;
  int feedAfterPrint;

  PrintMethod printMethod;
  int copies;
  int density;
  String codepage;
  bool beep;
  bool openCashDrawer;
  int drawerPin;

  String currencySymbol;
  String currencyCode;
  CurrencyPlacement currencyPlacement;
  AmountSeparator amountSeparator;
  int decimalPlaces;

  String dateFormatId;
  String timeFormatId;
  String invoicePrefix;
  int invoiceNextNumber;
  int invoiceNumberPadding;

  bool taxEnabledDefault;
  double taxRateDefault;
  String taxLabel;

  int seedColor;
  String themeMode;

  /// Convenience: a formatter bound to the current currency settings.
  MoneyFormatter get money => MoneyFormatter(
        symbol: currencySymbol,
        code: currencyCode,
        placement: currencyPlacement,
        separator: amountSeparator,
        decimals: decimalPlaces,
      );

  /// The next formatted invoice number, e.g. "INV-0007".
  String formatInvoiceNumber(int number) =>
      '$invoicePrefix${number.toString().padLeft(invoiceNumberPadding, '0')}';

  AppSettings copy() => AppSettings.fromJson(toJson());

  Map<String, dynamic> toJson() => {
        'businessName': businessName,
        'businessAddress': businessAddress,
        'businessPhone': businessPhone,
        'businessEmail': businessEmail,
        'businessTaxId': businessTaxId,
        'logoPath': logoPath,
        'printerInterface': printerInterface.name,
        'printerLanguage': printerLanguage.name,
        'lastDeviceId': lastDeviceId,
        'lastDeviceName': lastDeviceName,
        'lanHost': lanHost,
        'lanPort': lanPort,
        'autoConnect': autoConnect,
        'paperWidthMm': paperWidthMm,
        'cutMode': cutMode.name,
        'cutSpacing': cutSpacing,
        'feedAfterPrint': feedAfterPrint,
        'printMethod': printMethod.name,
        'copies': copies,
        'density': density,
        'codepage': codepage,
        'beep': beep,
        'openCashDrawer': openCashDrawer,
        'drawerPin': drawerPin,
        'currencySymbol': currencySymbol,
        'currencyCode': currencyCode,
        'currencyPlacement': currencyPlacement.name,
        'amountSeparator': amountSeparator.name,
        'decimalPlaces': decimalPlaces,
        'dateFormatId': dateFormatId,
        'timeFormatId': timeFormatId,
        'invoicePrefix': invoicePrefix,
        'invoiceNextNumber': invoiceNextNumber,
        'invoiceNumberPadding': invoiceNumberPadding,
        'taxEnabledDefault': taxEnabledDefault,
        'taxRateDefault': taxRateDefault,
        'taxLabel': taxLabel,
        'seedColor': seedColor,
        'themeMode': themeMode,
      };

  factory AppSettings.fromJson(Map<String, dynamic> j) {
    T pick<T>(String key, T fallback) =>
        j.containsKey(key) && j[key] != null ? j[key] as T : fallback;
    E pickEnum<E>(String key, List<E> values, E fallback) {
      final raw = j[key] as String?;
      if (raw == null) return fallback;
      for (final v in values) {
        if ((v as dynamic).name == raw) return v;
      }
      return fallback;
    }

    return AppSettings(
      businessName: pick('businessName', 'My Business'),
      businessAddress: pick('businessAddress', ''),
      businessPhone: pick('businessPhone', ''),
      businessEmail: pick('businessEmail', ''),
      businessTaxId: pick('businessTaxId', ''),
      logoPath: pick('logoPath', ''),
      printerInterface: pickEnum(
          'printerInterface', PrinterInterface.values, PrinterInterface.bluetooth),
      printerLanguage: pickEnum(
          'printerLanguage', PrinterLanguage.values, PrinterLanguage.escpos),
      lastDeviceId: pick('lastDeviceId', ''),
      lastDeviceName: pick('lastDeviceName', ''),
      lanHost: pick('lanHost', '192.168.0.100'),
      lanPort: pick('lanPort', 9100),
      autoConnect: pick('autoConnect', true),
      paperWidthMm: (pick<num>('paperWidthMm', 58)).toDouble(),
      cutMode: pickEnum('cutMode', CutMode.values, CutMode.partial),
      cutSpacing: pick('cutSpacing', 3),
      feedAfterPrint: pick('feedAfterPrint', 2),
      printMethod: pickEnum('printMethod', PrintMethod.values, PrintMethod.auto),
      copies: pick('copies', 1),
      density: pick('density', 8),
      codepage: pick('codepage', 'CP437'),
      beep: pick('beep', false),
      openCashDrawer: pick('openCashDrawer', false),
      drawerPin: pick('drawerPin', 0),
      currencySymbol: pick('currencySymbol', 'Rs.'),
      currencyCode: pick('currencyCode', 'PKR'),
      currencyPlacement: pickEnum(
          'currencyPlacement', CurrencyPlacement.values, CurrencyPlacement.before),
      amountSeparator: pickEnum(
          'amountSeparator', AmountSeparator.values, AmountSeparator.commaDot),
      decimalPlaces: pick('decimalPlaces', 2),
      dateFormatId: pick('dateFormatId', 'yMMMd'),
      timeFormatId: pick('timeFormatId', 'jm'),
      invoicePrefix: pick('invoicePrefix', 'INV-'),
      invoiceNextNumber: pick('invoiceNextNumber', 1),
      invoiceNumberPadding: pick('invoiceNumberPadding', 4),
      taxEnabledDefault: pick('taxEnabledDefault', false),
      taxRateDefault: (pick<num>('taxRateDefault', 0)).toDouble(),
      taxLabel: pick('taxLabel', 'Tax'),
      seedColor: pick('seedColor', 0xFF3D5AFE),
      themeMode: pick('themeMode', 'system'),
    );
  }
}
