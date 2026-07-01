import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:terminalpos/core/enums.dart';
import 'package:terminalpos/models/app_settings.dart';
import 'package:terminalpos/print/builders/cpcl_builder.dart';
import 'package:terminalpos/print/builders/escpos_builder.dart';
import 'package:terminalpos/print/builders/zpl_builder.dart';
import 'package:terminalpos/print/render/rasterizer.dart';

MonoBitmap _bmp() {
  // 8px wide (1 byte/row), 2 rows, all black.
  return MonoBitmap(
    width: 8,
    height: 2,
    bytesPerRow: 1,
    bits: Uint8List.fromList([0xFF, 0xFF]),
  );
}

void main() {
  test('ESC/POS GS v 0 raster carries the correct header + dimensions', () {
    final s = AppSettings()
      ..printMethod = PrintMethod.gsv0
      ..cutMode = CutMode.full
      ..openCashDrawer = false
      ..beep = false;
    final bytes = const EscPosBuilder().build(_bmp(), s);

    // Must start with ESC @ (init).
    expect(bytes.sublist(0, 2), [0x1B, 0x40]);
    // GS v 0 marker present with xL=1,xH=0,yL=2,yH=0 then data 0xFF,0xFF.
    final idx = _indexOfSeq(bytes, [0x1D, 0x76, 0x30, 0x00, 1, 0, 2, 0]);
    expect(idx, isNonNegative);
    expect(bytes.sublist(idx + 8, idx + 10), [0xFF, 0xFF]);
    // Full cut command present at the tail.
    expect(_indexOfSeq(bytes, [0x1D, 0x56, 0x00]), isNonNegative);
  });

  test('ESC/POS cash drawer pulse emitted when enabled', () {
    final s = AppSettings()..openCashDrawer = true;
    final bytes = const EscPosBuilder().build(_bmp(), s);
    expect(_indexOfSeq(bytes, [0x1B, 0x70]), isNonNegative);
  });

  test('ZPL wraps a ^GFA graphic field', () {
    final zpl = String.fromCharCodes(
        const ZplBuilder().build(_bmp(), AppSettings()));
    expect(zpl.startsWith('^XA'), isTrue);
    expect(zpl.contains('^GFA,2,2,1,FFFF'), isTrue);
    expect(zpl.endsWith('^XZ'), isTrue);
  });

  test('CPCL emits EG graphics and PRINT', () {
    final cpcl = String.fromCharCodes(
        const CpclBuilder().build(_bmp(), AppSettings()));
    expect(cpcl.contains('EG 1 2 0 0 FFFF'), isTrue);
    expect(cpcl.contains('PRINT'), isTrue);
  });
}

int _indexOfSeq(List<int> haystack, List<int> needle) {
  for (var i = 0; i <= haystack.length - needle.length; i++) {
    var ok = true;
    for (var j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) {
        ok = false;
        break;
      }
    }
    if (ok) return i;
  }
  return -1;
}
