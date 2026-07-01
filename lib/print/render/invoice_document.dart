import 'dart:io';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/calc.dart';
import '../../core/dynamic_fields.dart';
import '../../core/enums.dart';
import '../../models/app_settings.dart';
import '../../models/invoice.dart';
import '../../models/template.dart';
import 'paper.dart';

/// Renders an invoice exactly as it will print: black-on-white, sized to the
/// printable dot width. The SAME widget backs the on-screen preview and the
/// rasterizer, guaranteeing WYSIWYG. All layout is in dots (1 logical px = 1
/// printer dot) so capturing at pixelRatio 1 yields the exact bitmap.
class InvoiceDocument extends StatelessWidget {
  const InvoiceDocument({
    super.key,
    required this.invoice,
    required this.template,
    required this.settings,
  });

  final Invoice invoice;
  final InvoiceTemplate template;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final metrics = PaperMetrics.forWidth(settings.paperWidthMm);
    final totals = const InvoiceCalculator().compute(invoice);
    final base = 22.0 * template.fontScale;
    final crossAlign = template.alignment == TemplateAlignment.center
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.start;

    final sections = <Widget>[];
    for (final config in template.sections) {
      if (!config.enabled) continue;
      final widget = _buildSection(config.section, base, totals, metrics);
      if (widget != null) sections.add(widget);
    }

    return Container(
      width: metrics.dots.toDouble(),
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: DefaultTextStyle(
        style: TextStyle(
          color: Colors.black,
          fontSize: base,
          height: 1.25,
          fontFamily: 'monospace',
        ),
        child: Column(
          crossAxisAlignment: crossAlign,
          mainAxisSize: MainAxisSize.min,
          children: _withSpacing(sections),
        ),
      ),
    );
  }

  List<Widget> _withSpacing(List<Widget> children) {
    final out = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      out.add(children[i]);
      if (i != children.length - 1) out.add(const SizedBox(height: 10));
    }
    return out;
  }

  Widget? _buildSection(
    TemplateSection section,
    double base,
    InvoiceTotals totals,
    PaperMetrics metrics,
  ) {
    switch (section) {
      case TemplateSection.logo:
        return _logo(metrics);
      case TemplateSection.business:
        return _business(base);
      case TemplateSection.meta:
        return _meta(base);
      case TemplateSection.billTo:
        return _billTo(base);
      case TemplateSection.items:
        return _items(base, totals);
      case TemplateSection.totals:
        return _totals(base, totals);
      case TemplateSection.notes:
        return _notes(base);
      case TemplateSection.footer:
        return _footer(base);
      case TemplateSection.qr:
        return _qr(metrics);
    }
  }

  bool get _centered => template.alignment == TemplateAlignment.center;
  TextAlign get _textAlign => _centered ? TextAlign.center : TextAlign.left;

  Widget? _logo(PaperMetrics metrics) {
    if (settings.logoPath.isEmpty) return null;
    final file = File(settings.logoPath);
    if (!file.existsSync()) return null;
    return Align(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: metrics.dots * 0.7,
          maxHeight: metrics.dots * 0.45,
        ),
        child: Image.file(file, fit: BoxFit.contain, filterQuality: FilterQuality.medium),
      ),
    );
  }

  Widget? _business(double base) {
    final lines = <Widget>[
      if (settings.showBusinessName)
        Text(
          settings.businessName,
          textAlign: _textAlign,
          style: TextStyle(
            fontSize: base * 1.4,
            fontWeight: FontWeight.w900,
            color: Colors.black,
          ),
        ),
    ];
    for (final line in [
      settings.businessAddress,
      settings.businessPhone,
      settings.businessEmail,
      settings.businessWebsite,
      if (settings.businessTaxId.isNotEmpty) 'Tax ID: ${settings.businessTaxId}',
    ]) {
      if (line.trim().isEmpty) continue;
      lines.add(Text(line, textAlign: _textAlign));
    }
    if (lines.isEmpty) return null;
    return Column(
      crossAxisAlignment:
          _centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: lines,
    );
  }

  Widget _meta(double base) {
    final now = invoice.issuedAt;
    final date = dateFormatById(settings.dateFormatId).format(now);
    final time = timeFormatById(settings.timeFormatId).format(now);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _dividerLine(),
        _kv('Invoice #', invoice.number.isEmpty ? invoice.name : invoice.number,
            base, bold: true),
        _kv('Date', date, base),
        _kv('Time', time, base),
        _dividerLine(),
      ],
    );
  }

  Widget? _billTo(double base) {
    if (invoice.billToName.isEmpty &&
        invoice.billToPhone.isEmpty &&
        invoice.billToAddress.isEmpty) {
      return null;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('BILL TO', style: TextStyle(fontWeight: FontWeight.w800)),
        if (invoice.billToName.isNotEmpty) Text(invoice.billToName),
        if (invoice.billToPhone.isNotEmpty) Text(invoice.billToPhone),
        if (invoice.billToAddress.isNotEmpty) Text(invoice.billToAddress),
      ],
    );
  }

  Widget _items(double base, InvoiceTotals totals) {
    final money = settings.money;
    final rows = <Widget>[
      Row(
        children: [
          Expanded(
            child: Text('ITEM',
                style: TextStyle(fontWeight: FontWeight.w800)),
          ),
          Text('AMOUNT', style: TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
      _dashLine(),
    ];

    for (final item in invoice.items) {
      final qty = money.formatQuantity(item.quantity);
      final price = money.formatNumber(item.unitPrice);
      rows.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.name,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$qty x $price'
                    '${item.discount > 0 ? '  (-${money.formatNumber(item.discount)})' : ''}',
                    style: TextStyle(fontSize: base * 0.9),
                  ),
                ),
                Text(money.formatNumber(item.net)),
              ],
            ),
          ],
        ),
      ));
    }
    rows.add(_dashLine());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }

  Widget _totals(double base, InvoiceTotals totals) {
    final money = settings.money;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _kv('Subtotal', money.format(totals.subtotal), base),
        if (totals.invoiceDiscount > 0)
          _kv('Discount', '-${money.format(totals.invoiceDiscount)}', base),
        if (invoice.taxEnabled && totals.tax > 0)
          _kv('${settings.taxLabel} (${invoice.taxRate.toStringAsFixed(invoice.taxRate.truncateToDouble() == invoice.taxRate ? 0 : 2)}%)',
              money.format(totals.tax), base),
        const SizedBox(height: 4),
        _dividerLine(),
        _kv('TOTAL', money.format(totals.grandTotal), base * 1.25,
            bold: true),
        _dividerLine(),
      ],
    );
  }

  Widget? _notes(double base) {
    if (invoice.notes.trim().isEmpty) return null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Notes', style: TextStyle(fontWeight: FontWeight.w800)),
        Text(invoice.notes),
      ],
    );
  }

  Widget? _footer(double base) {
    if (template.footerText.trim().isEmpty && template.headerText.trim().isEmpty) {
      return null;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (template.footerText.trim().isNotEmpty)
          Align(
            alignment: Alignment.center,
            child: Text(template.footerText,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
      ],
    );
  }

  Widget _qr(PaperMetrics metrics) {
    final data = invoice.number.isEmpty ? invoice.name : invoice.number;
    return Align(
      alignment: Alignment.center,
      child: QrImageView(
        data: data,
        version: QrVersions.auto,
        size: metrics.dots * 0.4,
        backgroundColor: Colors.white,
        // ignore: deprecated_member_use
        foregroundColor: Colors.black,
      ),
    );
  }

  // ---- small helpers ----
  Widget _kv(String label, String value, double size, {bool bold = false}) {
    final style = TextStyle(
      fontSize: size,
      fontWeight: bold ? FontWeight.w900 : FontWeight.w400,
      color: Colors.black,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }

  Widget _dividerLine() => Container(
        height: 2,
        color: Colors.black,
        margin: const EdgeInsets.symmetric(vertical: 4),
      );

  Widget _dashLine() => const Padding(
        padding: EdgeInsets.symmetric(vertical: 2),
        child: Text(
          '--------------------------------',
          maxLines: 1,
          overflow: TextOverflow.clip,
          style: TextStyle(color: Colors.black, fontFamily: 'monospace'),
        ),
      );
}
