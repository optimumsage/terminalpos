import '../../core/enums.dart';

/// A discovered/known printer endpoint.
class PrinterDevice {
  const PrinterDevice({
    required this.id,
    required this.name,
    required this.interface,
  });

  /// MAC address (Bluetooth), "host:port" (LAN) or USB identifier.
  final String id;
  final String name;
  final PrinterInterface interface;
}

class PrinterException implements Exception {
  PrinterException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Sends raw bytes to a printer over one physical interface. Builders produce
/// the bytes; transports know nothing about ESC/POS vs ZPL. Adding iOS support
/// later means providing new transport implementations only.
abstract class PrinterTransport {
  PrinterInterface get interface;

  /// Lists reachable devices (paired BT devices, the configured LAN endpoint,
  /// attached USB devices).
  Future<List<PrinterDevice>> discover();

  Future<void> connect(PrinterDevice device);

  Future<bool> isConnected();

  Future<void> send(List<int> bytes);

  Future<void> disconnect();
}
