import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:terminalpos/data/app_database.dart';
import 'package:terminalpos/data/repositories.dart';

/// Regression guard: consuming an invoice number must PERSIST the advanced
/// counter to the KV store, so it keeps incrementing across app restarts.
/// Previously it used the in-memory-only `AsyncNotifier.update`, so the counter
/// reset on restart and repeated numbers were handed out.
void main() {
  test('consumeInvoiceNumber persists the advanced counter to the KV store',
      () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    await container.read(settingsProvider.future);
    final n1 = await container.read(settingsProvider.notifier).consumeInvoiceNumber();

    // The KV row (not just in-memory state) must reflect the advance.
    final raw = await db.getKv('app_settings');
    expect(raw, isNotNull);
    final persisted = jsonDecode(raw!) as Map<String, dynamic>;
    expect(persisted['invoiceNextNumber'], n1 + 1);
  });

  test('counter keeps incrementing across a simulated restart', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    // First "session".
    final c1 = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    await c1.read(settingsProvider.future);
    final n1 = await c1.read(settingsProvider.notifier).consumeInvoiceNumber();
    c1.dispose();

    // Second "session" against the same database (fresh providers = restart).
    final c2 = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(c2.dispose);
    await c2.read(settingsProvider.future);
    final n2 = await c2.read(settingsProvider.notifier).consumeInvoiceNumber();

    expect(n2, n1 + 1, reason: 'restart must not repeat the previous number');
  });
}
