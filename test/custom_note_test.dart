import 'package:flutter_test/flutter_test.dart';
import 'package:terminalpos/core/enums.dart';
import 'package:terminalpos/models/custom_note.dart';

void main() {
  test('CustomNote survives a JSON round-trip (styled blocks included)', () {
    final original = CustomNote(
      id: 'note-1',
      name: 'Welcome sign',
      createdAt: DateTime(2026, 7, 1, 9, 0),
      updatedAt: DateTime(2026, 7, 1, 9, 30),
      blocks: [
        NoteBlock(
          id: 'b1',
          text: 'SPECIAL!!!',
          sizeScale: 1.7,
          font: NoteFont.sans,
          bold: true,
          align: NoteAlign.center,
        ),
        NoteBlock(
          id: 'b2',
          text: 'Line one\nLine two',
          sizeScale: 0.8,
          font: NoteFont.serif,
          italic: true,
          align: NoteAlign.right,
        ),
      ],
    );

    final restored = CustomNote.fromJson(original.toJson());

    expect(restored.id, 'note-1');
    expect(restored.name, 'Welcome sign');
    expect(restored.blocks.length, 2);

    final b1 = restored.blocks[0];
    expect(b1.text, 'SPECIAL!!!');
    expect(b1.sizeScale, 1.7);
    expect(b1.font, NoteFont.sans);
    expect(b1.bold, isTrue);
    expect(b1.italic, isFalse);
    expect(b1.align, NoteAlign.center);

    final b2 = restored.blocks[1];
    expect(b2.text, 'Line one\nLine two');
    expect(b2.font, NoteFont.serif);
    expect(b2.italic, isTrue);
    expect(b2.align, NoteAlign.right);
  });

  test('fromJson tolerates missing optional fields', () {
    final restored = CustomNote.fromJson({
      'id': 'n',
      'createdAt': DateTime(2026).toIso8601String(),
      'updatedAt': DateTime(2026).toIso8601String(),
    });
    expect(restored.name, 'Note');
    expect(restored.blocks, isEmpty);
  });

  test('isEmpty reflects whether any block has text', () {
    final note = CustomNote(
      id: 'n',
      name: 'x',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      blocks: [NoteBlock(id: 'b', text: '   ')],
    );
    expect(note.isEmpty, isTrue);
    note.blocks.first.text = 'hello';
    expect(note.isEmpty, isFalse);
  });
}
