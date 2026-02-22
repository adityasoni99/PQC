# Build and test (for humans and subagents)

This project builds with CMake. **Subagents:** read **`tasks/tasks-quantum-safe-grpc-pqc.md`** section **"Build and implementation notes (for subagents)"** before changing CMake, proto, common TLS, or tests. That section documents:

- Why OpenSSL is found first and Protobuf/Abseil use CONFIG
- Where proto code is generated (in `proto/` subdir only)
- That TLS credentials use the stable `Ssl*` API (not experimental TlsKeyMaterialsConfig)
- How `GetNegotiatedGroupName` and tests are wired (non-template overload, `enable_testing()` in root)
- Exact configure/build/test commands and environment variables

## Quick reference

- **Dependencies:** See [docs/DEPENDENCIES.md](DEPENDENCIES.md). Check versions with `scripts/check_installed_versions.sh` (use `LD_LIBRARY_PATH` and `PREFIX` as in the tasks file).
- **Configure and build** (with env so the right OpenSSL/gRPC are used):
  ```bash
  export LD_LIBRARY_PATH="/usr/local/lib:/usr/local/lib64:${LD_LIBRARY_PATH:-}"
  export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:/usr/local/lib64/pkgconfig:${PKG_CONFIG_PATH:-}"
  export PATH="/usr/local/bin:${PATH}"
  cmake -B build -DCMAKE_PREFIX_PATH="/usr/local"
  cmake --build build
  ```
- **Tests:** `ctest --test-dir build --output-on-failure`
- **Local testing — validate hybrid TLS (same env as build):**
  - TLS/PQC availability: `bash scripts/tls_groups_check.sh`
  - Dependency versions: `LD_LIBRARY_PATH="/usr/local/lib:/usr/local/lib64" bash scripts/check_installed_versions.sh`
  - Validate TLS to ServiceA: requires OpenSSL ≥ 3.5 and **the same OpenSSL 3.5.5 used to build** (so ServiceA offers PQC groups). Start ServiceA first (e.g. `./build/service_a/service_a --port 50051`), then with the same env as build:
  ```bash
  export LD_LIBRARY_PATH="/usr/local/lib:/usr/local/lib64:${LD_LIBRARY_PATH:-}"
  export PATH="/usr/local/bin:${PATH}"
  bash scripts/validate_tls.sh
  ```
  - Custom OpenSSL prefix (e.g. if default `openssl` is under 3.5): `PREFIX=$HOME/.local bash scripts/validate_tls.sh`
  - Prove hybrid PQC with a server that explicitly sets groups (no ServiceA needed): `PQC_VALIDATE_USE_OPENSSL_SERVER=1 bash scripts/validate_tls.sh` (use `PQC_VALIDATE_PORT=50551` if port 50051 is in use).
  - Validate classical fallback (s_server/s_client; same env as build so OpenSSL 3.5.5 is used):
  ```bash
  export LD_LIBRARY_PATH="/usr/local/lib:/usr/local/lib64:${LD_LIBRARY_PATH:-}"
  export PATH="/usr/local/bin:${PATH}"
  bash scripts/validate_tls_fallback.sh
  ```
  - Custom OpenSSL prefix: `PREFIX=$HOME/.local bash scripts/validate_tls_fallback.sh`

### Proof of hybrid PQC (quantum-safe TLS)

The following output proves that with OpenSSL 3.5.5 and this project’s RSA certs, the TLS 1.3 handshake negotiates a **hybrid PQC key-exchange group** (e.g. **X25519MLKEM768**), i.e. a quantum-safe key agreement.

**Command (env as in Quick reference):**

```bash
export LD_LIBRARY_PATH="/usr/local/lib:/usr/local/lib64:${LD_LIBRARY_PATH:-}"
export PATH="/usr/local/bin:${PATH}"
PQC_VALIDATE_USE_OPENSSL_SERVER=1 PQC_VALIDATE_PORT=50551 bash scripts/validate_tls.sh
```

**Example success output:**

```
Using default temp DH parameters
ACCEPT
validate_tls: hybrid PQC group negotiated (TLS 1.3 group): X25519MLKEM768
```

The script uses `openssl s_server -groups X25519MLKEM768:x25519` and `openssl s_client -groups X25519MLKEM768:x25519`; the printed group name confirms the negotiated TLS 1.3 group (e.g. **X25519MLKEM768** = X25519 + ML-KEM-768, hybrid PQC).

### Proof of classical fallback

Because gRPC C++ does not expose `SSL_CTX`, we cannot set TLS groups in the services. To **prove classical-only and fallback** with the same s_server/s_client approach, use **the same env as build** (so `openssl` and libs are OpenSSL 3.5.5 from `/usr/local`, not the system default):

```bash
export LD_LIBRARY_PATH="/usr/local/lib:/usr/local/lib64:${LD_LIBRARY_PATH:-}"
export PATH="/usr/local/bin:${PATH}"
bash scripts/validate_tls_fallback.sh
```

This runs two checks: (1) both sides classical-only (`x25519:secp256r1`) → negotiated group is classical; (2) server offers `X25519MLKEM768:x25519:secp256r1`, client offers only `x25519:secp256r1` → handshake succeeds with classical group (fallback interop). On success the script **prints the negotiated group** (e.g. `x25519` or `secp256r1`) for each test.

**Example success output:**

```
validate_tls_fallback: Test 1 — classical-only (s_server and s_client with x25519:secp256r1)
...
validate_tls_fallback: Test 1 passed — classical group negotiated (classical-only mode): x25519
validate_tls_fallback: Test 2 — fallback interop (server X25519MLKEM768:x25519:secp256r1, client x25519:secp256r1)
...
validate_tls_fallback: Test 2 passed — classical group negotiated (server offered PQC+classical, client classical only): x25519
validate_tls_fallback: all fallback checks passed (classical-only and fallback interop)
```

If OpenSSL 3.5.5 is in a custom prefix (e.g. `$HOME/.local`), use that prefix in `PATH` and `LD_LIBRARY_PATH` instead of `/usr/local`, same as for build and `validate_tls.sh`.
