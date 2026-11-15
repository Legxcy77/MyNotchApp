#!/usr/bin/env bash
set -euo pipefail

CERT_NAME="MyNotchApp Local Dev"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

if security find-identity -v -p codesigning | grep -q "\"$CERT_NAME\""; then
    echo "Code signing identity '$CERT_NAME' already exists and is valid."
    exit 0
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "Creating self-signed code signing certificate '$CERT_NAME'..."
openssl req -x509 -newkey rsa:2048 -nodes \
    -keyout "$TMP_DIR/key.pem" \
    -out "$TMP_DIR/cert.pem" \
    -days 3650 \
    -subj "/CN=$CERT_NAME" \
    -addext "basicConstraints=critical,CA:false" \
    -addext "keyUsage=critical,digitalSignature" \
    -addext "extendedKeyUsage=critical,codeSigning" \
    2>/dev/null

LEGACY_FLAG=""
if openssl pkcs12 -help 2>&1 | grep -q -- "-legacy"; then
    LEGACY_FLAG="-legacy"
fi

# shellcheck disable=SC2086
openssl pkcs12 -export $LEGACY_FLAG \
    -out "$TMP_DIR/identity.p12" \
    -inkey "$TMP_DIR/key.pem" \
    -in "$TMP_DIR/cert.pem" \
    -passout pass:notch-local-dev \
    2>/dev/null

echo "Importing identity into $KEYCHAIN..."
security import "$TMP_DIR/identity.p12" \
    -k "$KEYCHAIN" \
    -P "notch-local-dev" \
    -T /usr/bin/codesign

echo "Trusting certificate for Code Signing (macOS may ask for Touch ID / password)..."
security add-trusted-cert -p codeSign -k "$KEYCHAIN" "$TMP_DIR/cert.pem"

echo "Verifying..."
security find-identity -v -p codesigning | grep "$CERT_NAME"
echo "Done! Now run ./scripts/bundle.sh to sign MyNotchApp.app persistently."

