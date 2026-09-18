import 'package:flutter_test/flutter_test.dart';
import 'package:no_sus/features/config/domain/app_update.dart';

void main() {
  group('compareVersions', () {
    test('equal versions compare as zero', () {
      expect(compareVersions('1.2.0', '1.2.0'), 0);
      expect(compareVersions('0.0.0', '0.0.0'), 0);
    });

    test('orders by major, minor, patch numerically', () {
      expect(compareVersions('2.0.0', '1.9.9'), greaterThan(0));
      expect(compareVersions('1.3.0', '1.2.9'), greaterThan(0));
      expect(compareVersions('1.2.1', '1.2.0'), greaterThan(0));
      expect(compareVersions('1.2.0', '1.2.1'), lessThan(0));
    });

    test('compares numerically, not lexically (1.10 > 1.9)', () {
      expect(compareVersions('1.10.0', '1.9.0'), greaterThan(0));
      expect(compareVersions('1.2.10', '1.2.9'), greaterThan(0));
    });

    test('tolerates a leading v/V prefix', () {
      expect(compareVersions('v1.2.1', '1.2.0'), greaterThan(0));
      expect(compareVersions('V1.2.0', 'v1.2.0'), 0);
    });

    test('treats missing segments as zero (1.2 == 1.2.0)', () {
      expect(compareVersions('1.2', '1.2.0'), 0);
      expect(compareVersions('1.2.0.1', '1.2'), greaterThan(0));
    });

    test('treats non-numeric segments as zero rather than crashing', () {
      expect(compareVersions('1.2.beta', '1.2.0'), 0);
      expect(compareVersions('garbage', '0.0.0'), 0);
    });

    test('drives the update decision the provider makes', () {
      // The banner shows only when latest > installed.
      const installed = '1.2.0';
      expect(compareVersions('9.9.9', installed) > 0, isTrue);
      expect(compareVersions('1.2.0', installed) > 0, isFalse);
      expect(compareVersions('1.1.9', installed) > 0, isFalse);
    });
  });
}
