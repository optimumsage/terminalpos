import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/enums.dart';
import '../data/repositories.dart';
import '../models/app_settings.dart';
import 'builders/command_builder.dart';
import 'builders/cpcl_builder.dart';
import 'builders/escpos_builder.dart';
import 'builders/zpl_builder.dart';
import 'render/rasterizer.dart';
import 'transport/bluetooth_transport.dart';
import 'transport/lan_transport.dart';
import 'transport/printer_transport.dart';
import 'transport/usb_transport.dart';

enum PrinterConnState { disconnected, connecting, connected, error }

class PrinterState {
  const PrinterState({
    this.status = PrinterConnState.disconnected,
    this.device,
    this.error,
    this.devices = const [],
    this.scanning = false,
  });

  final PrinterConnState status;
  final PrinterDevice? device;
  final String? error;
  final List<PrinterDevice> devices;
  final bool scanning;

  bool get isConnected => status == PrinterConnState.connected;

  PrinterState copyWith({
    PrinterConnState? status,
    PrinterDevice? device,
    Object? error = _sentinel,
    List<PrinterDevice>? devices,
    bool? scanning,
  }) {
    return PrinterState(
      status: status ?? this.status,
      device: device ?? this.device,
      error: error == _sentinel ? this.error : error as String?,
      devices: devices ?? this.devices,
      scanning: scanning ?? this.scanning,
    );
  }

  static const _sentinel = Object();
}

/// Orchestrates: pick transport (by interface) + builder (by language), manage
/// connection/discovery, and print a captured [MonoBitmap]. This is the single
/// funnel every print path goes through.
class PrinterController extends Notifier<PrinterState> {
  PrinterTransport? _transport;
  PrinterInterface? _transportInterface;

  @override
  PrinterState build() => const PrinterState();

  AppSettings get _settings =>
      ref.read(settingsProvider).value ?? AppSettings();

  PrinterTransport _transportFor(AppSettings s) {
    if (_transport != null && _transportInterface == s.printerInterface) {
      return _transport!;
    }
    _transport?.disconnect();
    _transportInterface = s.printerInterface;
    switch (s.printerInterface) {
      case PrinterInterface.bluetooth:
        _transport = BluetoothTransport();
        break;
      case PrinterInterface.lan:
        _transport = LanTransport(manual: [
          PrinterDevice(
            id: '${s.lanHost}:${s.lanPort}',
            name: 'Network printer (${s.lanHost})',
            interface: PrinterInterface.lan,
          ),
        ]);
        break;
      case PrinterInterface.usb:
        _transport = UsbTransport();
        break;
    }
    return _transport!;
  }

  CommandBuilder _builderFor(PrinterLanguage language) {
    switch (language) {
      case PrinterLanguage.escpos:
        return const EscPosBuilder();
      case PrinterLanguage.zpl:
        return const ZplBuilder();
      case PrinterLanguage.cpcl:
        return const CpclBuilder();
    }
  }

  Future<void> refreshDevices() async {
    final s = _settings;
    state = state.copyWith(scanning: true, error: null);
    try {
      final devices = await _transportFor(s).discover();
      state = state.copyWith(devices: devices, scanning: false);
    } on Object catch (e) {
      state = state.copyWith(
          scanning: false,
          status: PrinterConnState.error,
          error: e.toString());
    }
  }

  Future<void> connect(PrinterDevice device) async {
    final s = _settings;
    state = state.copyWith(
        status: PrinterConnState.connecting, error: null, device: device);
    try {
      await _transportFor(s).connect(device);
      // Persist as last-used for auto-connect.
      await ref.read(settingsProvider.notifier).edit((x) => x
        ..lastDeviceId = device.id
        ..lastDeviceName = device.name);
      state =
          state.copyWith(status: PrinterConnState.connected, device: device);
    } on Object catch (e) {
      state = state.copyWith(
          status: PrinterConnState.error, error: e.toString());
    }
  }

  Future<void> disconnect() async {
    await _transport?.disconnect();
    state = state.copyWith(status: PrinterConnState.disconnected);
  }

  /// Ensures a connection exists, auto-connecting to the last-used device when
  /// enabled.
  Future<void> _ensureConnected() async {
    final s = _settings;
    final transport = _transportFor(s);
    if (await transport.isConnected()) return;

    PrinterDevice? target = state.device;
    if (target == null && s.autoConnect && s.lastDeviceId.isNotEmpty) {
      target = PrinterDevice(
        id: s.lastDeviceId,
        name: s.lastDeviceName.isEmpty ? s.lastDeviceId : s.lastDeviceName,
        interface: s.printerInterface,
      );
    }
    if (target == null) {
      throw PrinterException('No printer selected. Connect one in Settings.');
    }
    await transport.connect(target);
    state = state.copyWith(status: PrinterConnState.connected, device: target);
  }

  /// Builds bytes from the bitmap and sends the configured number of copies.
  Future<void> printBitmap(MonoBitmap bitmap) async {
    final s = _settings;
    await _ensureConnected();
    final builder = _builderFor(s.printerLanguage);
    final bytes = builder.build(bitmap, s);
    final copies = s.copies.clamp(1, 10);
    for (var i = 0; i < copies; i++) {
      await _transportFor(s).send(bytes);
    }
  }
}

final printerControllerProvider =
    NotifierProvider<PrinterController, PrinterState>(PrinterController.new);
