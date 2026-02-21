#!/usr/bin/env bash
# Build and install OpenSSL 3.5.5 to PREFIX (default: /usr/local with sudo, else $HOME/.local).
# Required for this project's PQC/TLS support. See docs/DEPENDENCIES.md.
#
# Usage:
#   System-wide:  sudo bash scripts/install_openssl.sh
#   User install: PREFIX=$HOME/.local bash scripts/install_openssl.sh
#
# After a user install, add to your environment (e.g. in ~/.bashrc):
#   export PREFIX=$HOME/.local
#   export PATH="$PREFIX/bin:$PATH"
#   export LD_LIBRARY_PATH="$PREFIX/lib:$PREFIX/lib64:${LD_LIBRARY_PATH:-}"

set -e
OPENSSL_VERSION="3.5.5"
REQUIRED_OPENSSL_MIN="3.5.5"
PREFIX="${PREFIX:-/usr/local}"
# For non-root, default to user prefix so we don't prompt for sudo
if [[ $(id -u) -ne 0 && "$PREFIX" == "/usr/local" ]]; then
  PREFIX="${HOME:-/tmp}/.local"
fi
# Use a user-writable build dir when not root to avoid /tmp permission issues
if [[ $(id -u) -eq 0 ]]; then
  BD="${BUILD_DIR:-/tmp/openssl_build}"
else
  BD="${BUILD_DIR:-${HOME:-/tmp}/openssl_build}"
fi
MAKEJOBS="${MAKEJOBS:-$(nproc)}"

version_ge() {
  local v1="$1" v2="$2"
  [[ "$v1" == "$v2" ]] && return 0
  local first
  first=$(printf '%s\n' "$v1" "$v2" | sort -V | head -1)
  [[ "$first" == "$v2" ]]
}

# Check if OpenSSL >= 3.5.5 is already at PREFIX
check_existing() {
  local path_prefix="$1"
  export PATH="${path_prefix}/bin:${PATH}"
  export LD_LIBRARY_PATH="${path_prefix}/lib:${path_prefix}/lib64:${LD_LIBRARY_PATH:-}"
  if command -v openssl &>/dev/null; then
    local ov
    ov=$(openssl version 2>/dev/null | sed -n 's/OpenSSL \([0-9]\+\.[0-9]\+\.[0-9]\+\)[^0-9].*/\1/p')
    if [[ -n "$ov" ]] && version_ge "$ov" "$REQUIRED_OPENSSL_MIN"; then
      echo "OpenSSL $ov (>= $REQUIRED_OPENSSL_MIN) already present at $path_prefix"
      return 0
    fi
  fi
  return 1
}

if [[ -z "${FORCE_INSTALL:-}" ]] && check_existing "$PREFIX"; then
  echo "Skipping install. Use FORCE_INSTALL=1 to reinstall."
  exit 0
fi

echo "=== Installing OpenSSL ${OPENSSL_VERSION} to $PREFIX ==="
mkdir -p "$BD"
cd "$BD"
if [[ ! -f "openssl-${OPENSSL_VERSION}.tar.gz" ]]; then
  echo "=== Downloading OpenSSL ${OPENSSL_VERSION} ==="
  curl -sL "https://github.com/openssl/openssl/releases/download/openssl-${OPENSSL_VERSION}/openssl-${OPENSSL_VERSION}.tar.gz" -o "openssl-${OPENSSL_VERSION}.tar.gz"
fi
echo "=== Extracting ==="
rm -rf "openssl-${OPENSSL_VERSION}"
tar xzf "openssl-${OPENSSL_VERSION}.tar.gz"
cd "openssl-${OPENSSL_VERSION}"

echo "=== Configuring (shared, prefix=$PREFIX) ==="
./Configure linux-x86_64 shared \
  --prefix="$PREFIX" \
  --openssldir="$PREFIX/ssl" \
  -Wl,-rpath,"$PREFIX/lib"

echo "=== Building (-j${MAKEJOBS}) ==="
make -j "$MAKEJOBS"
echo "=== Testing ==="
if ! make test; then
  echo "WARNING: some tests failed; installing anyway (build succeeded)."
fi
echo "=== Installing ==="
make install_sw install_ssldirs

[[ $(id -u) -eq 0 ]] && ldconfig 2>/dev/null || true

echo "=== Verifying ==="
export PATH="${PREFIX}/bin:${PATH}"
export LD_LIBRARY_PATH="${PREFIX}/lib:${PREFIX}/lib64:${LD_LIBRARY_PATH:-}"
openssl version

echo "Done. OpenSSL ${OPENSSL_VERSION} installed to $PREFIX"
if [[ $(id -u) -ne 0 ]] && [[ "$PREFIX" == *".local"* ]]; then
  echo "Add to your environment to use this OpenSSL:"
  echo "  export PATH=\"$PREFIX/bin:\$PATH\""
  echo "  export LD_LIBRARY_PATH=\"$PREFIX/lib:$PREFIX/lib64:\${LD_LIBRARY_PATH:-}\""
fi
