import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/calc.dart';
import '../../core/enums.dart';
import '../../data/repositories.dart';
import '../../models/invoice.dart';
import '../../models/product.dart';
import '../../widgets/ui.dart';
import 'item_editor_sheet.dart';

/// Full invoice editor. Holds a local editable copy loaded from the repository
/// and autosaves on every change so nothing is lost.
class InvoiceEditorScreen extends ConsumerStatefulWidget {
  const InvoiceEditorScreen({super.key, required this.invoiceId});
  final String invoiceId;

  @override
  ConsumerState<InvoiceEditorScreen> createState() =>
      _InvoiceEditorScreenState();
}

class _InvoiceEditorScreenState extends ConsumerState<InvoiceEditorScreen> {
  Invoice? _invoice;
  bool _loading = true;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _notesCtrl;
  late final TextEditingController _billNameCtrl;
  late final TextEditingController _billPhoneCtrl;
  late final TextEditingController _billAddrCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _notesCtrl = TextEditingController();
    _billNameCtrl = TextEditingController();
    _billPhoneCtrl = TextEditingController();
    _billAddrCtrl = TextEditingController();
    _load();
  }

  Future<void> _load() async {
    final invoice = await ref.read(invoiceRepositoryProvider).get(widget.invoiceId);
    if (invoice != null) {
      _nameCtrl.text = invoice.name;
      _notesCtrl.text = invoice.notes;
      _billNameCtrl.text = invoice.billToName;
      _billPhoneCtrl.text = invoice.billToPhone;
      _billAddrCtrl.text = invoice.billToAddress;
    }
    setState(() {
      _invoice = invoice;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _notesCtrl.dispose();
    _billNameCtrl.dispose();
    _billPhoneCtrl.dispose();
    _billAddrCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final invoice = _invoice;
    if (invoice == null) return;
    invoice
      ..name = _nameCtrl.text.trim().isEmpty ? invoice.name : _nameCtrl.text
      ..notes = _notesCtrl.text
      ..billToName = _billNameCtrl.text
      ..billToPhone = _billPhoneCtrl.text
      ..billToAddress = _billAddrCtrl.text;
    ref.read(invoiceRepositoryProvider).save(invoice);
    setState(() {});
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
    final money = settings.money;
    final totals = const InvoiceCalculator().compute(invoice);
    final templates = ref.watch(templatesStreamProvider).value ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Invoice'),
        actions: [
          IconButton(
            tooltip: 'Preview & Print',
            icon: const Icon(Icons.print_outlined),
            onPressed: () {
              _save();
              context.push('/invoice/${invoice.id}/preview');
            },
          ),
        ],
      ),
      bottomNavigationBar: _TotalBar(
        total: money.format(totals.grandTotal),
        onPreview: () {
          _save();
          context.push('/invoice/${invoice.id}/preview');
        },
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          SectionCard(
            title: 'Details',
            icon: Icons.description_outlined,
            children: [
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Invoice name'),
                onChanged: (_) => _save(),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: templates.any((t) => t.id == invoice.templateId)
                    ? invoice.templateId
                    : (templates.isEmpty ? null : templates.first.id),
                decoration: const InputDecoration(labelText: 'Template'),
                items: templates
                    .map((t) => DropdownMenuItem(
                        value: t.id, child: Text(t.name)))
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  invoice.templateId = v;
                  _save();
                },
              ),
            ],
          ),
          SectionCard(
            title: 'Bill to',
            icon: Icons.person_outline,
            subtitle: 'Optional customer details',
            children: [
              TextField(
                controller: _billNameCtrl,
                decoration: const InputDecoration(labelText: 'Name'),
                onChanged: (_) => _save(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _billPhoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone'),
                onChanged: (_) => _save(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _billAddrCtrl,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Address'),
                onChanged: (_) => _save(),
              ),
            ],
          ),
          _ItemsCard(
            invoice: invoice,
            onAdd: _addItem,
            onEdit: _editItem,
            onDelete: (item) {
              invoice.items.remove(item);
              _save();
            },
          ),
          _TotalsCard(invoice: invoice, onChanged: () => _save()),
          SectionCard(
            title: 'Notes',
            icon: Icons.sticky_note_2_outlined,
            children: [
              TextField(
                controller: _notesCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                    hintText: 'Notes shown on the receipt'),
                onChanged: (_) => _save(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _addItem() async {
    final products = ref.read(productsStreamProvider).value ?? [];
    final action = await showModalBottomSheet<_AddChoice>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _AddItemSheet(products: products),
    );
    if (action == null || _invoice == null || !mounted) return;

    if (action.custom) {
      final item = await showItemEditor(
        context,
        InvoiceItem(id: newId(), name: '', quantity: 1, unitPrice: 0),
        ref.read(settingsValueProvider),
      );
      if (item != null) {
        _invoice!.items.add(item);
        _save();
      }
    } else if (action.product != null) {
      final p = action.product!;
      _invoice!.items.add(InvoiceItem(
        id: newId(),
        name: p.name,
        quantity: 1,
        unitPrice: p.price,
        productId: p.id,
      ));
      _save();
    }
  }

  Future<void> _editItem(InvoiceItem item) async {
    final edited =
        await showItemEditor(context, item, ref.read(settingsValueProvider));
    if (edited != null) {
      final index = _invoice!.items.indexWhere((i) => i.id == item.id);
      if (index >= 0) _invoice!.items[index] = edited;
      _save();
    }
  }
}

class _AddChoice {
  _AddChoice({this.product, this.custom = false});
  final Product? product;
  final bool custom;
}

class _AddItemSheet extends StatelessWidget {
  const _AddItemSheet({required this.products});
  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Add item',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          ),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Custom item'),
            subtitle: const Text('Type a one-off line'),
            onTap: () => Navigator.pop(context, _AddChoice(custom: true)),
          ),
          if (products.isNotEmpty) const Divider(),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: products
                  .map((p) => ListTile(
                        leading: const Icon(Icons.inventory_2_outlined),
                        title: Text(p.name),
                        subtitle: p.sku.isEmpty ? null : Text(p.sku),
                        onTap: () =>
                            Navigator.pop(context, _AddChoice(product: p)),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _ItemsCard extends ConsumerWidget {
  const _ItemsCard({
    required this.invoice,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });
  final Invoice invoice;
  final VoidCallback onAdd;
  final void Function(InvoiceItem) onEdit;
  final void Function(InvoiceItem) onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final money = ref.watch(settingsValueProvider).money;
    return SectionCard(
      title: 'Items',
      icon: Icons.shopping_cart_outlined,
      children: [
        if (invoice.items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text('No items yet',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          )
        else
          ...invoice.items.map((item) => Dismissible(
                key: ValueKey(item.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: const Icon(Icons.delete_outline),
                ),
                onDismissed: (_) => onDelete(item),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.name.isEmpty ? '(unnamed)' : item.name),
                  subtitle: Text(
                      '${money.formatQuantity(item.quantity)} × ${money.format(item.unitPrice)}'
                      '${item.discount > 0 ? '  −${money.format(item.discount)}' : ''}'),
                  trailing: Text(money.format(item.net),
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () => onEdit(item),
                ),
              )),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Add item'),
          ),
        ),
      ],
    );
  }
}

class _TotalsCard extends ConsumerWidget {
  const _TotalsCard({required this.invoice, required this.onChanged});
  final Invoice invoice;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsValueProvider);
    final money = settings.money;
    final totals = const InvoiceCalculator().compute(invoice);

    return SectionCard(
      title: 'Discounts & totals',
      icon: Icons.calculate_outlined,
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<DiscountKind>(
                initialValue: invoice.discountKind,
                decoration:
                    const InputDecoration(labelText: 'Invoice discount'),
                items: const [
                  DropdownMenuItem(
                      value: DiscountKind.none, child: Text('None')),
                  DropdownMenuItem(
                      value: DiscountKind.percent, child: Text('Percent %')),
                  DropdownMenuItem(
                      value: DiscountKind.fixed, child: Text('Fixed amount')),
                ],
                onChanged: (v) {
                  invoice.discountKind = v ?? DiscountKind.none;
                  onChanged();
                },
              ),
            ),
            if (invoice.discountKind != DiscountKind.none) ...[
              const SizedBox(width: 12),
              SizedBox(
                width: 110,
                child: TextFormField(
                  initialValue: invoice.discountValue == 0
                      ? ''
                      : invoice.discountValue.toString(),
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  decoration: const InputDecoration(labelText: 'Value'),
                  onChanged: (v) {
                    invoice.discountValue = double.tryParse(v) ?? 0;
                    onChanged();
                  },
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('Apply ${settings.taxLabel.toLowerCase()}'),
          value: invoice.taxEnabled,
          onChanged: (v) {
            invoice.taxEnabled = v;
            if (v && invoice.taxRate == 0) {
              invoice.taxRate = settings.taxRateDefault;
            }
            onChanged();
          },
        ),
        if (invoice.taxEnabled)
          TextFormField(
            initialValue:
                invoice.taxRate == 0 ? '' : invoice.taxRate.toString(),
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
                labelText: '${settings.taxLabel} rate (%)'),
            onChanged: (v) {
              invoice.taxRate = double.tryParse(v) ?? 0;
              onChanged();
            },
          ),
        const Divider(height: 24),
        LabeledRow('Subtotal', money.format(totals.subtotal)),
        if (totals.invoiceDiscount > 0)
          LabeledRow('Discount', '−${money.format(totals.invoiceDiscount)}'),
        if (invoice.taxEnabled && totals.tax > 0)
          LabeledRow(settings.taxLabel, money.format(totals.tax)),
        const SizedBox(height: 4),
        LabeledRow('Total', money.format(totals.grandTotal), emphasize: true),
      ],
    );
  }
}

class _TotalBar extends StatelessWidget {
  const _TotalBar({required this.total, required this.onPreview});
  final String total;
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border(top: BorderSide(color: scheme.outlineVariant)),
        ),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Total',
                    style: Theme.of(context).textTheme.bodySmall),
                Text(total,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: onPreview,
              icon: const Icon(Icons.visibility_outlined),
              label: const Text('Preview & Print'),
            ),
          ],
        ),
      ),
    );
  }
}
