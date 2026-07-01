import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../core/enums.dart';
import '../models/app_settings.dart';
import '../models/invoice.dart';
import '../models/product.dart';
import '../models/template.dart';
import 'app_database.dart';

const _uuid = Uuid();
String newId() => _uuid.v4();

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

// --------------------------------------------------------------------------
// Settings
// --------------------------------------------------------------------------
const _settingsKey = 'app_settings';

/// Loads [AppSettings] from the KV store and persists every mutation. Seeds
/// defaults + preset templates on first launch.
class SettingsController extends AsyncNotifier<AppSettings> {
  AppDatabase get _db => ref.read(appDatabaseProvider);

  @override
  Future<AppSettings> build() async {
    final raw = await _db.getKv(_settingsKey);
    if (raw == null) {
      final defaults = AppSettings();
      await _db.setKv(_settingsKey, jsonEncode(defaults.toJson()));
      await _seedTemplates();
      return defaults;
    }
    await _seedTemplates();
    return AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> _seedTemplates() async {
    final existing = await _db.allTemplates();
    if (existing.isNotEmpty) return;
    final now = DateTime.now();
    for (final t in presetTemplates()) {
      await _db.upsertTemplate(t.id, jsonEncode(t.toJson()), now);
    }
  }

  Future<void> edit(AppSettings Function(AppSettings) mutate) async {
    final current = state.value ?? AppSettings();
    final next = mutate(current.copy());
    await _db.setKv(_settingsKey, jsonEncode(next.toJson()));
    state = AsyncData(next);
  }

  /// Returns the current auto-increment number and advances the counter.
  Future<int> consumeInvoiceNumber() async {
    final current = state.value ?? AppSettings();
    final n = current.invoiceNextNumber;
    await update((s) => s..invoiceNextNumber = n + 1);
    return n;
  }
}

final settingsProvider =
    AsyncNotifierProvider<SettingsController, AppSettings>(
        SettingsController.new);

/// Non-null convenience for widgets that only build once settings are loaded.
final settingsValueProvider = Provider<AppSettings>((ref) {
  return ref.watch(settingsProvider).value ?? AppSettings();
});

// --------------------------------------------------------------------------
// Invoices
// --------------------------------------------------------------------------
final invoicesStreamProvider = StreamProvider<List<Invoice>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchInvoices().map((rows) => rows
      .map((r) => Invoice.fromJson(jsonDecode(r.data) as Map<String, dynamic>))
      .toList());
});

final invoiceRepositoryProvider = Provider<InvoiceRepository>((ref) {
  return InvoiceRepository(ref.read(appDatabaseProvider));
});

class InvoiceRepository {
  InvoiceRepository(this._db);
  final AppDatabase _db;

  Future<void> save(Invoice invoice) async {
    invoice.updatedAt = DateTime.now();
    await _db.upsertInvoice(
        invoice.id, jsonEncode(invoice.toJson()), invoice.updatedAt);
  }

  Future<Invoice?> get(String id) async {
    final row = await _db.getInvoice(id);
    if (row == null) return null;
    return Invoice.fromJson(jsonDecode(row.data) as Map<String, dynamic>);
  }

  Future<void> delete(String id) => _db.deleteInvoice(id);

  /// Deep-copies an invoice with a new id/name/timestamp and reset status.
  Invoice cloneOf(Invoice source, {required String name}) {
    final now = DateTime.now();
    return Invoice(
      id: newId(),
      name: name,
      number: source.number,
      templateId: source.templateId,
      createdAt: now,
      updatedAt: now,
      status: InvoiceStatus.draft,
      billToName: source.billToName,
      billToPhone: source.billToPhone,
      billToAddress: source.billToAddress,
      notes: source.notes,
      discountKind: source.discountKind,
      discountValue: source.discountValue,
      taxEnabled: source.taxEnabled,
      taxRate: source.taxRate,
      items: source.items
          .map((i) => i.copyWith(id: newId()))
          .toList(growable: true),
    );
  }
}

// --------------------------------------------------------------------------
// Products
// --------------------------------------------------------------------------
final productsStreamProvider = StreamProvider<List<Product>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchProducts().map((rows) => rows
      .map((r) => Product.fromJson(jsonDecode(r.data) as Map<String, dynamic>))
      .toList());
});

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepository(ref.read(appDatabaseProvider));
});

class ProductRepository {
  ProductRepository(this._db);
  final AppDatabase _db;

  Future<void> save(Product p) =>
      _db.upsertProduct(p.id, jsonEncode(p.toJson()), DateTime.now());

  Future<void> delete(String id) => _db.deleteProduct(id);
}

// --------------------------------------------------------------------------
// Templates
// --------------------------------------------------------------------------
final templatesStreamProvider = StreamProvider<List<InvoiceTemplate>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchTemplates().map((rows) => rows
      .map((r) =>
          InvoiceTemplate.fromJson(jsonDecode(r.data) as Map<String, dynamic>))
      .toList());
});

final templateRepositoryProvider = Provider<TemplateRepository>((ref) {
  return TemplateRepository(ref.read(appDatabaseProvider));
});

class TemplateRepository {
  TemplateRepository(this._db);
  final AppDatabase _db;

  Future<void> save(InvoiceTemplate t) =>
      _db.upsertTemplate(t.id, jsonEncode(t.toJson()), DateTime.now());

  Future<void> delete(String id) => _db.deleteTemplate(id);

  Future<InvoiceTemplate?> firstOrNull() async {
    final rows = await _db.allTemplates();
    if (rows.isEmpty) return null;
    return InvoiceTemplate.fromJson(
        jsonDecode(rows.first.data) as Map<String, dynamic>);
  }
}
