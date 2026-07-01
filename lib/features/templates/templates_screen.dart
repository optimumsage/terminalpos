import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/repositories.dart';
import '../../models/template.dart';
import '../../widgets/ui.dart';

/// Lists all invoice templates (built-in + custom) and lets the user create,
/// duplicate, delete and open templates for editing.
class TemplatesScreen extends ConsumerWidget {
  const TemplatesScreen({super.key});

  Future<void> _createTemplate(BuildContext context, WidgetRef ref) async {
    final template =
        presetTemplates().first.clone(id: newId(), name: 'Custom Template');
    await ref.read(templateRepositoryProvider).save(template);
    if (!context.mounted) return;
    context.push('/templates/${template.id}');
  }

  Future<void> _duplicate(
    BuildContext context,
    WidgetRef ref,
    InvoiceTemplate source,
  ) async {
    final copy =
        source.clone(id: newId(), name: '${source.name} Copy');
    await ref.read(templateRepositoryProvider).save(copy);
    if (!context.mounted) return;
    showSnack(context, 'Duplicated "${source.name}"');
    context.push('/templates/${copy.id}');
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    InvoiceTemplate template,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete template'),
        content: Text('Delete "${template.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(templateRepositoryProvider).delete(template.id);
    if (!context.mounted) return;
    showSnack(context, 'Deleted "${template.name}"');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templatesAsync = ref.watch(templatesStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Templates'),
        actions: [
          IconButton(
            tooltip: 'New template',
            icon: const Icon(Icons.add),
            onPressed: () => _createTemplate(context, ref),
          ),
        ],
      ),
      body: templatesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Failed to load: $error')),
        data: (templates) {
          if (templates.isEmpty) {
            return EmptyState(
              icon: Icons.dashboard_customize_outlined,
              title: 'No templates yet',
              message: 'Create a custom template to tailor your invoices.',
              action: FilledButton.icon(
                onPressed: () => _createTemplate(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('New template'),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: templates.length,
            itemBuilder: (context, index) => _TemplateCard(
              template: templates[index],
              onOpen: () => context.push('/templates/${templates[index].id}'),
              onDuplicate: () => _duplicate(context, ref, templates[index]),
              onDelete: templates[index].builtIn
                  ? null
                  : () => _delete(context, ref, templates[index]),
            ),
          );
        },
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.template,
    required this.onOpen,
    required this.onDuplicate,
    this.onDelete,
  });

  final InvoiceTemplate template;
  final VoidCallback onOpen;
  final VoidCallback onDuplicate;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabledCount = template.sections.where((s) => s.enabled).length;
    final totalCount = template.sections.length;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer
                      .withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.receipt_long_outlined,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            template.name,
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (template.builtIn) ...[
                          const SizedBox(width: 8),
                          _Badge(label: 'Built-in'),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$enabledCount of $totalCount sections enabled',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Actions',
                onSelected: (value) {
                  switch (value) {
                    case 'duplicate':
                      onDuplicate();
                    case 'delete':
                      onDelete?.call();
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'duplicate',
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.copy_outlined),
                      title: Text('Duplicate'),
                    ),
                  ),
                  if (onDelete != null)
                    const PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.delete_outline),
                        title: Text('Delete'),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSecondaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
