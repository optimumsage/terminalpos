import '../../models/app_settings.dart';
import '../render/rasterizer.dart';
import 'command_builder.dart';

/// ZPL II builder. Encodes the raster as a ^GFA graphic field. Cut spacing maps
/// to label length feed; cutter/drawer are printer-config dependent on ZPL and
/// left to the device.
class ZplBuilder implements CommandBuilder {
  const ZplBuilder();

  @override
  List<int> build(MonoBitmap bmp, AppSettings s) {
    final total = bmp.bytesPerRow * bmp.height;
    final hex = bytesToHex(bmp.bits);
    final buffer = StringBuffer()
      ..write('^XA')
      ..write('^PW${bmp.width}')
      ..write('^LH0,0')
      ..write('^FO0,0')
      ..write('^GFA,$total,$total,${bmp.bytesPerRow},$hex')
      ..write('^FS');
    if (s.cutMode.name != 'none') {
      buffer.write('^MMC'); // cut mode
    }
    buffer.write('^XZ');
    return buffer.toString().codeUnits;
  }
}
