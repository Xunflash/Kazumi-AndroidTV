#!/usr/bin/env bash

set -euo pipefail

apk_path="${1:-}"
if [[ -z "$apk_path" || ! -f "$apk_path" ]]; then
  echo "Usage: $0 path/to/app.apk" >&2
  exit 2
fi

for command_name in unzip readelf; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Required command is unavailable: $command_name" >&2
    exit 2
  fi
done

work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT

abis=(armeabi-v7a arm64-v8a)
required_libraries=(
  libapp.so
  libdartjni.so
  libdatastore_shared_counter.so
  libflutter.so
  libmediakitandroidhelper.so
  libmpv.so
)

for abi in "${abis[@]}"; do
  mapfile -t libraries < <(unzip -Z1 "$apk_path" "lib/$abi/*.so" 2>/dev/null | sort)
  if (( ${#libraries[@]} == 0 )); then
    echo "No native libraries found for $abi" >&2
    exit 1
  fi

  printf '%s\n' "${libraries[@]##*/}" > "$work_dir/$abi-libraries.txt"
  for library in "${required_libraries[@]}"; do
    if ! grep -Fxq "$library" "$work_dir/$abi-libraries.txt"; then
      echo "Missing required library lib/$abi/$library" >&2
      exit 1
    fi
  done

  for library_path in "${libraries[@]}"; do
    library_file="$work_dir/${abi}-$(basename "$library_path")"
    unzip -p "$apk_path" "$library_path" > "$library_file"

    load_count=0
    while IFS= read -r alignment; do
      ((load_count += 1))
      if (( alignment < 0x4000 )); then
        echo "$library_path has PT_LOAD alignment $alignment; at least 0x4000 is required" >&2
        exit 1
      fi
    done < <(readelf -lW "$library_file" | awk '$1 == "LOAD" { print $NF }')
    if (( load_count == 0 )); then
      echo "$library_path has no ELF PT_LOAD segments" >&2
      exit 1
    fi
  done

  mpv_file="$work_dir/${abi}-libmpv.so"
  if readelf -d "$mpv_file" | grep -q 'Shared library: \[libvulkan.so\]'; then
    echo "libmpv for $abi requires libvulkan.so and will not load on older Android TV systems" >&2
    exit 1
  fi
  if readelf -Ws "$mpv_file" \
    | grep -Eq 'UND[[:space:]]+vkGetPhysicalDevice(Properties2|QueueFamilyProperties2)'; then
    echo "libmpv for $abi imports Vulkan 1.1 symbols unavailable on older Android TV systems" >&2
    exit 1
  fi
done

diff -u "$work_dir/armeabi-v7a-libraries.txt" "$work_dir/arm64-v8a-libraries.txt"

unexpected_x86="$(unzip -Z1 "$apk_path" 'lib/x86*/*.so' 2>/dev/null || true)"
if [[ -n "$unexpected_x86" ]]; then
  echo "Unexpected x86 native libraries in ARM universal APK:" >&2
  echo "$unexpected_x86" >&2
  exit 1
fi

zipalign_bin="${ZIPALIGN_BIN:-}"
if [[ -z "$zipalign_bin" ]] && command -v zipalign >/dev/null 2>&1; then
  zipalign_bin="$(command -v zipalign)"
fi
if [[ -z "$zipalign_bin" ]]; then
  zipalign_candidates=()
  for sdk_root in "${ANDROID_HOME:-}" "${ANDROID_SDK_ROOT:-}" /opt/android-sdk; do
    [[ -d "$sdk_root/build-tools" ]] || continue
    for candidate in "$sdk_root"/build-tools/*/zipalign; do
      [[ -x "$candidate" ]] && zipalign_candidates+=("$candidate")
    done
  done
  if (( ${#zipalign_candidates[@]} > 0 )); then
    zipalign_bin="$(printf '%s\n' "${zipalign_candidates[@]}" | sort -V | tail -n 1)"
  fi
fi
if [[ -z "$zipalign_bin" || ! -x "$zipalign_bin" ]]; then
  echo "zipalign was not found; install Android SDK build-tools or set ZIPALIGN_BIN" >&2
  exit 2
fi

"$zipalign_bin" -c -P 16 4 "$apk_path"

if [[ "${REQUIRE_RELEASE_SIGNATURE:-0}" == 1 ]]; then
  apksigner_bin="$(dirname "$zipalign_bin")/apksigner"
  if [[ ! -x "$apksigner_bin" ]]; then
    echo "apksigner was not found next to $zipalign_bin" >&2
    exit 2
  fi

  verification_output="$("$apksigner_bin" verify --verbose --print-certs "$apk_path")"
  echo "$verification_output"
  if ! grep -Eq '^Verified using v[2-9] scheme.*: true$' <<< "$verification_output"; then
    echo "APK must have a valid v2 or newer signature" >&2
    exit 1
  fi
  if grep -Eiq 'certificate DN:.*CN=Android Debug([,]|$)' <<< "$verification_output"; then
    echo "Release APK is signed with an Android Debug certificate" >&2
    exit 1
  fi

  mapfile -t signer_digests < <(
    printf '%s\n' "$verification_output" \
      | awk '
          /^Signer #[0-9]+ certificate SHA-256 digest: / ||
          /^V[0-9]+([.][0-9]+)* Signer( #[0-9]+)?: certificate SHA-256 digest: / {
            sub(/^.*certificate SHA-256 digest: /, "")
            gsub(/[[:space:]:]/, "")
            print tolower($0)
          }
        ' \
      | sort -u
  )
  if (( ${#signer_digests[@]} != 1 )); then
    echo "Expected exactly one APK signer, found ${#signer_digests[@]}" >&2
    exit 1
  fi

  expected_signer="${EXPECTED_SIGNER_SHA256:-}"
  if [[ -n "$expected_signer" ]]; then
    actual_signer="$(printf '%s' "${signer_digests[0]}" | tr '[:upper:]' '[:lower:]' | tr -d ':[:space:]')"
    expected_signer="$(printf '%s' "$expected_signer" | tr '[:upper:]' '[:lower:]' | tr -d ':[:space:]')"
    if [[ ! "$expected_signer" =~ ^[0-9a-f]{64}$ ]]; then
      echo "EXPECTED_SIGNER_SHA256 must contain one SHA-256 certificate digest" >&2
      exit 1
    fi
    if [[ "$actual_signer" != "$expected_signer" ]]; then
      echo "APK signer digest $actual_signer does not match EXPECTED_SIGNER_SHA256" >&2
      exit 1
    fi
  fi
fi

echo "Android TV APK verification passed: $apk_path"
