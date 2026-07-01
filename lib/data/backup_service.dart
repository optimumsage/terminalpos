import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/calc.dart';
import '../models/app_settings.dart';
import '../models/invoice.dart';
import '../models/product.dart';
import '../models/template.dart';
import 'app_database.dart';
import 'repositories.dart';

/// Full-data backup: export/import everything as a single JSON document and
/// produce CSV summaries. Files are written to the app documents directory and
/// the JSON is also offered via clipboard, avoiding any native file-picker
/// dependency while still letting users move data between installs.
class BackupService {
  BackupService(this._db, this._ref);
  final AppDatabase _db;
  final Ref _ref;

  static const _formatVersion = 1;

  Future<Map<String, dynamic>> _collect() async {
    final invoices = await _db.allInvoices();
    final products = await _db.allProducts();
    final templates = await _db.allTemplates();
    final settings = _ref.read(settingsProvider).value ?? AppSettings();
    return {
      'formatVersion': _formatVersion,
      'settings': settings.toJson(),
      'templates':
          templates.map((r) => jsonDecode(r.data)).toList(growable: false),
      'products':
          products.map((r) => jsonDecode(r.data)).toList(growable: false),
      'invoices':
          invoices.map((r) => jsonDecode(r.data)).toList(growable: false),
    };
  }

  /// Returns the pretty-printed JSON backup string.
  Future<String> exportJsonString() async {
    final data = await _collect();
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// Writes the JSON backup to a timestamped file and returns its path.
  Future<String> exportJsonFile(DateTime now) async {
    final json = await exportJsonString();
    final dir = await getApplicationDocumentsDirectory();
    final stamp = now
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;
    final file = File(p.join(dir.path, 'terminalpos-backup-$stamp.json'));
    await file.writeAsString(json);
    return file.path;
  }

  /// Merges a JSON backup into the database (upsert by id). Returns a summary.
  Future<ImportResult> importJsonString(String raw) async {
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final now = DateTime.now();
    var templates = 0, products = 0, invoices = 0;

    for (final t in (data['templates'] as List<dynamic>? ?? [])) {
      final tpl = InvoiceTemplate.fromJson(t as Map<String, dynamic>);
      await _db.upsertTemplate(tpl.id, jsonEncode(tpl.toJson()), now);
      templates++;
    }
    for (final pr in (data['products'] as List<dynamic>? ?? [])) {
      final prod = Product.fromJson(pr as Map<String, dynamic>);
      await _db.upsertProduct(prod.id, jsonEncode(prod.toJson()), prod.createdAt);
      products++;
    }
    for (final inv in (data['invoices'] as List<dynamic>? ?? [])) {
      final invoice = Invoice.fromJson(inv as Map<String, dynamic>);
      await _db.upsertInvoice(
          invoice.id, jsonEncode(invoice.toJson()), invoice.updatedAt);
      invoices++;
    }
    if (data['settings'] is Map<String, dynamic>) {
      await _ref.read(settingsProvider.notifier).edit(
            (_) => AppSettings.fromJson(data['settings'] as Map<String, dynamic>),
          );
    }
    return ImportResult(
        templates: templates, products: products, invoices: invoices);
  }

  /// CSV of all invoices (one row per invoice, totals computed).
  Future<String> exportInvoicesCsv() async {
    final rows = await _db.allInvoices();
    final settings = _ref.read(settingsProvider).value ?? AppSettings();
    const calc = InvoiceCalculator();
    final sb = StringBuffer(
        'Number,Name,Date,Items,Subtotal,Discount,Tax,Total,Currency\n');
    for (final r in rows) {
      final inv = Invoice.fromJson(jsonDecode(r.data) as Map<String, dynamic>);
      final t = calc.compute(inv);
      sb.writeln([
        _csv(inv.number),
        _csv(inv.name),
        _csv(inv.createdAt.toIso8601String()),
        t.itemCount,
        t.subtotal.toStringAsFixed(settings.decimalPlaces),
        t.invoiceDiscount.toStringAsFixed(settings.decimalPlaces),
        t.tax.toStringAsFixed(settings.decimalPlaces),
        t.grandTotal.toStringAsFixed(settings.decimalPlaces),
        _csv(settings.currencyCode),
      ].join(','));
    }
    return sb.toString();
  }

  Future<String> exportProductsCsv() async {
    final rows = await _db.allProducts();
    final settings = _ref.read(settingsProvider).value ?? AppSettings();
    final sb = StringBuffer('Name,SKU,Unit,Price\n');
    for (final r in rows) {
      final prod = Product.fromJson(jsonDecode(r.data) as Map<String, dynamic>);
      sb.writeln([
        _csv(prod.name),
        _csv(prod.sku),
        _csv(prod.unit),
        prod.price.toStringAsFixed(settings.decimalPlaces),
      ].join(','));
    }
    return sb.toString();
  }

  Future<String> writeTextFile(String name, String content) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, name));
    await file.writeAsString(content);
    return file.path;
  }

  String _csv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}

class ImportResult {
  ImportResult(
      {required this.templates, required this.products, required this.invoices});
  final int templates;
  final int products;
  final int invoices;
}

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(ref.read(appDatabaseProvider), ref);
});
