# Task: Helper privilegiato — Manifest signing Ed25519 + caller verification

## Obiettivo

Schema di autenticazione caller del daemon basato su keypair Ed25519 generata localmente (no Apple Developer ID richiesto). Il bundle dell'app contiene un manifest JSON con i CDHash autorizzati firmato con private key offline; il daemon verifica la firma con la public key hardcoded prima di accettare le chiamate `writeHosts`. App update → nuovo manifest firmato → helper accetta automaticamente, no re-install.

## Requisiti

- Keypair Ed25519 generata UNA VOLTA, private key offline (out-of-repo), public key embedded nell'helper
- Manifest `cdhash-manifest.json` nel bundle app con lista CDHash autorizzati
- Firma `cdhash-manifest.json.sig` accanto al manifest
- Helper estrae `auditToken` del caller, recupera path bundle, legge manifest+sig, verifica firma con public key, confronta CDHash del caller
- Build phase script che firma il manifest in fase di release (in dev: bypass o auto-sign con dev key)
- Modalità DEBUG: helper accetta qualunque caller (skip verifica, productivity)

## Checklist

- [ ] Script `tools/make-keys.sh` (one-shot) — genera Ed25519 keypair via `openssl genpkey -algorithm ed25519`; output `private.pem` (lo metti tu in posto sicuro, non in repo) + stampa public key in formato hex per copia in source
- [ ] Aggiornare `.gitignore` per escludere `*.pem` e `tools/keys/`
- [ ] In `HostFlowHelper`: `AuthorizedKeys.swift` con `static let publicKey: Data = Data([0x...])` (32 byte hex)
- [ ] Script `tools/sign-manifest.sh` — input: app path, private.pem path; calcola CDHash via `codesign -dvvv`, genera `cdhash-manifest.json`, firma con openssl `pkeyutl -sign`, output `.sig` accanto al manifest, embedded in `Contents/Resources/`
- [ ] Build phase post-codesign nel target `HostFlow`: chiama `sign-manifest.sh` se variabile env `HOSTFLOW_PRIVATE_KEY` è settata; altrimenti genera manifest "dev" con CDHash corrente (auto-self-sign con dev key locale per fluidity)
- [ ] In `HelperService.writeHosts`: prima di scrivere, chiama `verifyCaller(audit:)` privato:
  - estrae bundle path da audit token via `SecCodeCopyGuestWithAttributes`
  - legge `Contents/Resources/cdhash-manifest.json` + `.sig`
  - verifica con `Curve25519.Signing.PublicKey.isValidSignature(_:for:)`
  - confronta CDHash caller (estratto da SecCode) con quelli nel manifest
  - in `#if DEBUG` ritorna sempre `true`
  - in release: ritorna risultato verifica
- [ ] Errore custom `HelperError.unauthorizedCaller` ritornato al chiamante non autorizzato
- [ ] Build verifica + test manuale: app dev → manifest auto-firmato → daemon accetta. Modificare bytes nel manifest → daemon rifiuta.

## Note tecniche

- CryptoKit (`Curve25519.Signing`) disponibile da macOS 11+ (target è 14)
- `SecCodeCopyGuestWithAttributes` richiede import di `Security` framework
- Il CDHash si estrae dal `SecCode` del caller con `SecCodeCopySigningInformation` + key `kSecCodeInfoUnique`
- Manifest format minimale: `{"version": 1, "cdhashes": ["abc...", "def..."]}`
- Private key NON va MAI nel repo. Storage suggerito: 1Password / Bitwarden / file cifrato GPG su disco esterno
- Public key può andare nel repo (è pubblica per natura)

## Out of scope

- Rotation chiave (cambio private key) — task futuro se necessario
- Multi-firma (più chiavi autorizzate) — possibile ma per ora 1 chiave
- Network-fetched manifest (CDN) — esplicitamente rifiutato per security

---

**Completed:** 2026-05-08

**Resolution:** `Scripts/make-keys.sh` (Ed25519 keypair via openssl) + `Scripts/sign-manifest.sh` (CDHash → JSON manifest + Ed25519 sig in Contents/Resources). `AuthorizedKeys.swift` con publicKey hex placeholder, `HelperError` con casi unauthorizedCaller/manifestMissing/manifestInvalid/writeFailed, `CallerVerification` (PID lookup via `kSecGuestAttributePid` invece di auditToken privato; estrae CDHash con `SecCodeCopySigningInformation`, verifica con `Curve25519.Signing.PublicKey`). `HelperListenerDelegate` rifiuta connessioni non autorizzate. Build phase release richiede env `HOSTFLOW_PRIVATE_KEY`; debug bypass totale. `.gitignore` esclude `*.pem` e `Scripts/keys/`.
