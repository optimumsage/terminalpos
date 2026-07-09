import '../core/enums.dart';

/// A single styled block of text within a [CustomNote]. Each block owns its own
/// size, font, weight, slant and alignment so a note can mix, e.g., a big bold
/// title with smaller body lines. Line breaks inside [text] are preserved.
class NoteBlock {
  NoteBlock({
    required this.id,
    this.text = '',
    this.sizeScale = 1.0,
    this.font = NoteFont.monospace,
    this.bold = false,
    this.italic = false,
    this.align = NoteAlign.left,
  });

  final String id;
  String text;

  /// Multiplier over the base font size (22 dots, matching the invoice
  /// document). Presets: S=0.8, M=1.0, L=1.3, XL=1.7 — see [sizePresets].
  double sizeScale;
  NoteFont font;
  bool bold;
  bool italic;
  NoteAlign align;

  NoteBlock copy() => NoteBlock(
        id: id,
        text: text,
        sizeScale: sizeScale,
        font: font,
        bold: bold,
        italic: italic,
        align: align,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'sizeScale': sizeScale,
        'font': font.name,
        'bold': bold,
        'italic': italic,
        'align': align.name,
      };

  factory NoteBlock.fromJson(Map<String, dynamic> json) => NoteBlock(
        id: json['id'] as String,
        text: json['text'] as String? ?? '',
        sizeScale: (json['sizeScale'] as num?)?.toDouble() ?? 1.0,
        font: NoteFont.values.byName(json['font'] as String? ?? 'monospace'),
        bold: json['bold'] as bool? ?? false,
        italic: json['italic'] as bool? ?? false,
        align: NoteAlign.values.byName(json['align'] as String? ?? 'left'),
      );
}

/// The selectable text-size presets shown in the note editor, keyed by label.
const Map<String, double> sizePresets = {
  'S': 0.8,
  'M': 1.0,
  'L': 1.3,
  'XL': 1.7,
};

/// A saved, reusable custom-print note: an ordered list of styled [blocks].
/// Persisted as JSON in the KV store (key `custom_notes`) alongside the app
/// settings, so no database schema change is required.
class CustomNote {
  CustomNote({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    List<NoteBlock>? blocks,
  }) : blocks = blocks ?? [];

  final String id;
  String name;
  final DateTime createdAt;
  DateTime updatedAt;
  List<NoteBlock> blocks;

  /// Whether every block is empty (used to disable printing a blank note).
  bool get isEmpty => blocks.every((b) => b.text.trim().isEmpty);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'blocks': blocks.map((b) => b.toJson()).toList(),
      };

  factory CustomNote.fromJson(Map<String, dynamic> json) => CustomNote(
        id: json['id'] as String,
        name: json['name'] as String? ?? 'Note',
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        blocks: (json['blocks'] as List<dynamic>? ?? [])
            .map((e) => NoteBlock.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
