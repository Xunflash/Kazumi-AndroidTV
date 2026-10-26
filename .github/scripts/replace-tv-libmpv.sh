#!/usr/bin/env bash

# media_kit 83b7ca63 bundles libmpv v1.3.1, which links libvulkan.so and
# Vulkan 1.1 symbols. Older Android TV devices cannot load that library.
# v1.1.5 is 16 KB aligned and does not reference Vulkan. Its JNI helper is
# byte-identical to v1.3.1, so only libmpv.so is replaced.

set -euo pipefail

apk_path="${1:-}"
if [[ -z "$apk_path" || ! -f "$apk_path" ]]; then
  echo "Usage: $0 path/to/app.apk" >&2
  exit 2
fi

python3 - "$apk_path" <<'PY'
import hashlib
import os
import sys
import urllib.request
import zipfile

apk_path = sys.argv[1]
jars = {
    "armeabi-v7a": (
        "https://github.com/Predidit/libmpv-android-video-build/releases/download/v1.1.5/default-armeabi-v7a.jar",
        "4f2545c8678c264f10520d5581ba619278c3df04c9ef3b3316e00f85436418fc",
        "lib/armeabi-v7a/libmpv.so",
    ),
    "arm64-v8a": (
        "https://github.com/Predidit/libmpv-android-video-build/releases/download/v1.1.5/default-arm64-v8a.jar",
        "7bfb400fa1b63b68e8a7272673a993cc37b12ba90c79713c7a02a7ac7e9aa773",
        "lib/arm64-v8a/libmpv.so",
    ),
}

replacements = {}
for abi, (url, expected, entry) in jars.items():
    archive_path = os.path.join(
        os.environ.get("RUNNER_TEMP", "/tmp"),
        f"libmpv-v1.1.5-{abi}.jar",
    )
    if not os.path.exists(archive_path) or hashlib.sha256(
        open(archive_path, "rb").read()
    ).hexdigest() != expected:
        urllib.request.urlretrieve(url, archive_path)
        actual = hashlib.sha256(open(archive_path, "rb").read()).hexdigest()
        if actual != expected:
            raise SystemExit(f"SHA-256 mismatch for {url}: {actual}")
    with zipfile.ZipFile(archive_path) as archive:
        replacements[entry] = archive.read(entry)

temporary = apk_path + ".unaligned"
with zipfile.ZipFile(apk_path) as source, zipfile.ZipFile(
    temporary, "w"
) as output:
    seen = set()
    for info in source.infolist():
        payload = replacements.get(info.filename)
        if payload is None:
            output.writestr(info, source.read(info.filename))
            continue
        replaced = zipfile.ZipInfo(info.filename, info.date_time)
        replaced.compress_type = zipfile.ZIP_STORED
        replaced.external_attr = info.external_attr
        replaced.create_system = info.create_system
        output.writestr(replaced, payload)
        seen.add(info.filename)
missing = set(replacements) - seen
if missing:
    raise SystemExit(f"APK is missing libmpv entries: {sorted(missing)}")
os.replace(temporary, apk_path)
print("Replaced Android libmpv.so with v1.1.5")
PY

zipalign_bin="${ZIPALIGN_BIN:-}"
if [[ -z "$zipalign_bin" ]]; then
  for sdk_root in "${ANDROID_HOME:-}" "${ANDROID_SDK_ROOT:-}" /opt/android-sdk; do
    [[ -d "$sdk_root/build-tools" ]] || continue
    for candidate in "$sdk_root"/build-tools/*/zipalign; do
      [[ -x "$candidate" ]] && zipalign_bin="$candidate"
    done
  done
fi
if [[ -z "$zipalign_bin" || ! -x "$zipalign_bin" ]]; then
  echo "zipalign was not found; install Android SDK build-tools or set ZIPALIGN_BIN" >&2
  exit 2
fi

aligned="${apk_path}.aligned"
"$zipalign_bin" -f -P 16 4 "$apk_path" "$aligned"
mv "$aligned" "$apk_path"
echo "Realigned Android TV APK: $apk_path"
