import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../../core/enums.dart';
import 'printer_transport.dart';

/// Bluetooth (classic SPP) transport — the primary, fully-supported path for
/// Android thermal POS printers. Wraps `print_bluetooth_thermal`.
class BluetoothTransport implements PrinterTransport {
  @override
  PrinterInterface get interface => PrinterInterface.bluetooth;

  @override
  Future<List<PrinterDevice>> discover() async {
    final enabled = await PrintBluetoothThermal.bluetoothEnabled;
    if (!enabled) {
      throw PrinterException('Bluetooth is turned off. Enable it and retry.');
    }
    final paired = await PrintBluetoothThermal.pairedBluetooths;
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
    final ok =
        await PrintBluetoothThermal.connect(macPrinterAddress: device.id);
    if (!ok) {
      throw PrinterException('Could not connect to ${device.name}.');
    }
  }

  @override
  Future<bool> isConnected() => PrintBluetoothThermal.connectionStatus;

  @override
  Future<void> send(List<int> bytes) async {
    final connected = await PrintBluetoothThermal.connectionStatus;
    if (!connected) {
      throw PrinterException('Printer is not connected.');
    }
    final ok = await PrintBluetoothThermal.writeBytes(bytes);
    if (!ok) {
      throw PrinterException('Failed to send data to the printer.');
    }
  }

  @override
  Future<void> disconnect() async {
    await PrintBluetoothThermal.disconnect;
  }
}
