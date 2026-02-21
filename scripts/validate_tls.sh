#!/usr/bin/env bash
# Validate hybrid PQC TLS handshake: start ServiceA, run openssl s_client with
# X25519MLKEM768, parse output for "Server Temp Key" confirming hybrid group.
# Exits 0 on success, non-zero on failure. Run from repo root with certs present.
#
# Requires OpenSSL >= 3.5 (for PQC groups). If your default openssl is older,
# set PREFIX to your OpenSSL 3.5.5 install so both this script and ServiceA use it:
#   PREFIX=/usr/local bash scripts/validate_tls.sh
#   PREFIX=$HOME/.local bash scripts/validate_tls.sh
# Same PREFIX as used for build (see docs/DEPENDENCIES.md and docs/BUILD.md).
#
# Optional: PQC_VALIDATE_USE_OPENSSL_SERVER=1 uses openssl s_server with PQC
# groups instead of ServiceA (useful when gRPC server does not set TLS groups).
# Optional: PQC_VALIDATE_SKIP_START=1 skips starting server; only runs s_client
# against localhost:PORT (for CI when server is already running, e.g. in Docker).

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="${REPO_ROOT}/build"
PORT="${PQC_VALIDATE_PORT:-50051}"
CERTS_DIR="${CERTS_DIR:-$REPO_ROOT/certs}"

# Prefer OpenSSL 3.5.5 from PREFIX (same as install_openssl.sh / build env)
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
  echo "validate_tls: OpenSSL >= 3.5 is required for PQC groups. Found: ${OV:-not found}" >&2
  echo "Install OpenSSL 3.5.5 (e.g. PREFIX=\$HOME/.local bash scripts/install_openssl.sh) and run with:" >&2
  echo "  PREFIX=/usr/local bash scripts/validate_tls.sh   # or PREFIX=\$HOME/.local" >&2
  exit 1
fi

# Ensure cert paths for ServiceA (server) and for s_client (client cert required by server)
export PQC_CERT_PATH="${PQC_CERT_PATH:-$CERTS_DIR/server.pem}"
export PQC_KEY_PATH="${PQC_KEY_PATH:-$CERTS_DIR/server.key}"
export PQC_CA_PATH="${PQC_CA_PATH:-$CERTS_DIR/ca.pem}"
CLIENT_CERT="${PQC_CLIENT_CERT_PATH:-$CERTS_DIR/client.pem}"
CLIENT_KEY="${PQC_CLIENT_KEY_PATH:-$CERTS_DIR/client.key}"

for f in "$PQC_CERT_PATH" "$PQC_KEY_PATH" "$PQC_CA_PATH" "$CLIENT_CERT" "$CLIENT_KEY"; do
  if [ ! -f "$f" ]; then
    echo "validate_tls: certificate file not found: $f" >&2
    echo "Generate certs first: bash scripts/generate_rsa_certs.sh" >&2
    exit 1
  fi
done

USE_OPENSSL_SERVER="${PQC_VALIDATE_USE_OPENSSL_SERVER:-0}"
SKIP_START="${PQC_VALIDATE_SKIP_START:-0}"
SERVER_ADDR="${PQC_VALIDATE_SERVER_ADDR:-localhost:$PORT}"

if [ "$SKIP_START" = "1" ]; then
  # Server already running (e.g. Docker); wait for it to be reachable
  WAIT=0
  TMPOUT="${TMPDIR:-/tmp}/validate_tls_$$.out"
  while [ $WAIT -lt 30 ]; do
    if openssl s_client -connect "$SERVER_ADDR" -cert "$CLIENT_CERT" -key "$CLIENT_KEY" -CAfile "$PQC_CA_PATH" -brief 2>"$TMPOUT" </dev/null >/dev/null; then
      break
    fi
    sleep 1
    WAIT=$((WAIT + 1))
  done
  rm -f "$TMPOUT"
  if [ $WAIT -ge 30 ]; then
    echo "validate_tls: server at $SERVER_ADDR did not become ready" >&2
    exit 1
  fi
  PORT="${SERVER_ADDR#*:}"
elif [ "$USE_OPENSSL_SERVER" = "1" ]; then
  # Use openssl s_server so we can set -groups (gRPC server does not expose SSL_CTX)
  SERVER_LOG="${TMPDIR:-/tmp}/validate_tls_srv_$$.log"
  openssl s_server -accept "$PORT" -cert "$PQC_CERT_PATH" -key "$PQC_KEY_PATH" -CAfile "$PQC_CA_PATH" -groups X25519MLKEM768:x25519 -verify 1 -www 2>"$SERVER_LOG" &
  PID=$!
  cleanup() { kill "$PID" 2>/dev/null || true; wait "$PID" 2>/dev/null || true; rm -f "$SERVER_LOG"; }
  trap cleanup EXIT
  sleep 2
else
  SERVICE_A="${BUILD_DIR}/service_a/service_a"
  if [ ! -x "$SERVICE_A" ]; then
    echo "validate_tls: ServiceA binary not found: $SERVICE_A" >&2
    echo "Build first: cmake -B build && cmake --build build" >&2
    exit 1
  fi
  "$SERVICE_A" --port "$PORT" &
  PID=$!
  cleanup() { kill "$PID" 2>/dev/null || true; wait "$PID" 2>/dev/null || true; }
  trap cleanup EXIT
  WAIT=0
  TMPOUT="${TMPDIR:-/tmp}/validate_tls_$$.out"
  while [ $WAIT -lt 10 ]; do
    if openssl s_client -connect "localhost:$PORT" -cert "$CLIENT_CERT" -key "$CLIENT_KEY" -CAfile "$PQC_CA_PATH" -brief 2>"$TMPOUT" </dev/null >/dev/null; then
      break
    fi
    sleep 1
    WAIT=$((WAIT + 1))
  done
  rm -f "$TMPOUT"
  if [ $WAIT -ge 10 ]; then
    echo "validate_tls: ServiceA did not become ready on port $PORT" >&2
    exit 1
  fi
fi

# Connect with hybrid group and client cert, capture output
CONNECT_ADDR="${SERVER_ADDR:-localhost:$PORT}"
OUT=$(openssl s_client -connect "$CONNECT_ADDR" -cert "$CLIENT_CERT" -key "$CLIENT_KEY" -CAfile "$PQC_CA_PATH" -groups X25519MLKEM768:x25519 -showcerts 2>/dev/null </dev/null || true)

# Success: "Server Temp Key" or "Negotiated TLS1.3 group:" contains hybrid group
# Extract the actual group name (e.g. X25519MLKEM768) for the success message
GROUP=$(echo "$OUT" | grep -E "Server Temp Key|Negotiated TLS1.3 group:" | grep -oE 'X25519MLKEM768|SecP256r1MLKEM768|MLKEM[0-9]+' | head -1)
if [ -z "$GROUP" ]; then
  GROUP="hybrid PQC (MLKEM)"
fi

if echo "$OUT" | grep -q "Server Temp Key"; then
  if echo "$OUT" | grep "Server Temp Key" | grep -qiE 'X25519MLKEM768|MLKEM|ML-KEM'; then
    echo "validate_tls: hybrid PQC group negotiated (Server Temp Key): $GROUP"
    exit 0
  fi
fi
if echo "$OUT" | grep -q "Negotiated TLS1.3 group:"; then
  if echo "$OUT" | grep "Negotiated TLS1.3 group:" | grep -qiE 'X25519MLKEM768|MLKEM|ML-KEM'; then
    echo "validate_tls: hybrid PQC group negotiated (TLS 1.3 group): $GROUP"
    exit 0
  fi
fi

echo "validate_tls: could not confirm hybrid PQC group in s_client output" >&2
echo "validate_tls: TLS handshake is working. Negotiated group was not shown (gRPC server uses OpenSSL default; in OpenSSL 3.5 default is in ssl/t1_lib.c and prefers X25519MLKEM768)." >&2
echo "validate_tls: gRPC C++ does not expose SSL_CTX, so we cannot set groups; OpenSSL default is hardcoded in the library, not in openssl.cnf." >&2
if echo "$OUT" | grep -q "no suitable key share"; then
  echo "validate_tls: server did not offer a matching PQC key share." >&2
fi
echo "validate_tls: To prove hybrid PQC with this project's certs, run: PQC_VALIDATE_USE_OPENSSL_SERVER=1 bash scripts/validate_tls.sh" >&2
echo "Sample output:" >&2
echo "$OUT" | head -80
exit 1
