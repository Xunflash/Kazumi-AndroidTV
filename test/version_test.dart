import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/request/config/api_endpoints.dart';
import 'package:kazumi/utils/version.dart';

void main() {
  group('needUpdate', () {
    test('compares numeric versions', () {
      expect(needUpdate('2.2.6', '2.2.7'), isTrue);
      expect(needUpdate('2.2.6', '2.2.6'), isFalse);
      expect(needUpdate('2.2.6', '2.1.99'), isFalse);
    });

    test('accepts common release tag prefixes and suffixes', () {
      expect(needUpdate('2.2.6', 'v2.2.7'), isTrue);
      expect(needUpdate('2.2.6', '2.2.7-tv.1'), isTrue);
    });

    test('compares Android TV revisions within an upstream version', () {
      expect(needUpdate('2.2.6.1777', '2.2.6.1778-tv.abcdef'), isTrue);
      expect(needUpdate('2.2.6.1778', '2.2.6.1778-tv.abcdef'), isFalse);
    });

    test('rejects tags without a numeric version', () {
      expect(() => needUpdate('2.2.6', 'latest'), throwsFormatException);
    });
  });

  test('uses the compile-time Android TV app version', () {
    const configuredVersion = String.fromEnvironment(
      'KAZUMI_APP_VERSION',
      defaultValue: '2.2.6',
    );
    expect(ApiEndpoints.version, configuredVersion);
  });
}
