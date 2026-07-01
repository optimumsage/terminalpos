import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../../core/enums.dart';
import 'printer_transport.dart';

/// Bluetooth (classic SPP) transport — the primary, fully-supported path for
/// Android thermal POS printers. Wraps `print_bluetooth_thermal`.
///
/// Every native call is guarded by a timeout so a missing adapter or an
/// un-granted runtime permission surfaces as a clear error instead of a UI that
/// hangs forever.
class BluetoothTransport implements PrinterTransport {
  @override
  PrinterInterface get interface => PrinterInterface.bluetooth;

  static const _quick = Duration(seconds: 6);
  static const _connectTimeout = Duration(seconds: 12);

  @override
  Future<List<PrinterDevice>> discover() async {
    final enabled = await PrintBluetoothThermal.bluetoothEnabled.timeout(
      _quick,
      onTimeout: () => throw PrinterException(
          'Bluetooth is not responding. Grant the “Nearby devices” '
          'permission and make sure Bluetooth is on.'),
    );
    if (!enabled) {
      throw PrinterException('Bluetooth is turned off. Enable it and retry.');
    }
    final paired = await PrintBluetoothThermal.pairedBluetooths.timeout(
      _quick,
      onTimeout: () => <BluetoothInfo>[],
    );
    return paired
        .map((b) => PrinterDevice(
              id: b.macAdress,
              name: b.name.isEmpty ? b.macAdress : b.name,
              interface: PrinterInterface.bluetooth,
            ))
        .toList();
  }

  @override
  Future<void> connect(PrinterDevice device) async {
    final ok = await PrintBluetoothThermal.connect(macPrinterAddress: device.id)
        .timeout(_connectTimeout, onTimeout: () => false);
    if (!ok) {
      throw PrinterException(
          'Could not connect to ${device.name}. Check it is on and paired.');
    }
  }

  @override
  Future<bool> isConnected() => PrintBluetoothThermal.connectionStatus
      .timeout(_quick, onTimeout: () => false);

  @override
  Future<void> send(List<int> bytes) async {
    final connected = await isConnected();
    if (!connected) {
      throw PrinterException('Printer is not connected.');
    }
    final ok = await PrintBluetoothThermal.writeBytes(bytes)
        .timeout(_connectTimeout, onTimeout: () => false);
    if (!ok) {
      throw PrinterException('Failed to send data to the printer.');
    }
  }

  @override
  Future<void> disconnect() async {
    await PrintBluetoothThermal.disconnect
        .timeout(_quick, onTimeout: () => false);
  }
}
