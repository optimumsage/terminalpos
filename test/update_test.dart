import 'package:flutter_test/flutter_test.dart';
import 'package:terminalpos/data/update_service.dart';

void main() {
  test('newer version is detected across each segment', () {
    expect(compareVersions('1.0.1', '1.0.0'), greaterThan(0));
    expect(compareVersions('1.1.0', '1.0.9'), greaterThan(0));
    expect(compareVersions('2.0.0', '1.9.9'), greaterThan(0));
    expect(compareVersions('1.0.0', '1.0.1'), lessThan(0));
    expect(compareVersions('1.0.0', '1.0.0'), 0);
  });

  test('handles missing segments and build metadata', () {
    expect(compareVersions('1.2', '1.2.0'), 0);
    expect(compareVersions('1.0.0+5', '1.0.0+1'), 0);
    expect(compareVersions('1.3', '1.2.9'), greaterThan(0));
  });

  test('release outranks its pre-release', () {
    expect(compareVersions('1.0.0', '1.0.0-beta'), greaterThan(0));
    expect(compareVersions('1.0.0-beta', '1.0.0'), lessThan(0));
  });
}
