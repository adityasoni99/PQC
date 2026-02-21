#!/usr/bin/env bash
# Install gRPC 1.75.1, Protobuf 31.1, and Abseil 20250512.1 to PREFIX (default /usr/local).
# Required for building this project. Full documentation: docs/DEPENDENCIES.md
#
# Versions (must match root CMakeLists.txt and docs/DEPENDENCIES.md):
#   gRPC     1.75.1     (clone with submodules; tarball omits third_party)
#   Protobuf 31.1       https://github.com/protocolbuffers/protobuf/releases/download/v31.1/protobuf-31.1.tar.gz
#   Abseil  20250512.1  https://github.com/abseil/abseil-cpp/releases/download/20250512.1/abseil-cpp-20250512.1.tar.gz
#   OpenSSL 3.5.5+      system or custom; required for PQC/TLS
#
# Usage:
#   System-wide:  sudo bash scripts/install_grpc_deps.sh
#   Custom prefix: PREFIX=$HOME/.local bash scripts/install_grpc_deps.sh
#   The script checks PREFIX for required versions first; skip with FORCE_INSTALL=1.
#
# If you see "libssl.so.3: cannot open shared object file", restore it first as root:
#   cp -a /lib/x86_64-linux-gnu/libssl.so.3.bak /lib/x86_64-linux-gnu/libssl.so.3
#   cp -a /usr/lib/x86_64-linux-gnu/libssl.so.3.bak /usr/lib/x86_64-linux-gnu/libssl.so.3
#   ldconfig

set -e
export DEBIAN_FRONTEND=noninteractive
PREFIX="${PREFIX:-/usr/local}"
BD="${BUILD_DIR:-/tmp/pqc_deps_build}"
MAKEJOBS="${MAKEJOBS:-$(nproc)}"

# Required versions (must match root CMakeLists.txt and docs/DEPENDENCIES.md)
REQUIRED_PROTOC_VERSION="31.1"
REQUIRED_ABSEIL_VERSION="20250512.1"
REQUIRED_GRPC_VERSION="1.75.1"
REQUIRED_OPENSSL_MIN="3.5.5"

# Returns 0 if $1 >= $2 (version comparison, e.g. 3.5.5 >= 3.5.5)
version_ge() {
  local v1="$1" v2="$2"
  [[ "$v1" == "$v2" ]] && return 0
  local first
  first=$(printf '%s\n' "$v1" "$v2" | sort -V | head -1)
  [[ "$first" == "$v2" ]]
}

# Check if required dependency versions are already installed at PREFIX
check_versions() {
  local path_prefix="$1"
  export PATH="${path_prefix}/bin:${PATH}"
  export PKG_CONFIG_PATH="${path_prefix}/lib/pkgconfig:${path_prefix}/lib64/pkgconfig:${PKG_CONFIG_PATH:-}"

  local protoc_ok=0
  local abseil_ok=0
  local grpc_ok=0
  local openssl_ok=0

  if command -v openssl &>/dev/null; then
    local ov
    ov=$(openssl version 2>/dev/null | sed -n 's/OpenSSL \([0-9]\+\.[0-9]\+\.[0-9]\+\)[^0-9].*/\1/p')
    if [[ -n "$ov" ]] && version_ge "$ov" "$REQUIRED_OPENSSL_MIN"; then
      openssl_ok=1
    fi
  fi

  if command -v protoc &>/dev/null; then
    local pv
    pv=$(protoc --version 2>/dev/null | sed -n 's/.* \([0-9][0-9]*\.[0-9][0-9]*\).*/\1/p')
    if [[ "$pv" == "$REQUIRED_PROTOC_VERSION" ]]; then
      protoc_ok=1
    fi
  fi

  if pkg-config --exists abseil_cpp 2>/dev/null; then
    local av
    av=$(pkg-config --modversion abseil_cpp 2>/dev/null)
    if [[ "$av" == "$REQUIRED_ABSEIL_VERSION" ]]; then
      abseil_ok=1
    fi
  fi

  if pkg-config --exists grpc++ 2>/dev/null; then
    local gv
    gv=$(pkg-config --modversion grpc++ 2>/dev/null)
    if [[ "$gv" == "$REQUIRED_GRPC_VERSION" ]]; then
      grpc_ok=1
    fi
  fi

  if [[ $openssl_ok -eq 1 && $protoc_ok -eq 1 && $abseil_ok -eq 1 && $grpc_ok -eq 1 ]]; then
    echo "=== Required versions already installed at $path_prefix ==="
    echo "  OpenSSL: >= $REQUIRED_OPENSSL_MIN  (openssl version)"
    echo "  protoc:  $REQUIRED_PROTOC_VERSION"
    echo "  abseil:  $REQUIRED_ABSEIL_VERSION"
    echo "  grpc++:  $REQUIRED_GRPC_VERSION"
    echo "Skipping install. To force reinstall, use: FORCE_INSTALL=1 bash $0"
    return 0
  fi
  return 1
}

if [[ -z "${FORCE_INSTALL:-}" ]] && check_versions "$PREFIX"; then
  exit 0
fi

# Allow non-root only when installing to a custom prefix
if [[ $(id -u) -ne 0 && "$PREFIX" == "/usr/local" ]]; then
  echo "For system-wide install run as root: sudo bash $0"
  echo "Or use a custom prefix: PREFIX=\$HOME/.local bash $0"
  exit 1
fi

# Ensure standard paths so build tools are found (e.g. when run with sudo)
export PATH="/usr/local/bin:/usr/bin:/bin:${PREFIX}/bin:${PATH}"
export LD_LIBRARY_PATH="${PREFIX}/lib:${PREFIX}/lib64:${LD_LIBRARY_PATH:-}"

# Require build tools
for cmd in cmake curl gcc g++ git; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "ERROR: Required build tool '$cmd' not found in PATH."
    echo "Install with: sudo apt-get update && sudo apt-get install -y build-essential cmake curl git"
    exit 1
  fi
done

# Require OpenSSL 3.5.5+ for the build (gRPC links against system/custom OpenSSL).
# Prefer OpenSSL at PREFIX so a user install (e.g. PREFIX=$HOME/.local) is used when present.
if command -v openssl &>/dev/null; then
  ov=$(openssl version 2>/dev/null | sed -n 's/OpenSSL \([0-9]\+\.[0-9]\+\.[0-9]\+\)[^0-9].*/\1/p')
  if [[ -z "$ov" ]] || ! version_ge "$ov" "$REQUIRED_OPENSSL_MIN"; then
    echo "ERROR: OpenSSL >= $REQUIRED_OPENSSL_MIN is required (found: ${ov:-none})."
    echo "Install OpenSSL 3.5.5+ to $PREFIX first: PREFIX=$PREFIX bash scripts/install_openssl.sh"
    echo "Then re-run this script with the same PREFIX."
    exit 1
  fi
  echo "OpenSSL $ov (>= $REQUIRED_OPENSSL_MIN) found."
else
  echo "ERROR: OpenSSL not found. OpenSSL >= $REQUIRED_OPENSSL_MIN is required for PQC/TLS."
  echo "Install it first: PREFIX=$PREFIX bash scripts/install_openssl.sh"
  exit 1
fi

echo "=== Removing incompatible apt packages ==="
if [[ $(id -u) -eq 0 ]]; then
  apt-get remove -y \
    libgrpc++-dev libgrpc-dev protobuf-compiler-grpc \
    libprotobuf-dev protobuf-compiler \
    libgrpc++1.51t64 libgrpc29t64 \
    libprotobuf-lite32t64 libprotobuf32t64 \
    2>/dev/null || true
  apt-get autoremove -y 2>/dev/null || true
else
  echo "Skipping apt remove (non-root; install to $PREFIX)"
fi

echo "=== Build directory: $BD ==="
rm -rf "$BD"
mkdir -p "$BD"
cd "$BD"

# ----- Abseil 20250512.1 -----
echo "=== Downloading Abseil 20250512.1 ==="
curl -sL https://github.com/abseil/abseil-cpp/releases/download/20250512.1/abseil-cpp-20250512.1.tar.gz -o abseil.tar.gz
tar xzf abseil.tar.gz
cd abseil-cpp-20250512.1

echo "=== Building and installing Abseil ==="
cmake -B build \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DCMAKE_BUILD_TYPE=Release \
  -DABSL_ENABLE_INSTALL=ON
cmake --build build -j "$MAKEJOBS"
cmake --install build
cd "$BD"

# ----- Protobuf 31.1 -----
echo "=== Downloading Protobuf 31.1 ==="
curl -sL https://github.com/protocolbuffers/protobuf/releases/download/v31.1/protobuf-31.1.tar.gz -o protobuf.tar.gz
tar xzf protobuf.tar.gz
cd protobuf-31.1

echo "=== Building and installing Protobuf ==="
cmake -B build \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_PREFIX_PATH="$PREFIX" \
  -Dprotobuf_BUILD_TESTS=OFF \
  -Dprotobuf_ABSL_PROVIDER=package
cmake --build build -j "$MAKEJOBS"
cmake --install build
cd "$BD"

# ----- gRPC 1.75.1 (clone with submodules; tarball omits third_party) -----
echo "=== Cloning gRPC v1.75.1 with submodules ==="
if [[ ! -d grpc-1.75.1 ]]; then
  git clone --depth 1 --branch v1.75.1 https://github.com/grpc/grpc.git grpc-1.75.1
  cd grpc-1.75.1
  git submodule update --init --recursive
  cd "$BD"
fi
cd grpc-1.75.1

echo "=== Building and installing gRPC ==="
cmake -B build \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_PREFIX_PATH="$PREFIX" \
  -DgRPC_INSTALL=ON \
  -DgRPC_BUILD_TESTS=OFF \
  -DgRPC_PROTOBUF_PROVIDER=package \
  -DgRPC_ABSL_PROVIDER=package \
  -DgRPC_SSL_PROVIDER=package \
  -DgRPC_ZLIB_PROVIDER=package \
  -DgRPC_CARES_PROVIDER=module \
  -DgRPC_RE2_PROVIDER=module
cmake --build build -j "$MAKEJOBS"
cmake --install build
cd "$BD"

echo "=== Updating dynamic linker cache ==="
[[ $(id -u) -eq 0 ]] && ldconfig || true

echo "=== Verifying installations ==="
# Version checks
echo "OpenSSL: $(openssl version 2>/dev/null || echo 'not found')"
"$PREFIX/bin/protoc" --version
echo "Abseil: $(pkg-config --modversion abseil_cpp 2>/dev/null || echo 'ok')"
echo "gRPC:   $(pkg-config --modversion grpc++ 2>/dev/null || echo 'ok')"
# Verify shared library resolution (ldd) for key binaries
for exe in "$PREFIX/bin/protoc" "$PREFIX/bin/grpc_cpp_plugin"; do
  if [[ -x "$exe" ]]; then
    unresolved=$(ldd "$exe" 2>/dev/null | grep -E 'not found' || true)
    if [[ -n "$unresolved" ]]; then
      echo "ERROR: $exe has unresolved libraries:"
      echo "$unresolved"
      exit 1
    fi
    echo "ldd OK: $exe"
  fi
done
echo "Done. Installed to $PREFIX"
