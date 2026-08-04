/// Resolves the Android video output supported by the bundled libmpv build.
///
/// `gpu-next` is kept as an input for compatibility with settings saved by
/// older releases, but libmpv v1.1.5 does not include that video output.
String resolveAndroidVideoRenderer(String configuredRenderer) {
  switch (configuredRenderer) {
    case 'auto':
    case 'gpu-next':
      return 'gpu';
    default:
      return configuredRenderer;
  }
}
