import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/enums.dart';
import '../../data/repositories.dart';
import '../../models/template.dart';
import '../../widgets/ui.dart';

/// Edits a single [InvoiceTemplate] on a local copy, saving only on demand.
/// Built-in templates are read-only and can be duplicated to customize.
class TemplateEditorScreen extends ConsumerStatefulWidget {
  const TemplateEditorScreen({super.key, required this.templateId});

  final String templateId;

  @override
  ConsumerState<TemplateEditorScreen> createState() =>
      _TemplateEditorScreenState();
}

class _TemplateEditorScreenState extends ConsumerState<TemplateEditorScreen> {
  InvoiceTemplate? _edited;
  bool _builtIn = false;
  bool _initialized = false;

  late TextEditingController _nameCtrl;
  late TextEditingController _headerCtrl;
  late TextEditingController _footerCtrl;

  @override
  void dispose() {
    if (_initialized) {
      _nameCtrl.dispose();
      _headerCtrl.dispose();
      _footerCtrl.dispose();
    }
    super.dispose();
  }

  void _initFrom(InvoiceTemplate source) {
    _edited = source.clone(id: source.id, name: source.name);
    _builtIn = source.builtIn;
    _nameCtrl = TextEditingController(text: source.name);
    _headerCtrl = TextEditingController(text: source.headerText);
    _footerCtrl = TextEditingController(text: source.footerText);
    _initialized = true;
  }

  Future<void> _save() async {
    final template = _edited!
      ..name = _nameCtrl.text.trim().isEmpty
          ? 'Untitled Template'
          : _nameCtrl.text.trim()
      ..headerText = _headerCtrl.text
      ..footerText = _footerCtrl.text;
    await ref.read(templateRepositoryProvider).save(template);
    if (!mounted) return;
    showSnack(context, 'Template saved');
    context.pop();
  }

  Future<void> _duplicate() async {
    final copy = _edited!.clone(id: newId(), name: '${_edited!.name} Copy');
    await ref.read(templateRepositoryProvider).save(copy);
    if (!mounted) return;
    showSnack(context, 'Created editable copy');
    context.pushReplacement('/templates/${copy.id}');
  }

  @override
  Widget build(BuildContext context) {
    final templatesAsync = ref.watch(templatesStreamProvider);

    return templatesAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('Template')),
        body: Center(child: Text('Failed to load: $error')),
      ),
      data: (templates) {
        InvoiceTemplate? source;
        for (final t in templates) {
          if (t.id == widget.templateId) {
            source = t;
            break;
          }
        }
        if (source == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Template')),
            body: const EmptyState(
              icon: Icons.search_off,
              title: 'Template not found',
              message: 'It may have been deleted.',
            ),
          );
        }
        if (!_initialized) {
          _initFrom(source);
        }
        return _buildEditor(context);
      },
    );
  }

  Widget _buildEditor(BuildContext context) {
    final template = _edited!;
    final readOnly = _builtIn;

    return Scaffold(
      appBar: AppBar(
        title: Text(readOnly ? _nameCtrl.text : 'Edit Template'),
        actions: [
          if (readOnly)
            TextButton.icon(
              onPressed: _duplicate,
              icon: const Icon(Icons.copy_outlined),
              label: const Text('Duplicate'),
            )
          else
            IconButton(
              tooltip: 'Save',
              icon: const Icon(Icons.check),
              onPressed: _save,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          SectionCard(
            title: 'Details',
            icon: Icons.badge_outlined,
            children: [
              if (readOnly)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .secondaryContainer
                        .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_outline, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Built-in templates are read-only. Duplicate to '
                          'customize.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              TextField(
                controller: _nameCtrl,
                readOnly: readOnly,
                enabled: !readOnly,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  prefixIcon: Icon(Icons.title),
                ),
                onChanged: readOnly ? null : (_) => setState(() {}),
              ),
            ],
          ),
          SectionCard(
            title: 'Header & footer',
            icon: Icons.notes_outlined,
            children: [
              TextField(
                controller: _headerCtrl,
                readOnly: readOnly,
                enabled: !readOnly,
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Header text',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _footerCtrl,
                readOnly: readOnly,
                enabled: !readOnly,
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Footer text',
                ),
              ),
            ],
          ),
          SectionCard(
            title: 'Layout',
            icon: Icons.tune,
            children: [
              Text(
                'Font scale',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: template.fontScale.clamp(0.8, 1.4),
                      min: 0.8,
                      max: 1.4,
                      divisions: 12,
                      label: template.fontScale.toStringAsFixed(2),
                      onChanged: readOnly
                          ? null
                          : (v) => setState(() => template.fontScale = v),
                    ),
                  ),
                  SizedBox(
                    width: 44,
                    child: Text(
                      template.fontScale.toStringAsFixed(2),
                      textAlign: TextAlign.end,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Alignment',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<TemplateAlignment>(
                segments: const [
                  ButtonSegment(
                    value: TemplateAlignment.left,
                    label: Text('Left'),
                    icon: Icon(Icons.format_align_left),
                  ),
                  ButtonSegment(
                    value: TemplateAlignment.center,
                    label: Text('Center'),
                    icon: Icon(Icons.format_align_center),
                  ),
                ],
                selected: {template.alignment},
                onSelectionChanged: readOnly
                    ? null
                    : (selection) => setState(
                          () => template.alignment = selection.first,
                        ),
              ),
              const SizedBox(height: 4),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Show borders'),
                value: template.showBorders,
                onChanged: readOnly
                    ? null
                    : (v) => setState(() => template.showBorders = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Accent bold'),
                value: template.accentBold,
                onChanged: readOnly
                    ? null
                    : (v) => setState(() => template.accentBold = v),
              ),
            ],
          ),
          SectionCard(
            title: 'Sections',
            subtitle: 'Drag to reorder, toggle to show or hide.',
            icon: Icons.view_agenda_outlined,
            children: [
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                itemCount: template.sections.length,
                onReorderItem: readOnly
                    ? (_, _) {}
                    : (oldIndex, newIndex) => setState(() {
                          final item = template.sections.removeAt(oldIndex);
                          template.sections.insert(newIndex, item);
                        }),
                itemBuilder: (context, index) {
                  final config = template.sections[index];
                  return _SectionRow(
                    key: ValueKey(config.section.name),
                    index: index,
                    config: config,
                    readOnly: readOnly,
                    onToggle: readOnly
                        ? null
                        : (v) => setState(() => config.enabled = v),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionRow extends StatelessWidget {
  const _SectionRow({
    super.key,
    required this.index,
    required this.config,
    required this.readOnly,
    this.onToggle,
  });

  final int index;
  final TemplateSectionConfig config;
  final bool readOnly;
  final ValueChanged<bool>? onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          if (readOnly)
            Icon(
              Icons.drag_handle,
              color: theme.disabledColor,
            )
          else
            ReorderableDragStartListener(
              index: index,
              child: Icon(
                Icons.drag_handle,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              config.section.label,
              style: theme.textTheme.bodyLarge,
            ),
          ),
          Switch(
            value: config.enabled,
            onChanged: onToggle,
          ),
        ],
      ),
    );
  }
}
