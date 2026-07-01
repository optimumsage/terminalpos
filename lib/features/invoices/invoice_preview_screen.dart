import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/enums.dart';
import '../../data/repositories.dart';
import '../../models/invoice.dart';
import '../../models/template.dart';
import '../../print/print_service.dart';
import '../../print/render/invoice_document.dart';
import '../../print/render/paper.dart';
import '../../print/render/rasterizer.dart';
import '../../widgets/ui.dart';

/// Shows the invoice exactly as it will print (WYSIWYG) and prints it by
/// capturing the same rendered widget to a bitmap.
class InvoicePreviewScreen extends ConsumerStatefulWidget {
  const InvoicePreviewScreen({super.key, required this.invoiceId});
  final String invoiceId;

  @override
  ConsumerState<InvoicePreviewScreen> createState() =>
      _InvoicePreviewScreenState();
}

class _InvoicePreviewScreenState extends ConsumerState<InvoicePreviewScreen> {
  final GlobalKey _boundaryKey = GlobalKey();
  Invoice? _invoice;
  bool _loading = true;
  bool _printing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final invoice =
        await ref.read(invoiceRepositoryProvider).get(widget.invoiceId);
    setState(() {
      _invoice = invoice;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final invoice = _invoice;
    if (invoice == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(
            icon: Icons.error_outline, title: 'Invoice not found'),
      );
    }

    final settings = ref.watch(settingsValueProvider);
    final templates = ref.watch(templatesStreamProvider).value ?? [];
    final template = templates.firstWhere(
      (t) => t.id == invoice.templateId,
      orElse: () =>
          templates.isNotEmpty ? templates.first : presetTemplates().first,
    );
    final metrics = PaperMetrics.forWidth(settings.paperWidthMm);
    final printerState = ref.watch(printerControllerProvider);

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
                onPressed: _printing ? null : () => _print(invoice),
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
                          child: InvoiceDocument(
                            invoice: invoice,
                            template: template,
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

  Future<void> _print(Invoice invoice) async {
    setState(() => _printing = true);
    try {
      // Let the current frame (and logo image) settle before capturing.
      // Let the logo image decode and the current frame finish painting before
      // capturing. Note: do NOT use RenderObject.debugNeedsPaint here — it is a
      // debug-only getter whose value is computed inside an assert, so in
      // release builds it throws "LateInitializationError: Local 'result'".
      await Future<void>.delayed(const Duration(milliseconds: 150));
      await WidgetsBinding.instance.endOfFrame;
      final boundary = _boundaryKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final mono = await captureBoundary(boundary);
      await ref.read(printerControllerProvider.notifier).printBitmap(mono);

      invoice.status = InvoiceStatus.printed;
      await ref.read(invoiceRepositoryProvider).save(invoice);
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
