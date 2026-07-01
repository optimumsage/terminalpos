import '../../models/app_settings.dart';
import '../render/rasterizer.dart';
import 'command_builder.dart';

/// CPCL builder (Zebra/mobile printers). Uses the EG expanded-graphics command
/// to place the raster, then FORM + PRINT.
class CpclBuilder implements CommandBuilder {
  const CpclBuilder();

  @override
  List<int> build(MonoBitmap bmp, AppSettings s) {
    final hex = bytesToHex(bmp.bits);
    // ! 0 200 200 <height> <qty>
    final buffer = StringBuffer()
      ..write('! 0 200 200 ${bmp.height} 1\r\n')
      ..write('EG ${bmp.bytesPerRow} ${bmp.height} 0 0 $hex\r\n')
      ..write('FORM\r\n')
      ..write('PRINT\r\n');
    return buffer.toString().codeUnits;
  }
}

/// Selects the right builder for the configured printer language.
