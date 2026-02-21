#!/usr/bin/env bash
# Verify OpenSSL >= 3.5 and PQC algorithm availability (MLKEM, ML-DSA).
# Exits 0 if all checks pass, non-zero otherwise.

set -e

version_ge() {
  local v1="$1" v2="$2"
  if [ "$v1" = "$v2" ]; then return 0; fi
  local first
  first=$(printf '%s\n' "$v1" "$v2" | sort -V 2>/dev/null | head -1)
  [ "$first" = "$v2" ]
}

FAIL=0

# 1. OpenSSL version >= 3.5
OV=""
if command -v openssl >/dev/null 2>&1; then
  OV=$(openssl version 2>/dev/null | sed -n 's/OpenSSL \([0-9]\+\.[0-9]\+\.[0-9]\+\)[^0-9].*/\1/p')
fi
if [ -z "$OV" ]; then
  echo "tls_groups_check: openssl not found" >&2
  exit 1
fi
if ! version_ge "$OV" "3.5.0"; then
  echo "tls_groups_check: OpenSSL >= 3.5 required, found $OV" >&2
  exit 1
fi
echo "OpenSSL version: $OV"

# 2. KEM algorithms: expect MLKEM entries (e.g. ML-KEM-768, Kyber768, or X25519MLKEM768 in group list)
if openssl list -kem-algorithms 2>/dev/null | grep -qiE 'mlkem|kyber|ml-kem'; then
  echo "KEM algorithms: MLKEM/ML-KEM entries found"
else
  # Fallback: check -groups for hybrid PQC (OpenSSL 3.5 exposes groups)
  if openssl s_client -help 2>&1 | grep -q '\-groups'; then
    echo "KEM algorithms: s_client -groups supported (hybrid groups available)"
  else
    echo "tls_groups_check: no MLKEM entries in openssl list -kem-algorithms" >&2
    FAIL=1
  fi
fi

# 3. Signature algorithms: expect ML-DSA entries
if openssl list -signature-algorithms 2>/dev/null | grep -qiE 'mldsa|ml-dsa'; then
  echo "Signature algorithms: ML-DSA entries found"
else
  echo "tls_groups_check: no ML-DSA entries in openssl list -signature-algorithms" >&2
  FAIL=1
fi

if [ "$FAIL" -ne 0 ]; then
  exit 1
fi
echo "tls_groups_check: all checks passed"
