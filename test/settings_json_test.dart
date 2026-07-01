import 'package:flutter_test/flutter_test.dart';
import 'package:terminalpos/core/enums.dart';
import 'package:terminalpos/models/app_settings.dart';

void main() {
  test('AppSettings survives a JSON round-trip (enum fields included)', () {
    final original = AppSettings()
      ..printerInterface = PrinterInterface.lan
      ..printerLanguage = PrinterLanguage.zpl
      ..printMethod = PrintMethod.star
      ..cutMode = CutMode.none
      ..amountSeparator = AmountSeparator.dotComma
      ..currencyPlacement = CurrencyPlacement.after
      ..currencySymbol = '₨'
      ..paperWidthMm = 72
      ..invoiceNextNumber = 42;

    // This path previously threw NoSuchMethodError on the enum `.name` lookup.
    final restored = AppSettings.fromJson(original.toJson());

    expect(restored.printerInterface, PrinterInterface.lan);
    expect(restored.printerLanguage, PrinterLanguage.zpl);
    expect(restored.printMethod, PrintMethod.star);
    expect(restored.cutMode, CutMode.none);
    expect(restored.amountSeparator, AmountSeparator.dotComma);
    expect(restored.currencyPlacement, CurrencyPlacement.after);
    expect(restored.currencySymbol, '₨');
    expect(restored.paperWidthMm, 72);
    expect(restored.invoiceNextNumber, 42);
  });

  test('defaults round-trip and keep PKR', () {
    final restored = AppSettings.fromJson(AppSettings().toJson());
    expect(restored.currencyCode, 'PKR');
    expect(restored.currencySymbol, 'Rs.');
    expect(restored.printerInterface, PrinterInterface.bluetooth);
  });
}
