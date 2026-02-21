#!/usr/bin/env bash
# Cross-check installed dependency versions against project requirements.
# Run from repo root. For system-wide install, use: sudo bash scripts/check_installed_versions.sh
# For PREFIX install: PREFIX=$HOME/.local bash scripts/check_installed_versions.sh

set -e
PREFIX="${PREFIX:-/usr/local}"
export PATH="/usr/local/bin:/usr/bin:/bin:${PREFIX}/bin:${PATH}"
export PKG_CONFIG_PATH="${PREFIX}/lib/pkgconfig:${PREFIX}/lib64/pkgconfig:${PKG_CONFIG_PATH:-}"
export LD_LIBRARY_PATH="${PREFIX}/lib:${PREFIX}/lib64:${LD_LIBRARY_PATH:-}"

REQUIRED_OPENSSL_MIN="3.5.5"
REQUIRED_PROTOC="31.1"
REQUIRED_ABSEIL="20250512.1"
REQUIRED_GRPC="1.75.1"

version_ge() {
  local v1="$1" v2="$2"
  [[ "$v1" == "$v2" ]] && return 0
  local first
  first=$(printf '%s\n' "$v1" "$v2" | sort -V | head -1)
  [[ "$first" == "$v2" ]]
}

ok() { printf '  %-10s %-12s (required: %s)  OK\n' "$1" "$2" "$3"; }
fail() { printf '  %-10s %-12s (required: %s)  MISS/FAIL\n' "$1" "$2" "$3"; }

echo "=== Checking versions at PREFIX=$PREFIX ==="
echo ""

# OpenSSL (must use PREFIX libs so 3.5.5 is used when installed there)
OV=""
if command -v openssl &>/dev/null; then
  OV=$(openssl version 2>/dev/null | sed -n 's/OpenSSL \([0-9]\+\.[0-9]\+\.[0-9]\+\)[^0-9].*/\1/p')
fi
if [[ -n "$OV" ]] && version_ge "$OV" "$REQUIRED_OPENSSL_MIN"; then
  ok "OpenSSL" "$OV" ">= $REQUIRED_OPENSSL_MIN"
else
  fail "OpenSSL" "${OV:-not found}" ">= $REQUIRED_OPENSSL_MIN"
fi

# protoc
PV=""
if command -v protoc &>/dev/null; then
  PV=$(protoc --version 2>/dev/null | sed -n 's/.* \([0-9][0-9]*\.[0-9][0-9]*\).*/\1/p')
fi
if [[ "$PV" == "$REQUIRED_PROTOC" ]]; then
  ok "protoc" "$PV" "$REQUIRED_PROTOC"
else
  fail "protoc" "${PV:-not found}" "$REQUIRED_PROTOC"
fi

# Abseil (pkg-config abseil_cpp or absl_base; fallback read .pc file)
AV=""
if pkg-config --exists abseil_cpp 2>/dev/null; then
  AV=$(pkg-config --modversion abseil_cpp 2>/dev/null)
elif pkg-config --exists absl_base 2>/dev/null; then
  AV=$(pkg-config --modversion absl_base 2>/dev/null)
fi
if [[ -z "$AV" ]]; then
  for pc in "${PREFIX}/lib/pkgconfig/absl_base.pc" "${PREFIX}/lib64/pkgconfig/absl_base.pc"; do
    if [[ -r "$pc" ]]; then
      AV=$(sed -n 's/^Version: *//p' "$pc"); break
    fi
  done
fi
if [[ -n "$AV" ]]; then
  if [[ "$AV" == "$REQUIRED_ABSEIL" ]] || [[ "$AV" == "20250512" && "$REQUIRED_ABSEIL" == "20250512.1" ]]; then
    ok "Abseil" "$AV" "$REQUIRED_ABSEIL"
  else
    fail "Abseil" "$AV" "$REQUIRED_ABSEIL"
  fi
else
  fail "Abseil" "not found" "$REQUIRED_ABSEIL"
fi

# gRPC (pkg-config or read .pc)
GV=""
if pkg-config --exists grpc++ 2>/dev/null; then
  GV=$(pkg-config --modversion grpc++ 2>/dev/null)
fi
if [[ -z "$GV" ]]; then
  for pc in "${PREFIX}/lib/pkgconfig/grpc++.pc" "${PREFIX}/lib64/pkgconfig/grpc++.pc"; do
    if [[ -r "$pc" ]]; then
      GV=$(sed -n 's/^Version: *//p' "$pc"); break
    fi
  done
fi
if [[ "$GV" == "$REQUIRED_GRPC" ]]; then
  ok "gRPC" "$GV" "$REQUIRED_GRPC"
else
  fail "gRPC" "${GV:-not found}" "$REQUIRED_GRPC"
fi

echo ""
echo "If OpenSSL shows system (e.g. 3.0.x), set LD_LIBRARY_PATH to PREFIX libs:"
echo "  export LD_LIBRARY_PATH=\"$PREFIX/lib:$PREFIX/lib64:\${LD_LIBRARY_PATH:-}\""
echo "  Then re-run this script."
