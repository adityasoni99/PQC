#!/usr/bin/env bash
# Prove classical-only TLS 1.3 handshake (fallback) using OpenSSL s_server/s_client.
# Same idea as validate_tls.sh with PQC_VALIDATE_USE_OPENSSL_SERVER=1 for hybrid PQC:
# we cannot set groups in gRPC C++, so we use s_server/s_client to verify behaviour.
#
# Test 1 (classical-only): s_server and s_client both use -groups x25519:secp256r1;
#   verifies that classical negotiation works with this project's certs.
# Test 2 (fallback interop): s_server offers X25519MLKEM768:x25519:secp256r1,
#   s_client offers only x25519:secp256r1; verifies handshake succeeds with classical
#   group (client "fallback" — no PQC on client, server agrees on classical).
#
# Requires OpenSSL >= 3.5. Use the same env as build so the script uses OpenSSL 3.5.5:
#   export LD_LIBRARY_PATH="/usr/local/lib:/usr/local/lib64:${LD_LIBRARY_PATH:-}"
#   export PATH="/usr/local/bin:${PATH}"
#   bash scripts/validate_tls_fallback.sh
# If OpenSSL 3.5.5 is in a custom prefix: PREFIX=$HOME/.local bash scripts/validate_tls_fallback.sh
# See docs/BUILD.md "Local testing" and "Proof of classical fallback".
# Run from repo root. Generate certs first: bash scripts/generate_rsa_certs.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PORT="${PQC_VALIDATE_FALLBACK_PORT:-50553}"
CERTS_DIR="${CERTS_DIR:-$REPO_ROOT/certs}"

if [ -n "${PREFIX:-}" ]; then
  export PATH="${PREFIX}/bin:${PATH}"
  export LD_LIBRARY_PATH="${PREFIX}/lib:${PREFIX}/lib64:${LD_LIBRARY_PATH:-}"
fi

version_ge() {
  local v1="$1" v2="$2"
  if [ "$v1" = "$v2" ]; then return 0; fi
  local first
  first=$(printf '%s\n' "$v1" "$v2" | sort -V 2>/dev/null | head -1)
  [ "$first" = "$v2" ]
}

OV=$(openssl version 2>/dev/null | sed -n 's/OpenSSL \([0-9]\+\.[0-9]\+\.[0-9]\+\)[^0-9].*/\1/p')
if [ -z "$OV" ] || ! version_ge "$OV" "3.5.0"; then
  echo "validate_tls_fallback: OpenSSL >= 3.5 required for -groups. Found: ${OV:-not found}" >&2
  echo "Use same PREFIX as build, e.g. PREFIX=/usr/local bash scripts/validate_tls_fallback.sh" >&2
  exit 1
fi

SERVER_PEM="${PQC_CERT_PATH:-$CERTS_DIR/server.pem}"
SERVER_KEY="${PQC_KEY_PATH:-$CERTS_DIR/server.key}"
CA_PEM="${PQC_CA_PATH:-$CERTS_DIR/ca.pem}"
CLIENT_PEM="${PQC_CLIENT_CERT_PATH:-$CERTS_DIR/client.pem}"
CLIENT_KEY="${PQC_CLIENT_KEY_PATH:-$CERTS_DIR/client.key}"

for f in "$SERVER_PEM" "$SERVER_KEY" "$CA_PEM" "$CLIENT_PEM" "$CLIENT_KEY"; do
  if [ ! -f "$f" ]; then
    echo "validate_tls_fallback: cert not found: $f" >&2
    echo "Run: bash scripts/generate_rsa_certs.sh" >&2
    exit 1
  fi
done

# Classical-only group list (no PQC)
CLASSICAL_GROUPS="x25519:secp256r1"
# Server offers hybrid first, then classical (for fallback test)
HYBRID_AND_CLASSICAL_GROUPS="X25519MLKEM768:x25519:secp256r1"

run_s_client() {
  local connect_addr="$1"
  local groups="$2"
  # Capture both stdout and stderr: "Server Temp Key" / "Negotiated TLS1.3 group" may be on stderr
  openssl s_client -connect "$connect_addr" -cert "$CLIENT_PEM" -key "$CLIENT_KEY" \
    -CAfile "$CA_PEM" -groups "$groups" -showcerts 2>&1 </dev/null || true
}

# Extract negotiated group name from s_client output for display (Server Temp Key or Negotiated TLS1.3 group line).
extract_negotiated_group() {
  local out="$1"
  local line group
  line=$(echo "$out" | grep -E "Server Temp Key|Negotiated TLS1.3 group:" | head -1)
  if [ -n "$line" ]; then
    # Server Temp Key: X25519, 253 bits  or  ECDH, prime256v1, 256 bits  or  Negotiated TLS1.3 group: x25519
    group=$(echo "$line" | grep -oEi 'x25519|secp256r1|prime256v1|P-256' | head -1)
    [ -n "$group" ] && echo "$group" && return
  fi
  # Fallback: first classical group name found in output (e.g. from session info)
  group=$(echo "$out" | grep -oEi 'x25519|secp256r1|prime256v1' | head -1)
  [ -n "$group" ] && echo "$group" && return
  echo "classical"
}

check_classical_group() {
  local out="$1"
  # Prefer explicit Server Temp Key or Negotiated TLS1.3 group line
  if echo "$out" | grep -q "Server Temp Key"; then
    if echo "$out" | grep "Server Temp Key" | grep -qiE 'x25519|secp256r1|prime256v1|P-256|ECDH.*256'; then
      return 0
    fi
  fi
  if echo "$out" | grep -q "Negotiated TLS1.3 group:"; then
    if echo "$out" | grep "Negotiated TLS1.3 group:" | grep -qiE 'x25519|secp256r1|prime256v1|P-256'; then
      return 0
    fi
  fi
  # Some builds send session info to stderr; ensure we didn't miss it (no PQC group = classical)
  if echo "$out" | grep -qiE 'x25519|secp256r1|prime256v1'; then
    if ! echo "$out" | grep -qiE 'MLKEM|ML-KEM|X25519MLKEM'; then
      return 0
    fi
  fi
  return 1
}

# ----- Test 1: classical-only (both sides classical) -----
echo "validate_tls_fallback: Test 1 — classical-only (s_server and s_client with $CLASSICAL_GROUPS)"
SERVER_LOG="${TMPDIR:-/tmp}/validate_fallback_srv_$$.log"
openssl s_server -accept "$PORT" -cert "$SERVER_PEM" -key "$SERVER_KEY" \
  -CAfile "$CA_PEM" -groups "$CLASSICAL_GROUPS" -verify 1 -www 2>"$SERVER_LOG" &
PID=$!
cleanup() { kill "$PID" 2>/dev/null || true; wait "$PID" 2>/dev/null || true; rm -f "$SERVER_LOG"; }
trap cleanup EXIT
sleep 2

OUT1=$(run_s_client "localhost:$PORT" "$CLASSICAL_GROUPS")
if ! check_classical_group "$OUT1"; then
  echo "validate_tls_fallback: Test 1 failed — could not confirm classical group" >&2
  echo "$OUT1" | head -40
  exit 1
fi
GROUP1=$(extract_negotiated_group "$OUT1")
echo "validate_tls_fallback: Test 1 passed — classical group negotiated (classical-only mode): $GROUP1"
cleanup
trap - EXIT

# ----- Test 2: fallback interop (server offers hybrid+classical, client classical only) -----
echo "validate_tls_fallback: Test 2 — fallback interop (server $HYBRID_AND_CLASSICAL_GROUPS, client $CLASSICAL_GROUPS)"
SERVER_LOG="${TMPDIR:-/tmp}/validate_fallback_srv_$$.log"
openssl s_server -accept "$PORT" -cert "$SERVER_PEM" -key "$SERVER_KEY" \
  -CAfile "$CA_PEM" -groups "$HYBRID_AND_CLASSICAL_GROUPS" -verify 1 -www 2>"$SERVER_LOG" &
PID=$!
cleanup() { kill "$PID" 2>/dev/null || true; wait "$PID" 2>/dev/null || true; rm -f "$SERVER_LOG"; }
trap cleanup EXIT
sleep 2

OUT2=$(run_s_client "localhost:$PORT" "$CLASSICAL_GROUPS")
if ! check_classical_group "$OUT2"; then
  echo "validate_tls_fallback: Test 2 failed — could not confirm classical group (fallback)" >&2
  echo "$OUT2" | head -40
  exit 1
fi
GROUP2=$(extract_negotiated_group "$OUT2")
echo "validate_tls_fallback: Test 2 passed — classical group negotiated (server offered PQC+classical, client classical only): $GROUP2"

echo "validate_tls_fallback: all fallback checks passed (classical-only and fallback interop)"
exit 0
