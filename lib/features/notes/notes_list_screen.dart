import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/repositories.dart';
import '../../models/custom_note.dart';
import '../../widgets/ui.dart';

/// Library of reusable custom-print notes. Mirrors the invoice list: searchable
/// rows, a New Note action, and per-row clone/preview/delete.
class NotesListScreen extends ConsumerWidget {
  const NotesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(notesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Custom Print')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _create(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New Note'),
      ),
      body: notesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (notes) {
          if (notes.isEmpty) {
            return EmptyState(
              icon: Icons.note_alt_outlined,
              title: 'No notes yet',
              message:
                  'Create a note to print anything — receipts messages, signs, '
                  'or reminders — with your own text, sizes and styles.',
              action: FilledButton.icon(
                onPressed: () => _create(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('New Note'),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
            itemCount: notes.length,
            itemBuilder: (context, index) {
              final note = notes[index];
              return Card(
                margin:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: const Icon(Icons.sticky_note_2_outlined),
                  title: Text(note.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    _preview(note),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  trailing: _RowMenu(
                    onPreview: () => context.push('/notes/${note.id}/preview'),
                    onClone: () => _clone(context, ref, note),
                    onDelete: () => _delete(context, ref, note),
                  ),
                  onTap: () => context.push('/notes/${note.id}'),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _preview(CustomNote note) {
    final parts = note.blocks
        .map((b) => b.isImage ? '[image]' : b.text.trim())
        .where((t) => t.isNotEmpty)
        .join(' · ')
        .replaceAll('\n', ' ');
    return parts.isEmpty ? '(empty)' : parts;
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(notesProvider.notifier);
    final note = controller.createBlank();
    await controller.save(note);
    if (context.mounted) context.push('/notes/${note.id}');
  }

  Future<void> _clone(
      BuildContext context, WidgetRef ref, CustomNote source) async {
    final controller = ref.read(notesProvider.notifier);
    final now = DateTime.now();
    final copy = CustomNote(
      id: newId(),
      name: '${source.name} (copy)',
      createdAt: now,
      updatedAt: now,
      blocks: source.blocks.map((b) => b.copy()).toList(),
    );
    await controller.save(copy);
    if (context.mounted) showSnack(context, 'Note cloned');
  }

  Future<void> _delete(
      BuildContext context, WidgetRef ref, CustomNote note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete note?'),
        content: Text('“${note.name}” will be permanently removed.'),
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
      await ref.read(notesProvider.notifier).delete(note.id);
      if (context.mounted) showSnack(context, 'Note deleted');
    }
  }
}

class _RowMenu extends StatelessWidget {
  const _RowMenu({
    required this.onPreview,
    required this.onClone,
    required this.onDelete,
  });
  final VoidCallback onPreview;
  final VoidCallback onClone;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_horiz, size: 20),
      padding: EdgeInsets.zero,
      onSelected: (v) {
        switch (v) {
          case 'preview':
            onPreview();
            break;
          case 'clone':
            onClone();
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
