import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/repositories.dart';
import '../../models/custom_note.dart';
import '../../print/print_service.dart';
import '../../print/render/custom_document.dart';
import '../../print/render/paper.dart';
import '../../print/render/rasterizer.dart';
import '../../widgets/ui.dart';

/// Shows a custom note exactly as it will print (WYSIWYG) and prints it by
/// capturing the same rendered widget to a bitmap — reusing the invoice print
/// pipeline.
class NotePreviewScreen extends ConsumerStatefulWidget {
  const NotePreviewScreen({super.key, required this.noteId});
  final String noteId;

  @override
  ConsumerState<NotePreviewScreen> createState() => _NotePreviewScreenState();
}

class _NotePreviewScreenState extends ConsumerState<NotePreviewScreen> {
  final GlobalKey _boundaryKey = GlobalKey();
  CustomNote? _note;
  bool _loading = true;
  bool _printing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await ref.read(notesProvider.future);
    final note = ref.read(notesProvider.notifier).get(widget.noteId);
    if (!mounted) return;
    setState(() {
      _note = note;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final note = _note;
    if (note == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(
            icon: Icons.error_outline, title: 'Note not found'),
      );
    }

    final settings = ref.watch(settingsValueProvider);
    final metrics = PaperMetrics.forWidth(settings.paperWidthMm);
    final printerState = ref.watch(printerControllerProvider);
    final canPrint = !note.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Preview'),
        actions: [
          IconButton(
            tooltip: 'Printer settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings/printer'),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: _ConnectionPill(
                  connected: printerState.isConnected,
                  label: printerState.isConnected
                      ? (printerState.device?.name ?? 'Connected')
                      : 'Not connected',
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: (_printing || !canPrint) ? null : () => _print(note),
                icon: _printing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.print),
                label: Text(_printing ? 'Printing…' : 'Print'),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Text(
              '${settings.paperWidthMm.toStringAsFixed(0)} mm · ${metrics.dots} dots · '
              '${settings.printerLanguage.name.toUpperCase()} · '
              '${settings.printerInterface.name}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: Container(
              color: const Color(0xFFE9EAF0),
              width: double.infinity,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: metrics.dots.toDouble(),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Material(
                        elevation: 3,
                        color: Colors.white,
                        child: RepaintBoundary(
                          key: _boundaryKey,
                          child: CustomDocument(
                            note: note,
                            settings: settings,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _print(CustomNote note) async {
    setState(() => _printing = true);
    try {
      // Let the current frame settle before capturing (see invoice preview).
      await Future<void>.delayed(const Duration(milliseconds: 150));
      await WidgetsBinding.instance.endOfFrame;
      final boundary = _boundaryKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final mono = await captureBoundary(boundary);
      await ref.read(printerControllerProvider.notifier).printBitmap(mono);
      if (mounted) showSnack(context, 'Sent to printer');
    } catch (e) {
      if (mounted) {
        showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Print failed'),
            content: Text(e.toString()),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK')),
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.push('/settings/printer');
                },
                child: const Text('Printer settings'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }
}

class _ConnectionPill extends StatelessWidget {
  const _ConnectionPill({required this.connected, required this.label});
  final bool connected;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = connected ? Colors.green : scheme.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(connected ? Icons.bluetooth_connected : Icons.print_disabled,
              size: 18, color: color),
          const SizedBox(width: 8),
          Flexible(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
