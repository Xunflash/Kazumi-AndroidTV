# Upstream sync and Android TV releases

`upstream-sync.yaml` checks `Predidit/Kazumi:main` after non-documentation pushes
to the fork's `main`, every day at 20:23 UTC (04:23 China Standard Time), and
when started manually. It makes a normal merge commit on `main`; it never resets
or force-pushes the fork. A merge pushed with `GITHUB_TOKEN` does not recursively
start another push workflow; the active sync run invokes the release directly.

When upstream has new commits, the workflow pushes only the merge commit to
`main`. A Release is created only when upstream has published a new semver tag,
such as `2.4.2`. The fork tag is that version plus `-tv`, for example
`2.4.2-tv`. Commits that land between upstream releases update `main` and are
included in the next tagged release; they do not publish a version of their own.
If that exact Release and APK already exist, later sync runs leave the tag where
it is.

The Android-only entry point in `release.yaml` tests and builds that exact
commit, signs and verifies the APK, and only then creates the tag and Release.
It passes the exact commit as `target_commitish`, rather than relying on the
calling workflow's `github.sha`. A run is considered complete only when the
Release contains the expected APK asset. Therefore a later scheduled or manual
run retries a missing Release or missing upload even when there is no new merge.

If the merge conflicts, nothing is pushed. The workflow uploads the conflict
status and diff for 30 days and, when Issues are enabled, creates or updates an
issue linking to the failed run.

## Repository configuration

In **Settings > Actions > General > Workflow permissions**, select **Read and
write permissions**. The workflow uses the repository's short-lived
`GITHUB_TOKEN`; no personal access token is required. A branch ruleset that
forbids GitHub Actions from pushing directly to `main` must explicitly allow the
Actions bot, otherwise the `main` push fails and no tag or Release is created.

GitHub disables Actions on a newly created fork until its owner enables them.
Scheduled workflows only run from the default branch and GitHub may disable
their schedule after 60 days without repository activity. The manual **Run
workflow** trigger remains available after Actions are enabled.

Configure these Actions secrets once so every APK release uses the same Android
certificate and can upgrade an installed version:

- `SIGNING_KEY_BASE64`
- `KEY_ALIAS`
- `KEY_STORE_PASSWORD`

Also set the non-secret repository variable `ANDROID_SIGNER_SHA256` to the
64-character SHA-256 digest of that signing certificate. The release fails if
the signed APK has multiple signers or a different certificate, preventing an
accidental keystore rotation from reaching users.

One way to create and configure the key is shown below. `keytool` prompts for
the password; use the same password for the keystore and key because the
workflow supplies `KEY_STORE_PASSWORD` for both. Never commit the resulting
keystore or its base64 value.

```bash
keytool -genkeypair -v \
  -keystore kazumi-tv-release.p12 \
  -storetype PKCS12 \
  -alias kazumi-tv \
  -keyalg RSA \
  -keysize 4096 \
  -validity 10000

base64 -w 0 kazumi-tv-release.p12 | \
  gh secret set SIGNING_KEY_BASE64 --repo Xunflash/Kazumi-AndroidTV
printf '%s' 'kazumi-tv' | \
  gh secret set KEY_ALIAS --repo Xunflash/Kazumi-AndroidTV
gh secret set KEY_STORE_PASSWORD --repo Xunflash/Kazumi-AndroidTV
keytool -list -v \
  -keystore kazumi-tv-release.p12 \
  -alias kazumi-tv
```

Copy the `SHA256` certificate fingerprint printed by the final command into
the `ANDROID_SIGNER_SHA256` Actions variable. Colons and letter case are
accepted. Store an offline backup of the `.p12` file and its password before
publishing the first APK.

The shared APK verifier runs for PR builds, release builds, and the final signed
artifact. It requires matching ARM32/ARM64 library sets, all required TV native
libraries, no x86 libraries, no unsupported Vulkan dependency, ELF `PT_LOAD`
alignment of at least `0x4000`, and `zipalign -c -P 16 4`. Signed releases must
also have a valid v2-or-newer signature and must not use an Android Debug
certificate. Build Tools 35.0.0 is installed explicitly for these checks.

Keep the signing keystore backed up outside GitHub. Losing or replacing it makes
future APKs unable to update existing installations. The upstream service API
secrets already referenced by `release.yaml` remain optional for compilation,
but features backed by those services may require their values at runtime.
The first APK signed by this key cannot replace an earlier debug-signed APK with
a different certificate; uninstall that debug build once before installing the
stable signed release.

The full multi-platform release path remains available from `release.yaml`.
Automatic upstream synchronization selects `androidOnly`, because the upstream
Windows signing service and Apple build outputs are not owned by this fork. A
manual retry should run `upstream-sync.yaml` again. It keeps the same tag for
the current upstream release and rebuilds only when that Release or its APK is
missing. Usually no manual retry is needed because the next sync run detects a
missing APK asset.

Android TV builds receive `KAZUMI_APP_VERSION` as the upstream release version,
for example `2.4.2`. The GitHub tag is `2.4.2-tv`. Android `versionCode` uses a
separate monotonic mapping with a fixed revision of 1, so one upstream release
always maps to the same code:

```text
build number = major * 10000000 + minor * 100000 + patch * 1000 + 1
universal APK versionCode = build number * 10 + 9
```

The workflow accepts three-part versions with `major <= 20`, `minor <= 99`, and
`patch <= 99`. It fails before building if the result does not exceed the
upstream APK version code or would exceed Android's `2,100,000,000` limit.
