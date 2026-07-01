import 'package:flutter/material.dart';

import '../../core/enums.dart';
import '../../models/app_settings.dart';
import '../../models/invoice.dart';

/// Modal editor for a single invoice line. Returns the edited item, or null if
/// cancelled. Works for both new (empty name) and existing items.
Future<InvoiceItem?> showItemEditor(
  BuildContext context,
  InvoiceItem source,
  AppSettings settings,
) {
  return showModalBottomSheet<InvoiceItem>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: _ItemEditor(source: source, settings: settings),
    ),
  );
}

class _ItemEditor extends StatefulWidget {
  const _ItemEditor({required this.source, required this.settings});
  final InvoiceItem source;
  final AppSettings settings;

  @override
  State<_ItemEditor> createState() => _ItemEditorState();
}

class _ItemEditorState extends State<_ItemEditor> {
  late final TextEditingController _name;
  late final TextEditingController _qty;
  late final TextEditingController _price;
  late final TextEditingController _discount;
  late DiscountKind _discountKind;

  @override
  void initState() {
    super.initState();
    final s = widget.source;
    _name = TextEditingController(text: s.name);
    _qty = TextEditingController(text: _fmt(s.quantity));
    _price = TextEditingController(text: _fmt(s.unitPrice));
    _discount =
        TextEditingController(text: s.discountValue == 0 ? '' : _fmt(s.discountValue));
    _discountKind = s.discountKind;
  }

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  @override
  void dispose() {
    _name.dispose();
    _qty.dispose();
    _price.dispose();
    _discount.dispose();
    super.dispose();
  }

  void _submit() {
    final item = widget.source.copyWith(
      name: _name.text.trim(),
      quantity: double.tryParse(_qty.text) ?? 1,
      unitPrice: double.tryParse(_price.text) ?? 0,
      discountKind: _discountKind,
      discountValue: double.tryParse(_discount.text) ?? 0,
    );
    Navigator.pop(context, item);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.source.name.isEmpty ? 'New item' : 'Edit item',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            autofocus: widget.source.name.isEmpty,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _qty,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Quantity'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _price,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                      labelText: 'Unit price',
                      prefixText: '${widget.settings.currencySymbol} '),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<DiscountKind>(
                  initialValue: _discountKind,
                  decoration: const InputDecoration(labelText: 'Discount'),
                  items: const [
                    DropdownMenuItem(
                        value: DiscountKind.none, child: Text('None')),
                    DropdownMenuItem(
                        value: DiscountKind.percent, child: Text('Percent %')),
                    DropdownMenuItem(
                        value: DiscountKind.fixed, child: Text('Fixed')),
                  ],
                  onChanged: (v) =>
                      setState(() => _discountKind = v ?? DiscountKind.none),
                ),
              ),
              if (_discountKind != DiscountKind.none) ...[
                const SizedBox(width: 12),
                SizedBox(
                  width: 110,
                  child: TextField(
                    controller: _discount,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Value'),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          _LinePreview(
            settings: widget.settings,
            qty: double.tryParse(_qty.text) ?? 0,
            price: double.tryParse(_price.text) ?? 0,
            kind: _discountKind,
            discount: double.tryParse(_discount.text) ?? 0,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _submit,
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}

class _LinePreview extends StatelessWidget {
  const _LinePreview({
    required this.settings,
    required this.qty,
    required this.price,
    required this.kind,
    required this.discount,
  });
  final AppSettings settings;
  final double qty;
  final double price;
  final DiscountKind kind;
  final double discount;

  @override
  Widget build(BuildContext context) {
    final gross = qty * price;
    double disc;
    switch (kind) {
      case DiscountKind.none:
        disc = 0;
        break;
      case DiscountKind.percent:
        disc = gross * discount / 100;
        break;
      case DiscountKind.fixed:
        disc = discount;
        break;
    }
    final net = (gross - disc).clamp(0, double.infinity);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Line total',
            style: Theme.of(context).textTheme.bodyMedium),
        Text(settings.money.format(net),
            style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }
}
