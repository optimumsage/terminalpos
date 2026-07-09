import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/enums.dart';
import '../../data/repositories.dart';
import '../../models/custom_note.dart';
import '../../widgets/ui.dart';

/// Edits a single custom-print note on the live note object, autosaving on every
/// change. A note is an ordered list of styled text blocks.
class NoteEditorScreen extends ConsumerStatefulWidget {
  const NoteEditorScreen({super.key, required this.noteId});
  final String noteId;

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  CustomNote? _note;
  bool _loading = true;
  late final TextEditingController _nameCtrl;
  final Map<String, TextEditingController> _blockCtrls = {};

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _load();
  }

  Future<void> _load() async {
    // Wait for the notes provider to finish loading, then grab the live object.
    await ref.read(notesProvider.future);
    final note = ref.read(notesProvider.notifier).get(widget.noteId);
    if (note != null) {
      _nameCtrl.text = note.name;
      for (final b in note.blocks) {
        _blockCtrls[b.id] = TextEditingController(text: b.text);
      }
    }
    if (!mounted) return;
    setState(() {
      _note = note;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    for (final c in _blockCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    final note = _note;
    if (note == null) return;
    note.name = _nameCtrl.text.trim().isEmpty ? 'Note' : _nameCtrl.text.trim();
    ref.read(notesProvider.notifier).save(note);
  }

  void _addBlock() {
    final note = _note;
    if (note == null) return;
    final block = NoteBlock(id: newId());
    _blockCtrls[block.id] = TextEditingController();
    setState(() => note.blocks.add(block));
    _save();
  }

  Future<void> _showAddSheet() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Add block',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            ),
            ListTile(
              leading: const Icon(Icons.text_fields),
              title: const Text('Text block'),
              subtitle: const Text('Styled text — size, font, bold, align'),
              onTap: () => Navigator.pop(context, 'text'),
            ),
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: const Text('Image block'),
              subtitle: const Text('Pick an image to print'),
              onTap: () => Navigator.pop(context, 'image'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choice == 'text') {
      _addBlock();
    } else if (choice == 'image') {
      await _addImageBlock();
    }
  }

  Future<void> _addImageBlock() async {
    final path = await _pickImage();
    if (path == null) return;
    final note = _note;
    if (note == null) return;
    final block = NoteBlock(id: newId(), imagePath: path);
    _blockCtrls[block.id] = TextEditingController();
    setState(() => note.blocks.add(block));
    _save();
  }

  /// Picks an image and copies it into the app documents dir (picked temp files
  /// can be cleared). Returns the persistent path, or null if cancelled.
  Future<String?> _pickImage() async {
    final picked =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return null;
    final dir = await getApplicationDocumentsDirectory();
    final dest = p.join(
        dir.path, 'note_${DateTime.now().millisecondsSinceEpoch}.png');
    await File(picked.path).copy(dest);
    return dest;
  }

  Future<void> _replaceImage(NoteBlock block) async {
    final path = await _pickImage();
    if (path == null) return;
    setState(() => block.imagePath = path);
    _save();
  }

  void _removeImage(NoteBlock block) {
    // Clear the image so the block becomes an (empty) text block again.
    setState(() => block.imagePath = '');
    _save();
  }

  void _deleteBlock(NoteBlock block) {
    final note = _note;
    if (note == null) return;
    _blockCtrls.remove(block.id)?.dispose();
    setState(() => note.blocks.remove(block));
    _save();
  }

  void _moveBlock(int index, int delta) {
    final note = _note;
    if (note == null) return;
    final target = index + delta;
    if (target < 0 || target >= note.blocks.length) return;
    setState(() {
      final b = note.blocks.removeAt(index);
      note.blocks.insert(target, b);
    });
    _save();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final note = _note;
    if (note == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(
            icon: Icons.error_outline, title: 'Note not found'),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Note'),
        actions: [
          IconButton(
            tooltip: 'Preview & Print',
            icon: const Icon(Icons.print_outlined),
            onPressed: () {
              _save();
              context.push('/notes/${note.id}/preview');
            },
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _showAddSheet,
                  icon: const Icon(Icons.add),
                  label: const Text('Add block'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    _save();
                    context.push('/notes/${note.id}/preview');
                  },
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('Preview'),
                ),
              ),
            ],
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          SectionCard(
            title: 'Note',
            icon: Icons.sticky_note_2_outlined,
            children: [
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Note name'),
                onChanged: (_) => _save(),
              ),
            ],
          ),
          for (var i = 0; i < note.blocks.length; i++)
            _BlockCard(
              key: ValueKey(note.blocks[i].id),
              index: i,
              total: note.blocks.length,
              block: note.blocks[i],
              controller: _blockCtrls[note.blocks[i].id]!,
              onChanged: () => setState(_save),
              onTextChanged: (v) {
                note.blocks[i].text = v;
                _save();
              },
              onPickImage: () => _replaceImage(note.blocks[i]),
              onRemoveImage: () => _removeImage(note.blocks[i]),
              onDelete: () => _deleteBlock(note.blocks[i]),
              onMoveUp: () => _moveBlock(i, -1),
              onMoveDown: () => _moveBlock(i, 1),
            ),
        ],
      ),
    );
  }
}

class _BlockCard extends StatelessWidget {
  const _BlockCard({
    super.key,
    required this.index,
    required this.total,
    required this.block,
    required this.controller,
    required this.onChanged,
    required this.onTextChanged,
    required this.onPickImage,
    required this.onRemoveImage,
    required this.onDelete,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  final int index;
  final int total;
  final NoteBlock block;
  final TextEditingController controller;
  final VoidCallback onChanged;
  final ValueChanged<String> onTextChanged;
  final VoidCallback onPickImage;
  final VoidCallback onRemoveImage;
  final VoidCallback onDelete;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: block.isImage ? 'Image ${index + 1}' : 'Block ${index + 1}',
      icon: block.isImage ? Icons.image_outlined : Icons.text_fields,
      children: [
        if (block.isImage) ..._imageChildren(context) else ..._textChildren(context),
        const Divider(height: 24),
        Row(
          children: [
            IconButton(
              tooltip: 'Move up',
              icon: const Icon(Icons.arrow_upward),
              onPressed: index == 0 ? null : onMoveUp,
            ),
            IconButton(
              tooltip: 'Move down',
              icon: const Icon(Icons.arrow_downward),
              onPressed: index == total - 1 ? null : onMoveDown,
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: total <= 1 ? null : onDelete,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete block'),
            ),
          ],
        ),
      ],
    );
  }

  List<Widget> _textChildren(BuildContext context) => [
        TextField(
          controller: controller,
          maxLines: null,
          minLines: 2,
          keyboardType: TextInputType.multiline,
          decoration: const InputDecoration(
            hintText: 'Type your text…',
            border: OutlineInputBorder(),
          ),
          onChanged: onTextChanged,
        ),
        const SizedBox(height: 16),
        Text('Size', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: SegmentedButton<double>(
            segments: [
              for (final e in sizePresets.entries)
                ButtonSegment(value: e.value, label: Text(e.key)),
            ],
            selected: {_closest(sizePresets.values, block.sizeScale)},
            showSelectedIcon: false,
            onSelectionChanged: (sel) {
              block.sizeScale = sel.first;
              onChanged();
            },
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Text('Font', style: Theme.of(context).textTheme.labelLarge),
            const Spacer(),
            DropdownButton<NoteFont>(
              value: block.font,
              items: [
                for (final f in NoteFont.values)
                  DropdownMenuItem(value: f, child: Text(f.label)),
              ],
              onChanged: (v) {
                if (v != null) {
                  block.font = v;
                  onChanged();
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilterChip(
              label: const Text('Bold'),
              selected: block.bold,
              onSelected: (v) {
                block.bold = v;
                onChanged();
              },
            ),
            FilterChip(
              label: const Text('Italic'),
              selected: block.italic,
              onSelected: (v) {
                block.italic = v;
                onChanged();
              },
            ),
            _alignButtons(),
          ],
        ),
      ];

  List<Widget> _imageChildren(BuildContext context) {
    final exists = block.imagePath.isNotEmpty && File(block.imagePath).existsSync();
    return [
      Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxHeight: 220),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(8),
        child: exists
            ? Image.file(File(block.imagePath), fit: BoxFit.contain)
            : const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('Image not found', textAlign: TextAlign.center),
              ),
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: onPickImage,
            icon: const Icon(Icons.image_search),
            label: const Text('Replace'),
          ),
          TextButton.icon(
            onPressed: onRemoveImage,
            icon: const Icon(Icons.hide_image_outlined),
            label: const Text('Remove image'),
          ),
        ],
      ),
      const SizedBox(height: 16),
      Text('Width', style: Theme.of(context).textTheme.labelLarge),
      const SizedBox(height: 8),
      Align(
        alignment: Alignment.centerLeft,
        child: SegmentedButton<double>(
          segments: [
            for (final e in imageWidthPresets.entries)
              ButtonSegment(value: e.value, label: Text(e.key)),
          ],
          selected: {_closest(imageWidthPresets.values, block.imageWidthScale)},
          showSelectedIcon: false,
          onSelectionChanged: (sel) {
            block.imageWidthScale = sel.first;
            onChanged();
          },
        ),
      ),
      const SizedBox(height: 16),
      Align(alignment: Alignment.centerLeft, child: _alignButtons()),
    ];
  }

  Widget _alignButtons() => SegmentedButton<NoteAlign>(
        segments: const [
          ButtonSegment(
              value: NoteAlign.left, icon: Icon(Icons.format_align_left)),
          ButtonSegment(
              value: NoteAlign.center, icon: Icon(Icons.format_align_center)),
          ButtonSegment(
              value: NoteAlign.right, icon: Icon(Icons.format_align_right)),
        ],
        selected: {block.align},
        showSelectedIcon: false,
        onSelectionChanged: (sel) {
          block.align = sel.first;
          onChanged();
        },
      );

  /// Snap an arbitrary stored scale to the nearest preset so the SegmentedButton
  /// always has a valid selection.
  double _closest(Iterable<double> presets, double value) {
    double best = presets.first;
    double bestDiff = double.infinity;
    for (final v in presets) {
      final diff = (v - value).abs();
      if (diff < bestDiff) {
        bestDiff = diff;
        best = v;
      }
    }
    return best;
  }
}
