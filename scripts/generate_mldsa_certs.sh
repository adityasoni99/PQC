#!/usr/bin/env bash
# Generate ML-DSA-65 CA, server, and client certificates (OpenSSL >= 3.5).
# Output: certs/mldsa/ (ca.pem, ca.key, server.pem, server.key, client.pem, client.key).

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CERTS_DIR="${REPO_ROOT}/certs/mldsa"
DAYS=365
SUBJ_CA="/CN=PQC-MLDSA-CA"
SUBJ_SERVER="/CN=localhost"
SUBJ_CLIENT="/CN=PQC-MLDSA-Client"

# Require OpenSSL >= 3.5 for ML-DSA
version_ge() {
  local v1="$1" v2="$2"
  if [ "$v1" = "$v2" ]; then return 0; fi
  local first
  first=$(printf '%s\n' "$v1" "$v2" | sort -V 2>/dev/null | head -1)
  [ "$first" = "$v2" ]
}

OV=""
if command -v openssl >/dev/null 2>&1; then
  OV=$(openssl version 2>/dev/null | sed -n 's/OpenSSL \([0-9]\+\.[0-9]\+\.[0-9]\+\)[^0-9].*/\1/p')
fi
if [ -z "$OV" ] || ! version_ge "$OV" "3.5.0"; then
  echo "Error: OpenSSL >= 3.5 is required for ML-DSA. Found: ${OV:-not found}" >&2
  exit 1
fi

# Algorithm name: OpenSSL 3.5 uses ML-DSA-65 (or mldsa65 in some builds)
MLDSA_ALG=""
for alg in "ML-DSA-65" "mldsa65" "MLDSA65"; do
  if openssl genpkey -algorithm "$alg" -out /dev/null 2>/dev/null; then
    MLDSA_ALG="$alg"
    break
  fi
done
if [ -z "$MLDSA_ALG" ]; then
  echo "Error: ML-DSA-65 key generation not available. Try: openssl list -signature-algorithms" >&2
  exit 1
fi

mkdir -p "$CERTS_DIR"
cd "$CERTS_DIR"

# CA: ML-DSA-65
openssl genpkey -algorithm "$MLDSA_ALG" -out ca.key
openssl req -new -x509 -key ca.key -out ca.pem -days "$DAYS" -subj "$SUBJ_CA"

# Server: ML-DSA-65, signed by CA
openssl genpkey -algorithm "$MLDSA_ALG" -out server.key
openssl req -new -key server.key -out server.csr -subj "$SUBJ_SERVER"
openssl x509 -req -in server.csr -CA ca.pem -CAkey ca.key -CAcreateserial -out server.pem -days "$DAYS"
rm -f server.csr

# Client: ML-DSA-65, signed by CA
openssl genpkey -algorithm "$MLDSA_ALG" -out client.key
openssl req -new -key client.key -out client.csr -subj "$SUBJ_CLIENT"
openssl x509 -req -in client.csr -CA ca.pem -CAkey ca.key -CAcreateserial -out client.pem -days "$DAYS"
rm -f client.csr
rm -f ca.srl

echo "ML-DSA certificates written to $CERTS_DIR"
echo "  CA:       ca.pem, ca.key"
echo "  Server:   server.pem, server.key"
echo "  Client:   client.pem, client.key"
echo "  Set:      PQC_CERT_PATH=$CERTS_DIR/server.pem PQC_KEY_PATH=$CERTS_DIR/server.key PQC_CA_PATH=$CERTS_DIR/ca.pem"
