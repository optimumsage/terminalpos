import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/enums.dart';
import '../../models/app_settings.dart';
import '../../models/custom_note.dart';
import 'paper.dart';

/// Renders a [CustomNote] exactly as it will print: black-on-white, sized to the
/// printable dot width. The SAME widget backs the on-screen preview and the
/// rasterizer, guaranteeing WYSIWYG — mirroring `InvoiceDocument`.
class CustomDocument extends StatelessWidget {
  const CustomDocument({
    super.key,
    required this.note,
    required this.settings,
  });

  final CustomNote note;
  final AppSettings settings;

  // Base font size in dots, matching InvoiceDocument so sizes feel consistent.
  static const double _base = 22.0;

  @override
  Widget build(BuildContext context) {
    final metrics = PaperMetrics.forWidth(settings.paperWidthMm);
    final blocks = <Widget>[];
    for (final block in note.blocks) {
      final widget = _block(block, metrics);
      if (widget != null) blocks.add(widget);
    }

    return Container(
      width: metrics.dots.toDouble(),
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: _withSpacing(blocks),
      ),
    );
  }

  Widget? _block(NoteBlock block, PaperMetrics metrics) {
    if (block.isImage) return _imageBlock(block, metrics);
    if (block.text.trim().isEmpty) return null;
    return Text(
      block.text,
      textAlign: _textAlign(block.align),
      style: TextStyle(
        color: Colors.black,
        fontSize: _base * block.sizeScale,
        fontWeight: block.bold ? FontWeight.w900 : FontWeight.w400,
        fontStyle: block.italic ? FontStyle.italic : FontStyle.normal,
        fontFamily: block.font.family,
        height: 1.25,
      ),
    );
  }

  Widget? _imageBlock(NoteBlock block, PaperMetrics metrics) {
    final file = File(block.imagePath);
    if (!file.existsSync()) return null;
    return Align(
      alignment: _alignment(block.align),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: metrics.dots * block.imageWidthScale,
        ),
        child: Image.file(
          file,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
        ),
      ),
    );
  }

  Alignment _alignment(NoteAlign align) {
    switch (align) {
      case NoteAlign.left:
        return Alignment.centerLeft;
      case NoteAlign.center:
        return Alignment.center;
      case NoteAlign.right:
        return Alignment.centerRight;
    }
  }

  TextAlign _textAlign(NoteAlign align) {
    switch (align) {
      case NoteAlign.left:
        return TextAlign.left;
      case NoteAlign.center:
        return TextAlign.center;
      case NoteAlign.right:
        return TextAlign.right;
    }
  }

  List<Widget> _withSpacing(List<Widget> children) {
    final out = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      out.add(children[i]);
      if (i != children.length - 1) out.add(const SizedBox(height: 10));
    }
    return out;
  }
}
