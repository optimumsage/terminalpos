import '../../core/enums.dart';
import 'printer_transport.dart';

/// USB (OTG) transport. USB thermal printing on Android needs a host-side
/// device permission handshake that can only be exercised with hardware
/// attached; discovery/selection is wired into the UI and the send path throws
/// a clear message until validated on a real device (per the project plan,
/// Bluetooth is the first fully-supported interface).
class UsbTransport implements PrinterTransport {
  @override
  PrinterInterface get interface => PrinterInterface.usb;

  @override
  Future<List<PrinterDevice>> discover() async => const [];

  @override
  Future<void> connect(PrinterDevice device) async {
    throw PrinterException(
        'USB printing requires a connected USB printer to validate. '
        'Use Bluetooth or LAN for now.');
  }

  @override
  Future<bool> isConnected() async => false;

  @override
  Future<void> send(List<int> bytes) async {
    throw PrinterException('USB transport is not connected.');
  }

  @override
  Future<void> disconnect() async {}
}
