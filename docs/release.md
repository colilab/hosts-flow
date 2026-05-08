# Host Flow — Production Release Guide

This document is the operational checklist for producing a signed Release build
of Host Flow that the privileged helper will accept at runtime. It complements
[`helper.md`](./helper.md), which explains *why* the scheme works; here we only
cover *what to run, in what order, and how to verify*.

> The app does **not** use an Apple Developer Team ID. Distribution is direct
> (DMG / `.app` copy). Notarization and App Store submission are out of scope —
> see [`helper.md` §5.4](./helper.md).

---

## 1. Prerequisites

| Tool                         | Used for                                              |
| ---------------------------- | ----------------------------------------------------- |
| Xcode 15+ (Command Line Tools) | `xcodebuild`, `codesign`                            |
| [XcodeGen](https://github.com/yonaskolb/XcodeGen) | regenerates `HostFlow.xcodeproj` from `project.yml` |
| OpenSSL 3.x (LibreSSL works) | Ed25519 keypair + manifest signature                  |
| `shasum`, `xxd`, `PlistBuddy` | bundled with macOS                                   |

```bash
brew install xcodegen
xcodebuild -version    # sanity check
openssl version        # must support Ed25519 (OpenSSL ≥ 1.1.1, LibreSSL ≥ 3.7)
```

The build host must be the one that holds the **Ed25519 private key** — the
release artifact cannot be reproduced anywhere else without it.

---

## 2. One-time setup (per project, per signing identity)

These steps happen **once** when the project is bootstrapped, or whenever the
signing key is rotated (see §6).

### 2.1 Generate the Ed25519 keypair

```bash
./Scripts/make-keys.sh
```

Output:

* `Scripts/keys/private.pem` — the Ed25519 private key.
* `Scripts/keys/public.pem` — the matching public key.
* A printed line of the form:

  ```
  static let publicKeyHex = "<64-hex-chars>"
  ```

### 2.2 Move the private key off the working tree

The private key must **never** be committed. `.gitignore` already excludes
`*.pem` and `Scripts/keys/`, but treat the file like a code-signing identity:

```bash
mkdir -p ~/Documents/keys-vault
mv Scripts/keys/private.pem ~/Documents/keys-vault/hostflow-private.pem
chmod 600 ~/Documents/keys-vault/hostflow-private.pem
```

Recommended storage:

* a 1Password / Bitwarden secure note, **or**
* a GPG-encrypted file on an external disk, **or**
* the macOS Keychain (`security add-generic-password`).

If the key is lost, no further authorized builds can be produced and a key
rotation is required (see §6).

### 2.3 Embed the public key in the daemon

Open [`HostFlow/Helper/AuthorizedKeys.swift`](../HostFlow/Helper/AuthorizedKeys.swift)
and replace the `publicKeyHex` value with the hex string printed by
`make-keys.sh`. Commit this change — the public key is meant to ship inside the
daemon binary.

```swift
enum AuthorizedKeys {
    static let publicKeyHex = "abcdef0123…"   // 64 hex chars, 32 bytes
}
```

> The public key is the **identity of the signing authority** as seen by every
> installed daemon. Changing it requires every user to re-install the helper
> (see §6).

---

## 3. Per-release build

Every release is produced by the wrapper script
[`Scripts/build-release.sh`](../Scripts/build-release.sh). Run it like this:

```bash
export HOSTFLOW_PRIVATE_KEY=~/Documents/keys-vault/hostflow-private.pem
./Scripts/build-release.sh
```

The script enforces a fail-fast contract:

1. Aborts if `HOSTFLOW_PRIVATE_KEY` is unset or the file is missing — an
   unsigned manifest cannot ship by accident.
2. Runs `xcodegen generate` so `project.yml` is the single source of truth for
   the Xcode project.
3. Runs `xcodebuild -configuration Release clean build` with
   `CODE_SIGN_IDENTITY=-` (ad-hoc signing — no Team ID).
4. Locates the produced `HostFlow.app` under `~/Library/Developer/Xcode/DerivedData`.
5. If `codesign -dvvv` does not show a `CDHash`, applies an ad-hoc signature
   itself (`codesign --force --deep --sign -`). This handles the case where
   Xcode skips signing in Release without a team.
6. Invokes [`Scripts/sign-manifest.sh`](../Scripts/sign-manifest.sh):
   * computes `SHA-256` of `Contents/MacOS/<CFBundleExecutable>`,
   * writes `Contents/Resources/binary-hash-manifest.json`,
   * signs it with Ed25519 → `Contents/Resources/binary-hash-manifest.json.sig`.

On success the script prints the absolute path of the produced `.app`.

> **Critical invariant.** Do **not** run `codesign --force` (or any other
> resign step) on the produced `.app` afterwards. Re-signing rewrites the
> Mach-O signature blob, the binary SHA-256 changes, and the manifest goes
> stale. The daemon will then reject the very app you just built. If you need
> to fix anything, re-run `Scripts/build-release.sh` end to end.

---

## 4. Verifying the artifact

A clean release should pass all the checks below. Run them from the project
root with `APP=` set to the path printed by `build-release.sh`.

```bash
APP="/Users/<you>/Library/Developer/Xcode/DerivedData/.../Build/Products/Release/HostFlow.app"
```

### 4.1 The bundle is signed (ad-hoc) and well-formed

```bash
codesign -dvvv "$APP" 2>&1 | grep -E 'Identifier|CDHash|Signature'
codesign --verify --deep --strict --verbose=2 "$APP"
```

Expected: `Signature=adhoc`, a non-empty `CDHash=`, no errors.

### 4.2 The manifest exists and matches the binary

```bash
EXEC=$(/usr/libexec/PlistBuddy -c "Print :CFBundleExecutable" "$APP/Contents/Info.plist")
HASH=$(shasum -a 256 "$APP/Contents/MacOS/$EXEC" | cut -d' ' -f1)
echo "binary  : $HASH"
cat "$APP/Contents/Resources/binary-hash-manifest.json"
```

The `binary` line must appear inside the JSON's `"binaryHashes"` array.

### 4.3 The signature verifies against the embedded public key

```bash
PUB_HEX=$(grep 'publicKeyHex' HostFlow/Helper/AuthorizedKeys.swift \
  | sed -E 's/.*"([0-9a-fA-F]+)".*/\1/')

# Reconstruct an OpenSSL-readable public key from the 32-byte raw form.
{
  printf '\x30\x2a\x30\x05\x06\x03\x2b\x65\x70\x03\x21\x00'
  printf "$PUB_HEX" | xxd -r -p
} | openssl pkey -pubin -inform DER -out /tmp/hostflow-pub.pem

openssl pkeyutl -verify -pubin -inkey /tmp/hostflow-pub.pem -rawin \
  -in  "$APP/Contents/Resources/binary-hash-manifest.json" \
  -sigfile "$APP/Contents/Resources/binary-hash-manifest.json.sig"
```

Expected: `Signature Verified Successfully`.

### 4.4 The bundled daemon plist is in place

```bash
ls "$APP/Contents/Library/LaunchDaemons/"
# expected: com.colilab.hostflow.helper
#           com.colilab.hostflow.helper.plist
```

If the plist is missing, `xcodegen` likely dropped it — see the
`postBuildScripts` workaround note in [`helper.md` §6](./helper.md).

### 4.5 Smoke test on a clean machine (recommended)

1. Copy `HostFlow.app` to `/Applications/` on a Mac that has **never** run
   Host Flow before.
2. Launch it. The first profile/record toggle should display
   `HelperOnboardingSheet` and prompt for administrator credentials.
3. Approve. Confirm `/etc/hosts` is updated and that `Console.app` shows the
   daemon log line `(bytes_written: N)` under subsystem
   `com.colilab.hostflow.helper`.

If the daemon rejects the connection, see §7.

---

## 5. Distribution

Strategy B2 (no Team ID) supports two channels:

### 5.1 Direct copy

```bash
cp -R "$APP" /Applications/
```

The user opens it; Gatekeeper will show the standard *"app downloaded from the
internet"* warning the first time. Right-click → **Open** bypasses it.

### 5.2 DMG

Recommended for hand-off to other users:

```bash
hdiutil create -volname "Host Flow" -srcfolder "$APP" -ov -format UDZO \
  ./HostFlow-<version>.dmg
```

The DMG is **not** notarized; downloaders will need to either right-click →
**Open**, or remove the quarantine attribute manually:

```bash
xattr -dr com.apple.quarantine /Applications/HostFlow.app
```

> **Do not** notarize. Notarization re-signs the bundle (Apple's notary service
> staples a ticket inside the executable's signature blob), invalidating the
> manifest hash. If a notarized distribution is ever required, the helper
> verification scheme has to be redesigned.

---

## 6. Key rotation

Rotate when:

* the private key is suspected of compromise,
* the build host is decommissioned, or
* on a fixed schedule (yearly is a reasonable cadence).

Procedure:

```bash
# 1. New keypair into a fresh directory.
./Scripts/make-keys.sh ./Scripts/keys-new

# 2. Update the embedded public key.
#    Replace publicKeyHex in HostFlow/Helper/AuthorizedKeys.swift.

# 3. Move the new private key out of the repo.
mv Scripts/keys-new/private.pem ~/Documents/keys-vault/hostflow-private-YYYYMMDD.pem
chmod 600 ~/Documents/keys-vault/hostflow-private-YYYYMMDD.pem

# 4. Run the release build with the new key.
export HOSTFLOW_PRIVATE_KEY=~/Documents/keys-vault/hostflow-private-YYYYMMDD.pem
./Scripts/build-release.sh
```

Distribute the new app **and** instruct existing users to reinstall the helper:

> `Settings → Componente di sistema → Disinstalla…` then `Installa…`

The daemon binary is what enforces the embedded public key, so until the user
re-installs the helper, the app signed with the new key will be rejected with
`unauthorizedCaller`.

There is no per-manifest revocation list. A leaked old key remains capable of
producing manifests that pre-rotation daemons accept — relying users must
upgrade.

---

## 7. Troubleshooting

| Symptom                                                         | Likely cause                                                                                  | Fix                                                                                  |
| --------------------------------------------------------------- | --------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------ |
| `ERROR: HOSTFLOW_PRIVATE_KEY env var is required`               | Forgot to export the key path before running `build-release.sh`.                              | `export HOSTFLOW_PRIVATE_KEY=…/hostflow-private.pem` then re-run.                    |
| `ERROR: could not locate built HostFlow.app`                    | `xcodebuild` failed silently or DerivedData lives elsewhere.                                  | Re-run with full output; check `xcodebuild` errors and `~/Library/Developer/Xcode/DerivedData`. |
| `manifestMissing` from the daemon                               | Release was built without running `sign-manifest.sh`, or the bundle was repackaged.           | Re-run `Scripts/build-release.sh` end to end. Do not edit `Contents/Resources/` by hand. |
| `manifestInvalid` from the daemon                               | The embedded `publicKeyHex` does not match the private key used to sign, or the manifest was edited. | Confirm `AuthorizedKeys.swift` matches the key in use; re-build.                     |
| `unauthorizedCaller` from the daemon                            | The app's executable hash is not in the manifest. Often caused by re-codesigning **after** the build. | Re-run `Scripts/build-release.sh`. Never run `codesign --force` post-manifest.       |
| Gatekeeper "App is damaged and can't be opened"                 | Quarantine xattr on a downloaded DMG/app combined with ad-hoc signature.                      | `xattr -dr com.apple.quarantine /Applications/HostFlow.app`.                         |
| Daemon installs but never starts                                | `bootstrap` succeeded but the Mach service name conflicts with a stale registration.          | `sudo launchctl bootout system /Library/LaunchDaemons/com.colilab.hostflow.helper.plist` then reinstall from Settings. |
| `xcodegen generate` fails                                       | Missing or outdated `xcodegen`.                                                               | `brew upgrade xcodegen`; check `project.yml` syntax.                                 |

For deeper inspection, watch the daemon live:

```bash
log stream --predicate 'subsystem == "com.colilab.hostflow.helper"' --info
```

---

## 8. Release checklist (TL;DR)

- [ ] `HOSTFLOW_PRIVATE_KEY` exported and pointing at a readable file
- [ ] `AuthorizedKeys.publicKeyHex` matches the private key in use
- [ ] `./Scripts/build-release.sh` completes without errors
- [ ] §4.1 — `codesign --verify --deep --strict` passes
- [ ] §4.2 — binary SHA-256 appears in `binary-hash-manifest.json`
- [ ] §4.3 — `openssl pkeyutl -verify` returns *Signature Verified Successfully*
- [ ] §4.4 — `Contents/Library/LaunchDaemons/` contains both helper binary and plist
- [ ] §4.5 — smoke test on a clean machine writes `/etc/hosts` successfully
- [ ] No `codesign --force` was run on the bundle after `build-release.sh`
- [ ] DMG (if produced) has not been notarized
