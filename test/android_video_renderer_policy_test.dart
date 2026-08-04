import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/services/player/android_video_renderer_policy.dart';
import 'package:kazumi/utils/constants.dart';

void main() {
  group('resolveAndroidVideoRenderer', () {
    test('resolves auto to the supported OpenGL output', () {
      expect(resolveAndroidVideoRenderer('auto'), 'gpu');
    });

    test('downgrades a legacy gpu-next setting to gpu', () {
      expect(resolveAndroidVideoRenderer('gpu-next'), 'gpu');
    });

    test('keeps supported explicit renderers unchanged', () {
      expect(resolveAndroidVideoRenderer('gpu'), 'gpu');
      expect(
        resolveAndroidVideoRenderer('mediacodec_embed'),
        'mediacodec_embed',
      );
    });
  });

  test('Android renderer settings do not offer gpu-next', () {
    expect(androidVideoRenderersList, isNot(contains('gpu-next')));
  });
}
