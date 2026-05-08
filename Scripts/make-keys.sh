#!/bin/bash
set -euo pipefail

# Generate an Ed25519 keypair for signing the helper's CDHash manifest.
# Run ONCE. Store private.pem out of the repo (1Password / GPG-encrypted external disk).
# Public key (32 bytes hex) goes into Helper/AuthorizedKeys.swift.

OUT_DIR="${1:-Scripts/keys}"
mkdir -p "$OUT_DIR"

PRIV="$OUT_DIR/private.pem"
PUB="$OUT_DIR/public.pem"

if [[ -f "$PRIV" ]]; then
  echo "ERROR: $PRIV already exists. Refusing to overwrite." >&2
  exit 1
fi

openssl genpkey -algorithm ed25519 -out "$PRIV"
openssl pkey -in "$PRIV" -pubout -out "$PUB"

# Extract the raw 32-byte public key from the DER (last 32 bytes of the SubjectPublicKeyInfo).
PUB_HEX=$(openssl pkey -in "$PRIV" -pubout -outform DER | tail -c 32 | xxd -p -c 64)

cat <<EOF

✅ Keypair generated:
  private: $PRIV   ← MOVE THIS OUT OF THE REPO. NEVER COMMIT.
  public:  $PUB

Paste this into Helper/AuthorizedKeys.swift:

  static let publicKeyHex = "$PUB_HEX"

EOF
