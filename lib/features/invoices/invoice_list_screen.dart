import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/calc.dart';
import '../../core/dynamic_fields.dart';
import '../../core/enums.dart';
import '../../data/repositories.dart';
import '../../models/invoice.dart';
import '../../models/template.dart';
import '../../widgets/ui.dart';

/// Home screen: searchable list of all invoices with a prominent New Invoice
/// action. Entry point to products, templates and settings.
class InvoiceListScreen extends ConsumerStatefulWidget {
  const InvoiceListScreen({super.key});

  @override
  ConsumerState<InvoiceListScreen> createState() => _InvoiceListScreenState();
}

class _InvoiceListScreenState extends ConsumerState<InvoiceListScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final invoicesAsync = ref.watch(invoicesStreamProvider);
    final settings = ref.watch(settingsValueProvider);
    final money = settings.money;
    const calc = InvoiceCalculator();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoices'),
        actions: [
          IconButton(
            tooltip: 'Products',
            icon: const Icon(Icons.inventory_2_outlined),
            onPressed: () => context.push('/products'),
          ),
          IconButton(
            tooltip: 'Templates',
            icon: const Icon(Icons.dashboard_customize_outlined),
            onPressed: () => context.push('/templates'),
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createInvoice,
        icon: const Icon(Icons.add),
        label: const Text('New Invoice'),
      ),
      body: invoicesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (invoices) {
          final filtered = _query.isEmpty
              ? invoices
              : invoices
                  .where((i) =>
                      i.name.toLowerCase().contains(_query.toLowerCase()) ||
                      i.number.toLowerCase().contains(_query.toLowerCase()) ||
                      i.billToName
                          .toLowerCase()
                          .contains(_query.toLowerCase()))
                  .toList();

          if (invoices.isEmpty) {
            return EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'No invoices yet',
              message: 'Create your first invoice to get started.',
              action: FilledButton.icon(
                onPressed: _createInvoice,
                icon: const Icon(Icons.add),
                label: const Text('New Invoice'),
              ),
            );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search invoices',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final invoice = filtered[index];
                    final totals = calc.compute(invoice);
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 6),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        title: Text(invoice.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600)),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${invoice.number.isEmpty ? '—' : invoice.number} · '
                                '${dateFormatById(settings.dateFormatId).format(invoice.createdAt)}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  _StatusChip(status: invoice.status),
                                  const SizedBox(width: 8),
                                  Text('${totals.itemCount} item(s)',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall),
                                ],
                              ),
                            ],
                          ),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(money.format(totals.grandTotal),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            _RowMenu(
                              onClone: () => _clone(invoice),
                              onPreview: () =>
                                  context.push('/invoice/${invoice.id}/preview'),
                              onDelete: () => _delete(invoice),
                            ),
                          ],
                        ),
                        onTap: () => context.push('/invoice/${invoice.id}'),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _createInvoice() async {
    final templates = ref.read(templatesStreamProvider).value ?? [];
    final chosen = await _pickTemplate(templates);
    if (chosen == null) return;

    final settings = ref.read(settingsValueProvider);
    final number = await ref.read(settingsProvider.notifier).consumeInvoiceNumber();
    final now = DateTime.now();
    final invoice = Invoice(
      id: newId(),
      name: defaultInvoiceName(now),
      number: settings.formatInvoiceNumber(number),
      templateId: chosen.id,
      createdAt: now,
      updatedAt: now,
      taxEnabled: settings.taxEnabledDefault,
      taxRate: settings.taxRateDefault,
    );
    await ref.read(invoiceRepositoryProvider).save(invoice);
    if (mounted) context.push('/invoice/${invoice.id}');
  }

  Future<InvoiceTemplate?> _pickTemplate(List<InvoiceTemplate> templates) async {
    if (templates.isEmpty) return null;
    if (templates.length == 1) return templates.first;
    if (!mounted) return null;
    return showModalBottomSheet<InvoiceTemplate>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Choose a template',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            ),
            ...templates.map((t) => ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: Text(t.name),
                  subtitle: Text(
                      '${t.sections.where((s) => s.enabled).length} sections'),
                  onTap: () => Navigator.pop(context, t),
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _clone(Invoice invoice) async {
    final repo = ref.read(invoiceRepositoryProvider);
    final copy = repo.cloneOf(invoice, name: '${invoice.name} (copy)');
    await repo.save(copy);
    if (mounted) showSnack(context, 'Invoice cloned');
  }

  Future<void> _delete(Invoice invoice) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete invoice?'),
        content: Text('“${invoice.name}” will be permanently removed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(invoiceRepositoryProvider).delete(invoice.id);
      if (mounted) showSnack(context, 'Invoice deleted');
    }
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final InvoiceStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    late final Color bg;
    late final Color fg;
    late final String label;
    switch (status) {
      case InvoiceStatus.draft:
        bg = scheme.surfaceContainerHighest;
        fg = scheme.onSurfaceVariant;
        label = 'Draft';
        break;
      case InvoiceStatus.finalized:
        bg = scheme.secondaryContainer;
        fg = scheme.onSecondaryContainer;
        label = 'Finalized';
        break;
      case InvoiceStatus.printed:
        bg = scheme.primaryContainer;
        fg = scheme.onPrimaryContainer;
        label = 'Printed';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(label,
          style: TextStyle(
              color: fg, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

class _RowMenu extends StatelessWidget {
  const _RowMenu({
    required this.onClone,
    required this.onPreview,
    required this.onDelete,
  });
  final VoidCallback onClone;
  final VoidCallback onPreview;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_horiz, size: 20),
      padding: EdgeInsets.zero,
      onSelected: (v) {
        switch (v) {
          case 'clone':
            onClone();
            break;
          case 'preview':
            onPreview();
            break;
          case 'delete':
            onDelete();
            break;
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
            value: 'preview',
            child: ListTile(
                leading: Icon(Icons.visibility_outlined),
                title: Text('Preview / Print'))),
        PopupMenuItem(
            value: 'clone',
            child: ListTile(
                leading: Icon(Icons.copy_outlined), title: Text('Clone'))),
        PopupMenuItem(
            value: 'delete',
            child: ListTile(
                leading: Icon(Icons.delete_outline), title: Text('Delete'))),
      ],
    );
  }
}
