import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/enums.dart';
import '../../data/repositories.dart';
import '../../print/print_service.dart';
import '../../print/render/paper.dart';
import '../../print/render/rasterizer.dart';
import '../../widgets/ui.dart';

/// Printer configuration + live connection management: interface, language,
/// paper size, cut/drawer behaviour, print method and device discovery.
class PrinterSettingsScreen extends ConsumerWidget {
  const PrinterSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsValueProvider);
    final printer = ref.watch(printerControllerProvider);
    final controller = ref.read(printerControllerProvider.notifier);

    void update(void Function(dynamic s) mutate) {
      ref.read(settingsProvider.notifier).edit((s) {
        mutate(s);
        return s;
      });
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Printer')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          // ---- Connection ----
          SectionCard(
            title: 'Connection',
            icon: Icons.link,
            children: [
              _EnumChoice<PrinterInterface>(
                label: 'Interface',
                value: settings.printerInterface,
                values: PrinterInterface.values,
                labelOf: (v) => switch (v) {
                  PrinterInterface.bluetooth => 'Bluetooth',
                  PrinterInterface.usb => 'USB',
                  PrinterInterface.lan => 'LAN / WiFi',
                },
                onChanged: (v) => update((s) => s.printerInterface = v),
              ),
              const SizedBox(height: 8),
              _EnumChoice<PrinterLanguage>(
                label: 'Printer language',
                value: settings.printerLanguage,
                values: PrinterLanguage.values,
                labelOf: (v) => v.name.toUpperCase(),
                onChanged: (v) => update((s) => s.printerLanguage = v),
              ),
              if (settings.printerInterface == PrinterInterface.lan) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        initialValue: settings.lanHost,
                        decoration:
                            const InputDecoration(labelText: 'Host / IP'),
                        onChanged: (v) => update((s) => s.lanHost = v.trim()),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        initialValue: settings.lanPort.toString(),
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Port'),
                        onChanged: (v) =>
                            update((s) => s.lanPort = int.tryParse(v) ?? 9100),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Auto-connect to last printer'),
                value: settings.autoConnect,
                onChanged: (v) => update((s) => s.autoConnect = v),
              ),
              const Divider(),
              _ConnectionStatus(printer: printer),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed:
                          printer.scanning ? null : controller.refreshDevices,
                      icon: printer.scanning
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.search),
                      label: Text(settings.printerInterface ==
                              PrinterInterface.bluetooth
                          ? 'Scan paired'
                          : 'Find devices'),
                    ),
                  ),
                  if (printer.isConnected) ...[
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: controller.disconnect,
                      icon: const Icon(Icons.link_off),
                      label: const Text('Disconnect'),
                    ),
                  ],
                ],
              ),
              if (printer.devices.isNotEmpty) ...[
                const SizedBox(height: 8),
                ...printer.devices.map((d) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.print_outlined),
                      title: Text(d.name),
                      subtitle: Text(d.id),
                      trailing: printer.device?.id == d.id && printer.isConnected
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : const Icon(Icons.chevron_right),
                      onTap: () => controller.connect(d),
                    )),
              ],
              if (printer.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(printer.error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                ),
            ],
          ),

          // ---- Paper ----
          _PaperCard(settings: settings, update: update),

          // ---- Print behaviour ----
          SectionCard(
            title: 'Print behaviour',
            icon: Icons.tune,
            children: [
              _EnumChoice<PrintMethod>(
                label: 'Print command',
                value: settings.printMethod,
                values: PrintMethod.values,
                labelOf: (v) => v.label,
                onChanged: (v) => update((s) => s.printMethod = v),
              ),
              const SizedBox(height: 8),
              _EnumChoice<CutMode>(
                label: 'Cut mode',
                value: settings.cutMode,
                values: CutMode.values,
                labelOf: (v) => v.name,
                onChanged: (v) => update((s) => s.cutMode = v),
              ),
              const SizedBox(height: 12),
              _NumberField(
                label: 'Cut spacing (feed lines)',
                value: settings.cutSpacing,
                min: 0,
                max: 12,
                onChanged: (v) => update((s) => s.cutSpacing = v),
              ),
              _NumberField(
                label: 'Feed after print (lines)',
                value: settings.feedAfterPrint,
                min: 0,
                max: 12,
                onChanged: (v) => update((s) => s.feedAfterPrint = v),
              ),
              _NumberField(
                label: 'Copies',
                value: settings.copies,
                min: 1,
                max: 10,
                onChanged: (v) => update((s) => s.copies = v),
              ),
              _NumberField(
                label: 'Density',
                value: settings.density,
                min: 1,
                max: 15,
                onChanged: (v) => update((s) => s.density = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Open cash drawer after print'),
                value: settings.openCashDrawer,
                onChanged: (v) => update((s) => s.openCashDrawer = v),
              ),
              if (settings.openCashDrawer)
                _EnumChoiceInt(
                  label: 'Drawer pin',
                  value: settings.drawerPin,
                  values: const [0, 1],
                  labelOf: (v) => 'Pin ${v == 0 ? '2' : '5'}',
                  onChanged: (v) => update((s) => s.drawerPin = v),
                ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Beep after print'),
                value: settings.beep,
                onChanged: (v) => update((s) => s.beep = v),
              ),
            ],
          ),

          // ---- Test ----
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: FilledButton.tonalIcon(
              onPressed: () => _testPrint(context, ref),
              icon: const Icon(Icons.receipt_long_outlined),
              label: const Text('Test print'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _testPrint(BuildContext context, WidgetRef ref) async {
    final settings = ref.read(settingsValueProvider);
    final metrics = PaperMetrics.forWidth(settings.paperWidthMm);
    try {
      // Build a tiny test bitmap (a few black bars) without needing a widget.
      final bytesPerRow = (metrics.dots + 7) ~/ 8;
      const height = 80;
      final bits = Uint8List(bytesPerRow * height);
      for (var y = 10; y < 30; y++) {
        for (var b = 0; b < bytesPerRow; b++) {
          bits[y * bytesPerRow + b] = 0xFF;
        }
      }
      final mono = MonoBitmap(
        width: metrics.dots,
        height: height,
        bytesPerRow: bytesPerRow,
        bits: bits,
      );
      // Reuse the print pipeline.
      await ref.read(printerControllerProvider.notifier).printBitmap(mono);
      if (context.mounted) showSnack(context, 'Test sent to printer');
    } catch (e) {
      if (context.mounted) showSnack(context, 'Test failed: $e');
    }
  }
}

class _ConnectionStatus extends StatelessWidget {
  const _ConnectionStatus({required this.printer});
  final PrinterState printer;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    late final IconData icon;
    late final Color color;
    late final String label;
    switch (printer.status) {
      case PrinterConnState.connected:
        icon = Icons.check_circle;
        color = Colors.green;
        label = 'Connected to ${printer.device?.name ?? 'printer'}';
        break;
      case PrinterConnState.connecting:
        icon = Icons.sync;
        color = scheme.primary;
        label = 'Connecting…';
        break;
      case PrinterConnState.error:
        icon = Icons.error_outline;
        color = scheme.error;
        label = 'Connection error';
        break;
      case PrinterConnState.disconnected:
        icon = Icons.print_disabled;
        color = scheme.onSurfaceVariant;
        label = 'Not connected';
        break;
    }
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(label),
      ],
    );
  }
}

class _PaperCard extends StatelessWidget {
  const _PaperCard({required this.settings, required this.update});
  final dynamic settings;
  final void Function(void Function(dynamic)) update;

  @override
  Widget build(BuildContext context) {
    final presets = <double>[44, 58, 72, 80];
    final metrics = PaperMetrics.forWidth(settings.paperWidthMm);
    final isPreset = presets.contains(settings.paperWidthMm);
    return SectionCard(
      title: 'Paper',
      icon: Icons.straighten,
      subtitle: '${metrics.dots} printable dots · '
          '${metrics.widthInches.toStringAsFixed(2)} in',
      children: [
        Wrap(
          spacing: 8,
          children: [
            ...presets.map((mm) => ChoiceChip(
                  label: Text('${mm.toStringAsFixed(0)} mm'),
                  selected: settings.paperWidthMm == mm,
                  onSelected: (_) => update((s) => s.paperWidthMm = mm),
                )),
            ChoiceChip(
              label: const Text('Custom'),
              selected: !isPreset,
              onSelected: (_) => update((s) => s.paperWidthMm = 50),
            ),
          ],
        ),
        if (!isPreset) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue:
                      settings.paperWidthMm.toStringAsFixed(1),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Width (mm)'),
                  onChanged: (v) {
                    final mm = double.tryParse(v);
                    if (mm != null && mm > 20 && mm < 120) {
                      update((s) => s.paperWidthMm = mm);
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  key: ValueKey('in-${settings.paperWidthMm}'),
                  initialValue: mmToInches(settings.paperWidthMm)
                      .toStringAsFixed(2),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration:
                      const InputDecoration(labelText: 'Width (inches)'),
                  onChanged: (v) {
                    final inch = double.tryParse(v);
                    if (inch != null) {
                      final mm = inchesToMm(inch);
                      if (mm > 20 && mm < 120) {
                        update((s) => s.paperWidthMm = mm);
                      }
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _EnumChoice<T> extends StatelessWidget {
  const _EnumChoice({
    required this.label,
    required this.value,
    required this.values,
    required this.labelOf,
    required this.onChanged,
  });
  final String label;
  final T value;
  final List<T> values;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: values
              .map((v) => ChoiceChip(
                    label: Text(labelOf(v)),
                    selected: v == value,
                    onSelected: (_) => onChanged(v),
                  ))
              .toList(),
        ),
      ],
    );
  }
}

class _EnumChoiceInt extends StatelessWidget {
  const _EnumChoiceInt({
    required this.label,
    required this.value,
    required this.values,
    required this.labelOf,
    required this.onChanged,
  });
  final String label;
  final int value;
  final List<int> values;
  final String Function(int) labelOf;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(label),
          const Spacer(),
          ...values.map((v) => Padding(
                padding: const EdgeInsets.only(left: 8),
                child: ChoiceChip(
                  label: Text(labelOf(v)),
                  selected: v == value,
                  onSelected: (_) => onChanged(v),
                ),
              )),
        ],
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          IconButton(
            onPressed: value > min ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove_circle_outline),
          ),
          SizedBox(
            width: 28,
            child: Text('$value', textAlign: TextAlign.center),
          ),
          IconButton(
            onPressed: value < max ? () => onChanged(value + 1) : null,
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
    );
  }
}
