import 'package:flutter_test/flutter_test.dart';
import 'package:sajda_dataplus/services/version_check_service.dart';

void main() {
  group('VersionCheckService.compareVersions', () {
    test('older major version compares less', () {
      expect(VersionCheckService.compareVersions('1.0.3', '2.1.0'), lessThan(0));
    });

    test('numeric segments compare numerically, not lexically', () {
      // String compare would say '9' > '10' — must not happen.
      expect(VersionCheckService.compareVersions('1.2.9', '1.2.10'), lessThan(0));
      expect(VersionCheckService.compareVersions('1.2.10', '1.2.9'), greaterThan(0));
    });

    test('equal versions compare to zero', () {
      expect(VersionCheckService.compareVersions('2.1.0', '2.1.0'), 0);
    });

    test('build metadata (+N) is ignored', () {
      expect(VersionCheckService.compareVersions('1.0.3+4', '1.0.3'), 0);
      expect(VersionCheckService.compareVersions('1.0.3+4', '1.0.4'), lessThan(0));
    });

    test('missing segments count as zero', () {
      expect(VersionCheckService.compareVersions('2', '2.0.0'), 0);
      expect(VersionCheckService.compareVersions('2', '2.0.1'), lessThan(0));
    });

    test('garbage inputs never throw and default to 0', () {
      expect(VersionCheckService.compareVersions('abc', '0.0.0'), 0);
      expect(VersionCheckService.compareVersions('', '1.0.0'), lessThan(0));
    });

    test('force gate triggers exactly when installed < required', () {
      // Installed 1.0.3, backend requires 2.1.0 → gate must show.
      expect(VersionCheckService.compareVersions('1.0.3', '2.1.0') < 0, isTrue);
      // Installed 2.1.0 → no gate.
      expect(VersionCheckService.compareVersions('2.1.0', '2.1.0') < 0, isFalse);
      // Installed newer than required → no gate.
      expect(VersionCheckService.compareVersions('3.0.0', '2.1.0') < 0, isFalse);
    });
  });
}
