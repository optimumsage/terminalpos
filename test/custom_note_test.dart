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

  test('image blocks round-trip and report isImage', () {
    final note = CustomNote(
      id: 'n',
      name: 'Signage',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      blocks: [
        NoteBlock(
          id: 'img',
          imagePath: '/data/app/note_123.png',
          imageWidthScale: 0.6,
          align: NoteAlign.center,
        ),
      ],
    );

    final restored = CustomNote.fromJson(note.toJson());
    final b = restored.blocks.single;
    expect(b.isImage, isTrue);
    expect(b.imagePath, '/data/app/note_123.png');
    expect(b.imageWidthScale, 0.6);
    expect(b.align, NoteAlign.center);
    // A note with an image block (even with no text) is not "empty".
    expect(restored.isEmpty, isFalse);
  });

  test('old JSON without image fields defaults to a text block', () {
    final b = NoteBlock.fromJson({'id': 'b', 'text': 'hi'});
    expect(b.isImage, isFalse);
    expect(b.imagePath, '');
    expect(b.imageWidthScale, 1.0);
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
