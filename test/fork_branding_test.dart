import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/request/config/api_endpoints.dart';
import 'package:kazumi/utils/constants.dart';

void main() {
  group('Kazumi TV fork branding', () {
    test('local builds use the fork release source', () {
      expect(ApiEndpoints.githubRepository, 'Xunflash/Kazumi');
      expect(ApiEndpoints.usesOfficialGithubRepository, isFalse);
      expect(ApiEndpoints.sourceUrl, 'https://github.com/Xunflash/Kazumi');
      expect(
        ApiEndpoints.latestApp,
        'https://api.github.com/repos/Xunflash/Kazumi/releases/latest',
      );
      expect(
        ApiEndpoints.latestReleasePage,
        'https://github.com/Xunflash/Kazumi/releases/latest',
      );
    });

    test('runtime API identity points back to the fork', () {
      expect(
        bangumiHTTPHeader['user-agent'],
        'Xunflash/Kazumi/${ApiEndpoints.version} (Android TV) '
        '(https://github.com/Xunflash/Kazumi)',
      );
    });
  });
}
