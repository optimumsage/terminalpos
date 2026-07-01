import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:terminalpos/core/dynamic_fields.dart';
import 'package:terminalpos/data/app_database.dart';
import 'package:terminalpos/data/repositories.dart';
import 'package:terminalpos/models/invoice.dart';

/// Boot/wiring smoke test at the provider layer (real async, no fake clock):
/// settings load + first-run template seeding, then create/clone invoices
/// through the real repositories against an in-memory database.
void main() {
  test('boots: seeds templates and creates/clones invoices', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    // First-run boot: settings load with PKR defaults and templates seed.
    final settings = await container.read(settingsProvider.future);
    expect(settings.currencySymbol, 'Rs.');
    expect(settings.currencyCode, 'PKR');
    expect(settings.money.format(10), 'Rs. 10.00');

    final templates = await db.allTemplates();
    expect(templates, isNotEmpty,
        reason: 'built-in templates should be seeded on first run');

    // Auto-increment invoice number advances.
    final n1 = await container.read(settingsProvider.notifier).consumeInvoiceNumber();
    final n2 = await container.read(settingsProvider.notifier).consumeInvoiceNumber();
    expect(n2, n1 + 1);

    // Create an invoice via the repository.
    final repo = container.read(invoiceRepositoryProvider);
    final now = DateTime(2026, 7, 1, 14, 30);
    final invoice = Invoice(
      id: newId(),
      name: defaultInvoiceName(now),
      number: settings.formatInvoiceNumber(n1),
      templateId: templates.first.id,
      createdAt: now,
      updatedAt: now,
      items: [
        InvoiceItem(id: newId(), name: 'Coffee', quantity: 2, unitPrice: 250),
      ],
    );
    await repo.save(invoice);
    expect(invoice.name, 'Invoice 2026-07-01 14:30');

    var all = await db.allInvoices();
    expect(all.length, 1);

    // Clone deep-copies with a new id and fresh items.
    final clone = repo.cloneOf(invoice, name: '${invoice.name} (copy)');
    await repo.save(clone);
    all = await db.allInvoices();
    expect(all.length, 2);
    expect(clone.id, isNot(invoice.id));
    expect(clone.items.first.id, isNot(invoice.items.first.id));
    expect(clone.items.first.name, 'Coffee');
  });
}
