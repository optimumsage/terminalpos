import 'dart:io';

import '../../core/enums.dart';
import 'printer_transport.dart';

/// Network transport — connects to a printer's raw TCP port (9100 by default)
/// using dart:io sockets, so it needs no third-party package and works
/// identically on Android and iOS.
class LanTransport implements PrinterTransport {
  Socket? _socket;
  PrinterDevice? _device;

  @override
  PrinterInterface get interface => PrinterInterface.lan;

  /// The configured LAN endpoint is provided via [manual]; there is no LAN
  /// broadcast discovery here (kept simple and reliable).
  final List<PrinterDevice> manual;
  LanTransport({this.manual = const []});

  @override
  Future<List<PrinterDevice>> discover() async => manual;

  @override
  Future<void> connect(PrinterDevice device) async {
    _device = device;
    final parts = device.id.split(':');
    final host = parts.first;
    final port = parts.length > 1 ? int.tryParse(parts[1]) ?? 9100 : 9100;
    try {
      _socket?.destroy();
      _socket = await Socket.connect(host, port,
          timeout: const Duration(seconds: 6));
    } on SocketException catch (e) {
      throw PrinterException('Cannot reach $host:$port — ${e.message}');
    }
  }

  @override
  Future<bool> isReadyToConnect() async => true;

  @override
  Future<bool> isConnected() async => _socket != null;

  @override
  Future<void> send(List<int> bytes) async {
    final socket = _socket;
    if (socket == null) {
      // Reconnect on demand if we have a target.
      if (_device != null) {
        await connect(_device!);
      } else {
        throw PrinterException('Printer is not connected.');
      }
    }
    _socket!.add(bytes);
    await _socket!.flush();
  }

  @override
  Future<void> disconnect() async {
    await _socket?.flush();
    _socket?.destroy();
    _socket = null;
  }
}
