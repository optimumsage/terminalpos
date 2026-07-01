import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/backup_service.dart';
import '../../widgets/ui.dart';

/// Backup, restore and CSV export. JSON is written to the app documents folder
/// and copied to the clipboard so it can be pasted back on another device — no
/// native file picker required.
class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  final _importCtrl = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _importCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final backup = ref.read(backupServiceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Backup & Export')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          SectionCard(
            title: 'Full backup (JSON)',
            icon: Icons.backup_outlined,
            subtitle:
                'Includes invoices, products, templates and all settings.',
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _run(() async {
                              final path =
                                  await backup.exportJsonFile(DateTime.now());
                              final json = await backup.exportJsonString();
                              await Clipboard.setData(
                                  ClipboardData(text: json));
                              return 'Saved to $path\n(copied to clipboard)';
                            }),
                    icon: const Icon(Icons.save_alt),
                    label: const Text('Export backup'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _run(() async {
                              final json = await backup.exportJsonString();
                              await Clipboard.setData(
                                  ClipboardData(text: json));
                              return 'Backup JSON copied to clipboard';
                            }),
                    icon: const Icon(Icons.copy_all_outlined),
                    label: const Text('Copy JSON'),
                  ),
                ],
              ),
            ],
          ),
          SectionCard(
            title: 'Restore from JSON',
            icon: Icons.settings_backup_restore,
            subtitle: 'Paste a backup JSON below and import. Existing items '
                'with the same id are overwritten.',
            children: [
              TextField(
                controller: _importCtrl,
                maxLines: 6,
                decoration: const InputDecoration(
                  hintText: '{ "formatVersion": 1, ... }',
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonalIcon(
                  onPressed: _busy ? null : _import,
                  icon: const Icon(Icons.file_download_outlined),
                  label: const Text('Import'),
                ),
              ),
            ],
          ),
          SectionCard(
            title: 'CSV export',
            icon: Icons.table_chart_outlined,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _run(() async {
                              final csv = await backup.exportInvoicesCsv();
                              final path = await backup.writeTextFile(
                                  'invoices.csv', csv);
                              await Clipboard.setData(ClipboardData(text: csv));
                              return 'Invoices CSV saved to $path';
                            }),
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: const Text('Invoices CSV'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _run(() async {
                              final csv = await backup.exportProductsCsv();
                              final path = await backup.writeTextFile(
                                  'products.csv', csv);
                              await Clipboard.setData(ClipboardData(text: csv));
                              return 'Products CSV saved to $path';
                            }),
                    icon: const Icon(Icons.inventory_2_outlined),
                    label: const Text('Products CSV'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _run(Future<String> Function() action) async {
    setState(() => _busy = true);
    try {
      final message = await action();
      if (mounted) {
        showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Done'),
            content: Text(message),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK')),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) showSnack(context, 'Failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    final text = _importCtrl.text.trim();
    if (text.isEmpty) {
      showSnack(context, 'Paste a backup JSON first');
      return;
    }
    setState(() => _busy = true);
    try {
      final result =
          await ref.read(backupServiceProvider).importJsonString(text);
      if (mounted) {
        showSnack(context,
            'Imported ${result.invoices} invoices, ${result.products} products, ${result.templates} templates');
        _importCtrl.clear();
      }
    } catch (e) {
      if (mounted) showSnack(context, 'Import failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
