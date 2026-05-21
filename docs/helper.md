# Host Flow Privileged Helper

This document describes the design, implementation, and security model of the
Host Flow privileged helper — the component that performs the actual writes to
`/etc/hosts` on behalf of the (unprivileged) Host Flow GUI app.

---

## 1. Why a separate helper

`/etc/hosts` is owned by `root:wheel` with mode `0644`. A regular user-launched
GUI app cannot write to it, no matter what permissions the user grants in the
Privacy panel — POSIX ownership wins. The standard macOS pattern for this is:

* a small launchd-managed daemon running as `root`,
* exposing a narrow Mach service over XPC,
* receiving requests from the GUI app and performing the privileged operation.

Host Flow follows this pattern. The helper does **one thing only**: accept a
`String` payload, validate the caller, and atomically write the bytes to
`/etc/hosts`. It has no other capabilities.

---

## 2. High-level architecture

```
┌────────────────────────────────────────────────────────────────────┐
│                    Host Flow.app  (user, GUI)                      │
│                                                                    │
│   ProfileStore  ──▶  HostsFileManager  ──▶  HostsXPCClient         │
│                                                       │            │
│                                                       │ NSXPCConn  │
│                                                       │ (mach)     │
└──────────────────────────────────────────────────────│─────────────┘
                                                       │
                          launchd / Mach port broker   │
                                                       │
┌──────────────────────────────────────────────────────│─────────────┐
│                                                       ▼            │
│   HelperListenerDelegate  ──verify──▶  CallerVerification          │
│            │                                                       │
│            ▼                                                       │
│   HelperService.writeHosts  ──▶  atomic rename(2)  ──▶  /etc/hosts │
│                                                                    │
│                  com.colilab.hostflow.helper  (root)               │
└────────────────────────────────────────────────────────────────────┘
```

### Two binaries, one repo

| Target            | Bundle ID                       | Runs as | Purpose                                     |
| ----------------- | ------------------------------- | ------- | ------------------------------------------- |
| `HostFlow`        | `com.colilab.hostflow`          | user    | GUI app, talks to the helper via XPC        |
| `HostFlowHelper`  | `com.colilab.hostflow.helper`   | root    | launchd daemon, performs the actual writes  |

Both targets compile a small `Shared/` source folder that holds the XPC
protocol and shared constants, so the wire contract stays in one place.

### File system layout after install

```
/Library/LaunchDaemons/com.colilab.hostflow.helper.plist     (root:wheel 0644)
/Library/PrivilegedHelperTools/com.colilab.hostflow.helper   (root:wheel 0755)
```

When the daemon is loaded by `launchctl bootstrap system`, launchd starts it on
demand the first time anyone resolves the Mach service
`com.colilab.hostflow.helper`. The plist sets `UserName: root` and registers
the Mach service via the `MachServices` key.

---

## 3. The XPC protocol

The Mach-port-based contract is a single Obj-C protocol shared by both targets:

```swift
// Shared/HostFlowHelperProtocol.swift
@objc public protocol HostFlowHelperProtocol {
    func writeHosts(content: String, reply: @escaping (Error?) -> Void)
}

public enum HostFlowHelperConstants {
    public static let machServiceName = "com.colilab.hostflow.helper"
}
```

### Why `@objc` and a reply block

`NSXPCConnection` is built on the Objective-C runtime. Methods exposed across
an XPC connection must be declared in an `@objc` protocol; in Swift, the
asynchronous "reply block" pattern (`@escaping (Error?) -> Void`) is the
canonical way to surface errors back to the caller because XPC cannot bridge
Swift `throws` directly. On the client side we wrap the call in
`withCheckedThrowingContinuation` to turn it back into `async throws`.

### Why Mach service vs anonymous endpoint

`NSXPCConnection(machServiceName:options:.privileged)` resolves a name that
launchd registered globally on behalf of the daemon. This means:

* The client never has to know the daemon's PID or its socket path.
* Any user on the system can dial the same name; access control is enforced
  by the daemon itself (see §5).
* launchd handles on-demand activation and respawn; if the daemon crashes,
  the next call brings it back automatically.

---

## 4. The connection lifecycle

```
                                        ┌──────────────┐
                                        │ HostsXPCClient │
                                        │  (singleton)  │
                                        └───────┬───────┘
   first call ──▶ connect()  ─create─▶ NSXPCConnection (.privileged)
                                                │
                                                │ remoteObjectInterface
                                                │ remoteObjectProxyWithErrorHandler
                                                │ resume()
                                                │
       ┌────────────────────────────────────────┴─────────────────────────┐
       │                                                                  │
       ▼                                                                  ▼
   writeHosts(_) ──reply─▶ resume continuation               invalidationHandler
       (success/error)                                       interruptionHandler
                                                                   │
                                                                   ▼
                                                            connection = nil
                                                            (next call reconnects)
```

The client is **stateful**: one `NSXPCConnection` per process, kept across
calls. If the daemon is bootout-ed, crashes, or the connection becomes
invalid, both the `invalidationHandler` and `interruptionHandler` run and
clear the cached reference, so the next `writeHosts` call lazily rebuilds
the connection.

The client lives behind a serial `DispatchQueue` so concurrent writes from
SwiftUI views can't race against connection setup/teardown.

---

## 5. Caller verification (the security boundary)

The helper runs as `root`. Anything that can dial
`com.colilab.hostflow.helper` can ask it to overwrite `/etc/hosts` — so the
helper must reject unauthorized callers. Host Flow uses a custom verification
scheme that does **not** rely on an Apple Developer Team ID.

### 5.1 Why not just rely on Team ID

The Apple-canonical solution (see `EvenBetterAuthorizationSample` and
`SMJobBless`) requires:

1. Both the app and the helper to be signed with a Team ID issued by Apple
   ($99/year membership).
2. The helper to embed a `SMAuthorizedClients` Code Requirement in its
   `Info.plist` like `anchor apple generic and certificate leaf[subject.OU] = "TEAMID"`.
3. The OS-level `smjobbless` machinery to enforce the requirement at install
   time and at every connection.

For an open-source local-dev tool we want users to be able to build from
source and run without any Apple Developer membership. Hence the custom
scheme below.

### 5.2 The scheme: Ed25519-signed binary-hash manifest

```
                               ┌─────────────────────────────────────┐
                               │    Build machine (developer)        │
                               │                                     │
                               │   Scripts/build-release.sh:         │
                               │                                     │
                               │   1. xcodebuild Release             │
                               │      → App.app codesigned (ad-hoc)  │
                               │                                     │
                               │   2. shasum -a 256                  │
                               │      Contents/MacOS/HostFlow        │
                               │      → binary SHA-256 hash H        │
                               │                                     │
                               │   3. write binary-hash-manifest.json│
                               │      {"version":1,                  │
                               │       "binaryHashes":["<H>"]}       │
                               │                                     │
                               │   4. openssl pkeyutl -sign          │
                               │      with private.pem (Ed25519)     │
                               │      → binary-hash-manifest.json.sig│
                               │                                     │
                               │   ⚠ NEVER re-codesign after step 4. │
                               │     The embedded signature lives    │
                               │     inside the Mach-O; re-signing   │
                               │     rewrites those bytes and        │
                               │     invalidates H.                  │
                               └─────────────────────────────────────┘
                                          │
                                          │  (both files placed in
                                          ▼   App.app/Contents/Resources/)
                               ┌─────────────────────────────────────┐
                               │   App.app/Contents/Resources/       │
                               │     binary-hash-manifest.json       │
                               │     binary-hash-manifest.json.sig   │
                               └─────────────────────────────────────┘
                                          │
       ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─│─ ─ ─ ─ ─ install/run boundary ─ ─
                                          │
                                          ▼
                ┌──────────────────────────────────────────────────┐
                │   HostFlowHelper (root) — runtime check          │
                │                                                  │
                │   1. Get caller PID from NSXPCConnection         │
                │   2. SecCodeCopyGuestWithAttributes(pid:...)     │
                │   3. SecCodeCopyPath → caller bundle URL         │
                │   4. Read CFBundleExecutable from Info.plist     │
                │   5. SHA256 of <bundle>/Contents/MacOS/<exec>    │
                │   6. Read manifest + .sig from bundle Resources/ │
                │   7. CryptoKit Curve25519.Signing.PublicKey      │
                │      .isValidSignature(.sig, for: manifest)      │
                │   8. SHA256 ∈ manifest.binaryHashes ?            │
                │                                                  │
                │   All checks pass → exportedObject = service     │
                │   Any check fails  → return false (drop conn)    │
                └──────────────────────────────────────────────────┘
```

#### Why hash the binary instead of the bundle CDHash

An earlier iteration of this design used the bundle's **CDHash** (the hash
that `codesign` stamps into the binary's CodeDirectory, summarising the
binary plus every resource file). It hit an unsolvable chicken-and-egg
problem:

1. Build app → codesign → CDHash X stamped into the binary.
2. Write `cdhash-manifest.json` (containing X) into `Contents/Resources/`.
3. Xcode's final codesign phase re-signs the bundle. The new resource list
   now includes the manifest, so a fresh CDHash Y is stamped.
4. Manifest contains X, but the running app's CDHash is Y → mismatch →
   verification always fails.

You cannot break the cycle without doing one of:

* embedding the manifest *outside* the bundle (sidecar files distributed
  alongside `.app`) — UX regression,
* writing a custom `CodeResources` rule that excludes the manifest from
  the seal — modern codesign no longer supports this,
* skipping the final re-signing — leaves the bundle's resource seal
  inconsistent and fights Xcode's build phases.

The chosen alternative is to hash **only the main executable** at
`Contents/MacOS/<CFBundleExecutable>`. Its bytes contain:

* the compiled Mach-O code,
* the embedded code signature (codesign appends a `__LINKEDIT` blob with
  the CodeDirectory and signature data into the binary itself).

Once the binary is signed, its bytes are stable. Adding files to
`Contents/Resources/` does not modify the executable. The cycle vanishes.

The cost is a smaller integrity surface — see §5.4 for what this does
*not* protect.

#### Step-by-step what each piece does

1. **Ed25519 keypair** — generated once with `Scripts/make-keys.sh` via
   `openssl genpkey -algorithm ed25519`. Output:
   * `private.pem` — kept off-repo (1Password, GPG-encrypted external disk).
     `.gitignore` excludes `*.pem` and `Scripts/keys/` defensively.
   * 32-byte raw public key — extracted with
     `openssl pkey -pubout -outform DER | tail -c 32` and pasted into
     `HostFlow/Helper/AuthorizedKeys.swift`. The public key is compiled into
     the daemon binary; rotating it requires rebuilding the daemon and a new
     install.

2. **Binary-hash manifest** — JSON document listing the SHA-256 hashes of
   the main executable that the daemon should accept as callers:
   ```json
   {"version": 2, "binaryHashes": ["<sha256-hex>", ...]}
   ```

   > **Updated for Sparkle (manifest `version: 2`).** The hash is no longer
   > taken over the *whole* executable file. It now covers each Mach-O slice's
   > **signed content region** — the bytes `[0, LC_CODE_SIGNATURE.dataoff)` —
   > computed by [`Scripts/macho-region-hash.py`](../Scripts/macho-region-hash.py).
   > That region is byte-identical before and after `codesign` re-signs, which
   > lets the manifest itself be sealed inside the bundle's code signature
   > (`codesign --verify` passes), so the in-app Sparkle updater accepts the
   > bundle. A universal binary contributes one hash per slice. The whole
   > rationale is in [`release.md` §9.5](./release.md). The sections below that
   > still say "SHA-256 of the executable" should be read as "of its signed
   > region"; the daemon logic in `CallerVerification.swift` and the build-time
   > `sign-manifest.sh` were updated together.

3. **Detached signature** — `Scripts/sign-manifest.sh` runs
   `openssl pkeyutl -sign -rawin` on the manifest bytes, producing
   `binary-hash-manifest.json.sig`. Ed25519 (RFC 8032) is used in its raw
   64-byte detached form; `-rawin` tells OpenSSL not to pre-hash (Ed25519
   is non-prehash by definition).

4. **Build-time injection via `Scripts/build-release.sh`** — the wrapper
   script calls `xcodebuild -configuration Release`, ad-hoc-signs the
   bundle if Xcode didn't (Automatic signing without a Team ID skips
   codesign in Release), then runs `sign-manifest.sh`. Manifest signing is
   driven externally rather than from a Xcode "Run Script" build phase
   because Xcode's final codesign phase always runs *after* user phases —
   the previous CDHash-based approach failed exactly because of this
   ordering. Running the manifest step *after* `xcodebuild` returns
   guarantees the binary bytes are frozen.

5. **Runtime verification** — when a connection arrives, the daemon's
   `HelperListenerDelegate.listener(_:shouldAcceptNewConnection:)` runs
   `CallerVerification.verify()`:
   * `connection.processIdentifier` — caller PID.
   * `SecCodeCopyGuestWithAttributes(nil, [kSecGuestAttributePid: pid], …)`
     resolves a `SecCode` referring to the caller's running process.
   * `SecCodeCopyStaticCode` materialises a `SecStaticCode` over the bundle
     on disk; `SecCodeCopyPath` returns the bundle URL.
   * The daemon reads `Contents/Info.plist` to find `CFBundleExecutable`,
     then computes `SHA256.hash(data:)` over the bytes of
     `Contents/MacOS/<exec>` using CryptoKit.
   * The manifest and signature live next to that binary, in
     `Contents/Resources/binary-hash-manifest.json[.sig]`.
   * `Curve25519.Signing.PublicKey(rawRepresentation: AuthorizedKeys.publicKeyData)
     .isValidSignature(sigData, for: manifestData)` does the Ed25519 verify
     (CryptoKit's implementation is constant-time by construction).
   * Finally, the caller's binary SHA-256 (lowercased hex) must appear in
     `manifest.binaryHashes`.
   * Any failure throws `HelperError.unauthorizedCaller |
     .manifestMissing | .manifestInvalid`; the listener logs via `NSLog`
     and returns `false`, dropping the connection before any service object
     is exposed.

#### Why PID lookup instead of audit token

The strongest identity for an XPC peer is its `audit_token_t`, an opaque
8-word kernel-issued token bound to the connection. With audit tokens the
sequence "find caller, hash caller" is atomic: there is no window between
"who connected" and "whose binary did we hash."

`NSXPCConnection.auditToken` is, however, an **SPI** — it lives in
`<NSXPCConnection_Private.h>`, not in the public header. Swift refuses to
import it. The available workarounds (Obj-C bridging that re-declares the
selector, or `xpc_connection_get_audit_token`) are private API and are
fragile across major macOS releases.

PID lookup (`kSecGuestAttributePid`) is documented and stable, but the PID
of the caller can in theory be reused by the kernel between when the
connection is opened and when we resolve the SecCode — a TOCTOU window.

In Host Flow that window is **rendered harmless by the second-stage check**.
After resolving the SecCode by PID we hash the caller's binary and demand
the hash appear in an Ed25519-signed manifest. To exploit a PID race an
attacker would have to:

1. Win the kernel PID race against a real Host Flow process, **and**
2. Possess the Ed25519 private key (so they could publish a manifest
   listing their attacker binary's hash).

(2) is equivalent to "the security of the whole scheme has already been
broken." The marginal exposure from PID-vs-audit-token is therefore
negligible relative to the gain of staying inside public API. This is an
explicit, documented trade-off; if a future macOS release exposes
`auditToken` publicly we'll switch.

#### The DEBUG bypass

```swift
#if DEBUG
return // accept any caller
#else
// real verification …
#endif
```

In Debug builds the daemon accepts everyone. The rationale:

* Debug builds change the binary on every recompile; a manifest baked at
  link time would be stale within seconds.
* Local development would otherwise need the private key on every
  developer's machine, which is the opposite of what we want.
* Debug builds are not what gets distributed; Release builds enforce the
  full chain.

`Scripts/build-release.sh` is Release-only and refuses to run without
`HOSTFLOW_PRIVATE_KEY` set, so a developer cannot ship an unsigned manifest
by accident.

### 5.3 What the scheme defends against

| Threat                                                          | Defended? |
| --------------------------------------------------------------- | --------- |
| Random user-space process dialing the helper                    | yes — its binary hash is not in the manifest |
| Modified Host Flow executable (trojaned Mach-O)                 | yes — binary SHA-256 changes |
| Repackaged app re-signed with attacker key                      | yes — codesign rewrites the binary's signature blob, hash changes |
| Manifest tampering (swap in attacker's binary hash)             | yes — Ed25519 signature breaks |
| Replay of an old signed manifest after a key rotation           | partial — the daemon embeds the current public key, so manifests signed with the previous key fail. There is no per-manifest revocation list. |
| Running daemon swap (replace binary on disk)                    | partially — binary is `root:wheel 0755`, only root can replace it; an attacker who is already root has by definition won. |
| TOCTOU on PID                                                   | yes — see §5.2 |
| Modification of bundle resources (Info.plist, assets, .strings) | NO — see §5.4 |
| Attacker steals private key                                     | NO — they can publish manifests for any binary. Treat the private key like a code-signing key: keep it offline, rotate on suspected compromise. |

### 5.4 What the scheme does NOT do

* **No bundle integrity.** Because we hash *only* the main executable, an
  attacker who gains write access to `Contents/Resources/` or
  `Contents/Info.plist` without modifying the binary can mutate those files
  and the daemon will still accept the caller. This is acceptable for Host
  Flow only because the bundle does not load any code or security-critical
  data from those locations:
  * No `dlopen`-loaded plug-ins.
  * No `NSLocalizedString` lookups feeding into shell commands, URLs, or
    privileged operations (see the discipline note below).
  * No sidecar JSON / plist files driving runtime behaviour.

  **Discipline going forward:** if you add localisation, configuration
  files, or any runtime-loaded resources, never let their values pilot
  security-critical decisions (paths, commands, URLs, AppleScript inputs,
  authorisation rights). Resources are display-only; constants live in
  Swift source (which *is* hashed). Reviewing this rule whenever the
  bundle layout changes keeps the binary-only check sound.

* **No notarization.** Strategy B2 was chosen specifically to avoid an Apple
  Developer Team ID, so the resulting helper is not notarized and cannot be
  distributed via the App Store. Local builds and direct DMG distribution
  are fine.

* **No multi-signer.** The manifest format supports multiple binary hashes
  (so multiple builds can be authorised simultaneously) but only one
  signing key. Multi-signer support is deliberately deferred.

* **No remote/over-the-network manifest.** The manifest must live on disk
  inside the app bundle; the daemon never fetches anything over the
  network.

---

## 6. Install / uninstall

### Why no SMJobBless / SMAppService

* `SMJobBless` (deprecated since macOS 13) requires a Team ID embedded in
  the helper's `SMAuthorizedClients` field. Excluded by the no-Team-ID
  decision.
* `SMAppService.daemon` is the modern replacement and would let us avoid
  the manual `launchctl` dance, but it also expects the daemon to be
  signed by the same Team ID as the app and registered automatically. With
  ad-hoc signing it works in a degraded mode that's not robust enough for
  production — so we fall back to the plain `launchctl bootstrap system`
  flow.

### The install flow

`HelperInstaller.install()` builds a single bash blob and runs it via:

```bash
osascript -e 'do shell script "<the script>" with administrator privileges'
```

`do shell script … with administrator privileges` is the documented
AppleScript primitive for launching a shell command as root with the
native macOS authentication dialog (the same one shown by `sudo` in
Terminal but rendered by `SecurityAgent`). It is **not** deprecated and
does not require any private API.

The bash blob:

```
cp <bundle>/Contents/Library/LaunchDaemons/com.colilab.hostflow.helper \
   /Library/PrivilegedHelperTools/com.colilab.hostflow.helper
chown root:wheel /Library/PrivilegedHelperTools/com.colilab.hostflow.helper
chmod 755       /Library/PrivilegedHelperTools/com.colilab.hostflow.helper

cp <bundle>/Contents/Library/LaunchDaemons/com.colilab.hostflow.helper.plist \
   /Library/LaunchDaemons/com.colilab.hostflow.helper.plist
chown root:wheel /Library/LaunchDaemons/com.colilab.hostflow.helper.plist
chmod 644       /Library/LaunchDaemons/com.colilab.hostflow.helper.plist

launchctl bootout system <plist> 2>/dev/null || true
launchctl bootstrap system <plist>
```

Notes:

* The bundled binary lives at
  `HostFlow.app/Contents/Library/LaunchDaemons/` because xcodegen
  `dependencies.copy { destination: wrapper, subpath: Contents/Library/LaunchDaemons }`
  puts it there at build time. The plist is copied alongside via a
  `postBuildScripts` phase (xcodegen silently drops `.plist` resource
  entries, so a script phase is the reliable workaround).
* `bootout` before `bootstrap` makes `install()` idempotent — running it
  again over an already-installed daemon swaps the files and re-loads the
  service.

### Uninstall

`HelperInstaller.uninstall()` runs:

```bash
launchctl bootout system /Library/LaunchDaemons/com.colilab.hostflow.helper.plist
rm -f /Library/PrivilegedHelperTools/com.colilab.hostflow.helper
rm -f /Library/LaunchDaemons/com.colilab.hostflow.helper.plist
```

There is intentionally no cleanup of `/etc/hosts.hostflow.bak` or the
managed block in `/etc/hosts` — the user can decide to keep, restore, or
manually edit either. A future task (`29-settings-reset-block`) will
expose a "remove the managed block" action.

### Sandbox trade-off

The GUI app is **not** sandboxed. Spawning `osascript` with administrator
privileges from a sandboxed process is blocked by `taskgated`, and the
no-Team-ID constraint rules out `SMAppService.daemon`. This is the explicit
architectural cost of strategy B2: in exchange for not requiring an Apple
Developer membership we lose the App Store distribution channel and the
extra defence-in-depth of the macOS sandbox. The decision is documented
in this file and in `.task/CHANGELOG.md`.

---

## 7. The atomic write

`HelperService.writeHosts(content:reply:)` is the only privileged operation
the daemon exposes. The implementation is intentionally narrow:

```swift
1. Encode content as UTF-8 → Data
2. If /etc/hosts exists, copy it to /etc/hosts.hostflow.bak (overwriting)
3. Write data to /etc/hosts.hostflow.tmp with .atomic option
4. Apply mode 0644, owner uid 0, gid 0 to the tmp file
5. FileManager.replaceItemAt(/etc/hosts, withItemAt: tmp)
```

### Why two writes

Step 3's `.atomic` option already writes to a sibling temp file and renames,
which guarantees that no partial file is ever observed by readers. Step 5
adds a second swap — this is what places the bytes at `/etc/hosts`
specifically while preserving the directory entry's atomicity (the rename
is a single `rename(2)` syscall under the hood). Together they ensure:

* Concurrent readers (e.g. mDNSResponder reloading hosts) always see either
  the old file or the new file, never a half-written one.
* Permissions and ownership are set on the tmp file *before* the rename, so
  the published `/etc/hosts` is never momentarily mode 0600 or owned by a
  user account.

The backup at `/etc/hosts.hostflow.bak` is overwritten on every write so
exactly one rollback target exists. A "keep N versions" backup is out of
scope.

### What the daemon does **not** do

* It does not parse the content. The app is responsible for assembling a
  valid `/etc/hosts` payload (managed block + everything else); the daemon
  treats the bytes as opaque.
* It does not validate hostnames or IPs; that happens client-side.
* It does not log the contents anywhere — only `(bytes_written: N)` is
  emitted via `os_log`.

---

## 8. Logging

The daemon uses Apple's unified logging via `os_log` with subsystem
`com.colilab.hostflow.helper`, category `service`. To watch the daemon at
runtime:

```bash
log stream --predicate 'subsystem == "com.colilab.hostflow.helper"' --info
```

Or, for historical entries:

```bash
log show --predicate 'subsystem == "com.colilab.hostflow.helper"' --last 1h
```

The app side does not emit structured logs yet; failures surface through
`ProfileStore.lastWriteError` and inline UI.

---

## 9. Build & release procedure

### One-time setup (per project)

```bash
# 1. Generate the keypair (writes Scripts/keys/private.pem, prints the public hex)
./Scripts/make-keys.sh

# 2. Move the private key off the working tree
mv Scripts/keys/private.pem ~/Documents/keys-vault/hostflow-private.pem

# 3. Paste the printed public-key hex into:
#    HostFlow/Helper/AuthorizedKeys.swift  →  publicKeyHex = "…"
```

### Per-release

```bash
export HOSTFLOW_PRIVATE_KEY=~/Documents/keys-vault/hostflow-private.pem
./Scripts/build-release.sh
```

The wrapper runs `xcodegen generate`, `xcodebuild -configuration Release`,
ad-hoc-signs the bundle if Xcode skipped codesign (Automatic signing
without a Team ID does this in Release), then runs `Scripts/sign-manifest.sh`
to compute the binary SHA-256 and write the signed manifest into
`Contents/Resources/`. The script aborts early if `HOSTFLOW_PRIVATE_KEY`
is unset or the file is missing, so an unsigned artifact cannot ship by
accident.

**Critical invariant: never run `codesign --force` on the produced `.app`
afterwards.** Re-signing rewrites the executable's embedded code-signature
blob, which changes its SHA-256, which makes the manifest stale. The
daemon will then reject the very app you just built. If you need to fix
something, re-run `Scripts/build-release.sh` end to end so the manifest
is regenerated against the new binary bytes.

### Key rotation (when needed)

1. `./Scripts/make-keys.sh ./Scripts/keys-new` — generate a fresh key.
2. Replace `publicKeyHex` in `AuthorizedKeys.swift` with the new public hex.
3. Do a Release build (signs the manifest with the new private key).
4. Distribute the new app **and** ensure users re-install the daemon: the
   new app's daemon binary is what enforces the new public key, so until
   the daemon is replaced, callers signed with the new key will be
   rejected. The `Settings → Componente di sistema → Disinstalla…` flow
   followed by `Installa…` does this.

---

## 10. Failure modes & user-visible behaviour

| Scenario                                              | What the user sees                                                |
| ----------------------------------------------------- | ----------------------------------------------------------------- |
| Helper not installed at all                           | `HelperOnboardingSheet` modal on the first profile/record toggle. |
| Helper installed but daemon not registered            | XPC connect fails; `lastWriteError` surfaces "Could not connect…". |
| Manifest missing (Release build without sign step)    | Daemon rejects connection with `manifestMissing`; user sees error. |
| Manifest signature invalid (key mismatch)             | Daemon rejects with `manifestInvalid`. |
| Caller binary hash not in manifest (modified or re-codesigned app) | Daemon rejects with `unauthorizedCaller`. |
| `/etc/hosts` write itself fails (disk full, etc)      | `HelperError.writeFailed` returned to client; alert via UI. |

---

## 11. File map

| Path                                              | Purpose                                              |
| ------------------------------------------------- | ---------------------------------------------------- |
| `Shared/HostFlowHelperProtocol.swift`             | XPC protocol + Mach service name (compiled into both targets) |
| `Helper/main.swift`                               | Daemon entry point: configure listener, run loop |
| `Helper/HelperListenerDelegate.swift`             | Accepts/refuses incoming XPC connections |
| `Helper/HelperService.swift`                      | The actual `writeHosts` implementation |
| `Helper/HelperError.swift`                        | Typed errors (`unauthorizedCaller`, `manifestMissing`, …) |
| `Helper/CallerVerification.swift`                 | PID → SecCode → bundle URL → SHA-256 of main executable → manifest verification |
| `Helper/AuthorizedKeys.swift`                     | Embedded Ed25519 public key (32 byte hex) |
| `Helper/Resources/com.colilab.hostflow.helper.plist` | launchd plist template (copied into the app bundle) |
| `Helpers/HelperInstaller.swift`                   | App-side install/uninstall via osascript |
| `Helpers/HostsXPCClient.swift`                    | App-side XPC client + async/await bridge |
| `Helpers/HostsFileManager.swift`                  | Builds the `/etc/hosts` payload, then delegates to the XPC client |
| `Views/Onboarding/HelperOnboardingSheet.swift`    | First-time install flow |
| `Views/Settings/HelperSettingsSection.swift`      | Settings-level state + install/uninstall buttons |
| `Scripts/make-keys.sh`                            | One-shot Ed25519 keypair generation |
| `Scripts/sign-manifest.sh`                        | Compute SHA-256 of main executable, write manifest, sign with Ed25519 |
| `Scripts/build-release.sh`                        | End-to-end Release build wrapper: xcodebuild + manifest signing |

---

## 12. Glossary

* **Binary hash (this scheme)** — SHA-256 of the bytes of
  `Contents/MacOS/<CFBundleExecutable>`. Stable across copies of the app
  and across post-build manifest writes; changes whenever the executable
  is recompiled or re-codesigned.
* **CDHash** — SHA-256 hash of an app's *CodeDirectory* (covers binary +
  resources + Info.plist). Visible via `codesign -dvvv App.app | grep CDHash`.
  Not used by Host Flow's verification — see §5.2 for why.
* **SecCode / SecStaticCode** — Apple Security framework objects
  representing, respectively, a *running* code instance and a *static*
  view of code on disk. Many introspection APIs require the static form.
* **Mach service** — a name registered with launchd that XPC clients can
  resolve to talk to a daemon without knowing its PID or socket path.
* **Audit token** — an 8-word kernel-issued opaque struct identifying a
  process at the connection level (immutable for the lifetime of that
  process).
* **Ed25519** — RFC 8032 signature scheme over Edwards curve 25519. Fast,
  small (32-byte public keys, 64-byte signatures), and constant-time when
  implemented correctly. CryptoKit's implementation is constant-time.
* **launchd / `launchctl bootstrap`** — macOS's init system. `bootstrap` /
  `bootout` are the modern (post-10.10) verbs for loading and unloading
  services into the system domain.
