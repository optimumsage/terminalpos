import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

/// Document rows: each entity is stored as a JSON blob keyed by its id. This
/// keeps the schema tiny while our rich domain models own (de)serialization,
/// and Drift still gives us reactive `watch` streams for the UI.
@DataClassName('InvoiceRow')
class Invoices extends Table {
  TextColumn get id => text()();
  TextColumn get data => text()();
  DateTimeColumn get updatedAt => dateTime()();
  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ProductRow')
class Products extends Table {
  TextColumn get id => text()();
  TextColumn get data => text()();
  DateTimeColumn get updatedAt => dateTime()();
  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('TemplateRow')
class Templates extends Table {
  TextColumn get id => text()();
  TextColumn get data => text()();
  DateTimeColumn get updatedAt => dateTime()();
  @override
  Set<Column> get primaryKey => {id};
}

/// Key-value store for singletons such as [AppSettings].
class Kv extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [Invoices, Products, Templates, Kv])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_open());
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  // ---- Invoices ----
  Stream<List<InvoiceRow>> watchInvoices() =>
      (select(invoices)..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
          .watch();

  Future<InvoiceRow?> getInvoice(String id) =>
      (select(invoices)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<InvoiceRow>> allInvoices() => select(invoices).get();

  Future<void> upsertInvoice(String id, String data, DateTime updatedAt) =>
      into(invoices).insertOnConflictUpdate(
          InvoicesCompanion.insert(id: id, data: data, updatedAt: updatedAt));

  Future<void> deleteInvoice(String id) =>
      (delete(invoices)..where((t) => t.id.equals(id))).go();

  // ---- Products ----
  Stream<List<ProductRow>> watchProducts() =>
      (select(products)..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
          .watch();

  Future<List<ProductRow>> allProducts() => select(products).get();

  Future<void> upsertProduct(String id, String data, DateTime updatedAt) =>
      into(products).insertOnConflictUpdate(
          ProductsCompanion.insert(id: id, data: data, updatedAt: updatedAt));

  Future<void> deleteProduct(String id) =>
      (delete(products)..where((t) => t.id.equals(id))).go();

  // ---- Templates ----
  Stream<List<TemplateRow>> watchTemplates() =>
      (select(templates)..orderBy([(t) => OrderingTerm.asc(t.updatedAt)]))
          .watch();

  Future<List<TemplateRow>> allTemplates() => select(templates).get();

  Future<void> upsertTemplate(String id, String data, DateTime updatedAt) =>
      into(templates).insertOnConflictUpdate(
          TemplatesCompanion.insert(id: id, data: data, updatedAt: updatedAt));

  Future<void> deleteTemplate(String id) =>
      (delete(templates)..where((t) => t.id.equals(id))).go();

  // ---- Kv ----
  Future<String?> getKv(String key) async {
    final row =
        await (select(kv)..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> setKv(String key, String value) => into(kv)
      .insertOnConflictUpdate(KvCompanion.insert(key: key, value: value));
}

LazyDatabase _open() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'terminalpos.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
