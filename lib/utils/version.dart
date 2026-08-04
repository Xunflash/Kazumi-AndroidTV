import 'dart:math';

bool needUpdate(String localVersion, String remoteVersion) {
  final localVersionList = _numericVersionSegments(localVersion);
  final remoteVersionList = _numericVersionSegments(remoteVersion);
  final maxLength = max(localVersionList.length, remoteVersionList.length);
  for (var i = 0; i < maxLength; i++) {
    final localSegment = i < localVersionList.length ? localVersionList[i] : 0;
    final remoteSegment =
        i < remoteVersionList.length ? remoteVersionList[i] : 0;
    if (remoteSegment > localSegment) {
      return true;
    } else if (remoteSegment < localSegment) {
      return false;
    }
  }
  return false;
}

List<int> _numericVersionSegments(String version) {
  final match = RegExp(r'\d+(?:\.\d+)*').firstMatch(version);
  if (match == null) {
    throw FormatException('Invalid version: $version');
  }
  return match.group(0)!.split('.').map(int.parse).toList(growable: false);
}
