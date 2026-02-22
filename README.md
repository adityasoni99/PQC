# Quantum-Safe gRPC PQC Microservices

C++ gRPC microservices with **hybrid post-quantum (PQC) key exchange** over TLS 1.3. Two services communicate over TLS; the shared TLS library supports hybrid PQC groups (e.g. X25519MLKEM768) when built with OpenSSL 3.5.5+ and is designed to support classical fallback once the gRPC C++ API allows configuring TLS groups (today group selection follows OpenSSL defaults).

## Overview

This project provides:

- **ServiceA** — gRPC server exposing a `ProcessData` RPC; reports the negotiated TLS group in the response.
- **ServiceB** — gRPC server and client: accepts `ForwardRequest` and calls ServiceA over TLS, returning both sides’ negotiated groups.

All TLS configuration (certificate loading, credential creation, optional PQC) lives in a common library used by both services and by tests.

```
    +-----------+                    +-----------+
    | ServiceB  | ---- TLS 1.3 ----->| ServiceA  |
    | :50052    |   (hybrid PQC)     | :50051    |
    +-----------+                    +-----------+
         ^
         | TLS (client certs)
         |
    [ clients ]
```

## Prerequisites

| Requirement | Version / notes |
|-------------|-----------------|
| **OpenSSL** | 3.5.5 or newer (for PQC groups; see [docs/DEPENDENCIES.md](docs/DEPENDENCIES.md)) |
| **CMake** | 3.22 or newer |
| **C++ compiler** | C++17 (GCC 11+ or Clang 14+) |
| **gRPC / Protobuf / Abseil** | gRPC 1.75.1, Protobuf 31.1, Abseil 20250512.1 (system-installed; use `scripts/install_grpc_deps.sh`) |
| **Docker** | Optional, for containerized build and e2e |

See [docs/DEPENDENCIES.md](docs/DEPENDENCIES.md) and [docs/BUILD.md](docs/BUILD.md) for install order and version checks.

## Build instructions

### Local build

Set the environment so CMake and the runtime use the same OpenSSL and gRPC install (e.g. `/usr/local` or `$HOME/.local`):

```bash
export LD_LIBRARY_PATH="/usr/local/lib:/usr/local/lib64:${LD_LIBRARY_PATH:-}"
export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:/usr/local/lib64/pkgconfig:${PKG_CONFIG_PATH:-}"
export PATH="/usr/local/bin:${PATH}"
cmake -B build -DCMAKE_PREFIX_PATH="/usr/local"
cmake --build build
```

If OpenSSL 3.5.5 is in a custom prefix:

```bash
cmake -B build -DCMAKE_PREFIX_PATH="/usr/local" -DOPENSSL_ROOT_DIR=/path/to/openssl-3.5.5
cmake --build build
```

### Docker build and run

From the repository root (use `--project-directory .` so build context and volume paths resolve correctly):

```bash
bash scripts/generate_rsa_certs.sh
chmod 644 certs/*.key certs/ca.key   # so containers can read keys from the bind mount
docker compose -f docker/docker-compose.yml --project-directory . build
docker compose -f docker/docker-compose.yml --project-directory . up
```

Generate certificates first; the compose file mounts `./certs` into the containers. ServiceB is configured to call ServiceA at `service_a:50051` on the Docker network. Server certs include SANs for `localhost`, `service_a`, and `service_b` so TLS verification works from the host and between containers.

**Test TLS exchange:** With the stack running, call ServiceB and inspect the TLS path (client → ServiceB → ServiceA):

```bash
docker run --rm --network host \
  -v "$(pwd)/certs:/certs:ro" -v "$(pwd)/proto:/proto:ro" \
  fullstorydev/grpcurl:latest \
  -cert /certs/client.pem -key /certs/client.key -cacert /certs/ca.pem \
  -d '{"payload":"test"}' -import-path /proto -proto /proto/service_b.proto \
  localhost:50052 pqc.serviceb.ServiceB/ForwardRequest
```

You should see a JSON response with `result`, `serviceAGroup`, and `serviceBGroup` (group names may show as `unknown` if the runtime does not expose the negotiated TLS group).

## Certificate generation

Certificates are required for TLS (server and client auth). Generate RSA certs into `certs/`:

```bash
chmod +x scripts/*.sh
bash scripts/generate_rsa_certs.sh
```

This creates a CA, server, and client keys/certs in `certs/` (e.g. `ca.pem`, `server.pem`, `server.key`, `client.pem`, `client.key`). Use the same directory for local runs (via `PQC_CERT_PATH`, `PQC_KEY_PATH`, `PQC_CA_PATH`) and for Docker (volume mount).

For ML-DSA (PQC) certificates (future phase):

```bash
bash scripts/generate_mldsa_certs.sh
```

Output goes to `certs/mldsa/`. The script checks that OpenSSL ≥ 3.5 is available.

## Hybrid PQC configuration

- **TLS 1.3 groups:** The intended order is hybrid PQC first, then classical fallback, e.g. `X25519MLKEM768:SecP256r1MLKEM768:x25519:secp256r1`. This is typically applied by calling **`SSL_CTX_set1_groups_list()`** on the underlying OpenSSL context.
- **gRPC C++ limitation:** The gRPC C++ API in 1.75.1 does **not** expose the underlying `SSL_CTX`, so the common TLS library cannot set the group list. Credentials use the stable `grpc::SslServerCredentialsOptions` / `grpc::SslCredentialsOptions` only; group selection follows **OpenSSL defaults**. The `pqc_enabled` parameter is accepted but has no effect until the API allows configuring groups.
- **Is the TLS exchange PQC-safe today?** ServiceA and ServiceB use **OpenSSL’s default TLS 1.3 groups** (we cannot set them; gRPC C++ does not expose `SSL_CTX`). In **OpenSSL 3.5**, that default is **hardcoded in the library** (`ssl/t1_lib.c`, macro `TLS_DEFAULT_GROUP_LIST`) and **prefers hybrid PQC first**: `X25519MLKEM768`, then `X25519`, then `secp256r1`, etc. So with OpenSSL 3.5.5 on both sides, connections **may already negotiate X25519MLKEM768**. The default is **not** read from `openssl.cnf`; it is in code. See [docs/PQC_FAQ.md](docs/PQC_FAQ.md) and **Proving PQC handshake** below.
- **Proving PQC handshake:** To confirm that OpenSSL 3.5.5 can negotiate hybrid PQC with this project’s certs, run the validation script against **OpenSSL’s s_server** (which allows `-groups`):  
  `PQC_VALIDATE_USE_OPENSSL_SERVER=1 bash scripts/validate_tls.sh`
- **Proving classical fallback:** Because gRPC C++ does not expose `SSL_CTX`, we cannot set groups in the services; the same way we prove hybrid PQC with s_server/s_client, we can **prove classical-only and fallback** with **`scripts/validate_tls_fallback.sh`**. It runs s_server and s_client with classical-only groups (`x25519:secp256r1`) and with server offering PQC+classical and client classical-only (fallback interop). On success it **prints the negotiated group** (e.g. `x25519` or `secp256r1`). Requires OpenSSL ≥ 3.5; use the same `PREFIX` as for build if needed: `PREFIX=/usr/local bash scripts/validate_tls_fallback.sh`.
- **When the API allows it:** A future implementation would use `pqc_enabled=true` to set the hybrid list and `pqc_enabled=false` for classical-only (e.g. `x25519:secp256r1`).

## Testing

### Local testing (same env as build)

Use the same `LD_LIBRARY_PATH`, `PKG_CONFIG_PATH`, and `PATH` as for the build (see [docs/BUILD.md](docs/BUILD.md)) so OpenSSL 3.5.5 and gRPC are used.

- **Unit and integration tests:**
  ```bash
  export LD_LIBRARY_PATH="/usr/local/lib:/usr/local/lib64:${LD_LIBRARY_PATH:-}"
  export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:/usr/local/lib64/pkgconfig:${PKG_CONFIG_PATH:-}"
  export PATH="/usr/local/bin:${PATH}"
  ctest --test-dir build --output-on-failure
  ```

- **Check OpenSSL and PQC algorithm availability:**
  ```bash
  bash scripts/tls_groups_check.sh
  ```
  (Use the same `PATH` / `PREFIX` as for build so OpenSSL 3.5.5 is used.)

- **Check installed dependency versions:**
  ```bash
  LD_LIBRARY_PATH="/usr/local/lib:/usr/local/lib64" bash scripts/check_installed_versions.sh
  ```
  Or with a custom prefix: `PREFIX=$HOME/.local LD_LIBRARY_PATH="$HOME/.local/lib:$HOME/.local/lib64" bash scripts/check_installed_versions.sh`

- **Validate TLS handshake to ServiceA (hybrid PQC when offered):**
  ```bash
  bash scripts/generate_rsa_certs.sh   # if certs/ not already present
  # Start ServiceA in another terminal: ./build/service_a/service_a --port 50051
  export LD_LIBRARY_PATH="/usr/local/lib:/usr/local/lib64:${LD_LIBRARY_PATH:-}"
  export PATH="/usr/local/bin:${PATH}"
  bash scripts/validate_tls.sh
  ```
  With a custom OpenSSL prefix: `PREFIX=$HOME/.local bash scripts/validate_tls.sh`. To test against OpenSSL’s s_server instead of ServiceA (e.g. when gRPC doesn't set groups): `PQC_VALIDATE_USE_OPENSSL_SERVER=1 bash scripts/validate_tls.sh`

- **Validate classical fallback (s_server/s_client):** With OpenSSL ≥ 3.5 (same env as build), run  
  `bash scripts/validate_tls_fallback.sh`  
  to prove classical-only negotiation and fallback interop (server offers PQC+classical, client classical-only). The script prints the **negotiated group** (e.g. `x25519` or `secp256r1`) for each test. Uses port 50553 by default; set `PQC_VALIDATE_FALLBACK_PORT` if needed.

### Docker testing

- **Unit/integration tests in image:** `docker run --rm pqc-grpc:latest ctest --test-dir build --output-on-failure`
- **TLS groups check in image:** `docker run --rm pqc-grpc:latest bash scripts/tls_groups_check.sh`
- **Validate TLS to ServiceA from inside the Docker network** (stack must be running; uses OpenSSL 3.5.5 in image):
  ```bash
  docker run --rm --network pqc_pqcnet \
    -v "$(pwd)/certs:/PQC/certs:ro" -v "$(pwd)/scripts:/PQC/scripts:ro" \
    -e PQC_VALIDATE_SKIP_START=1 -e PQC_VALIDATE_SERVER_ADDR=service_a:50051 \
    -e PQC_CERT_PATH=/PQC/certs/server.pem -e PQC_KEY_PATH=/PQC/certs/server.key \
    -e PQC_CA_PATH=/PQC/certs/ca.pem -e PQC_CLIENT_CERT_PATH=/PQC/certs/client.pem \
    -e PQC_CLIENT_KEY_PATH=/PQC/certs/client.key -e CERTS_DIR=/PQC/certs \
    -w /PQC pqc-grpc:latest bash scripts/validate_tls.sh
  ```
- **Call ServiceB (gRPC over TLS)** to exercise client → ServiceB → ServiceA (see Docker build and run section above for the grpcurl command).

## CI pipeline

GitHub Actions (`.github/workflows/ci.yml`) runs on push and pull requests to `main`:

1. **Build and test**
   - Builds the project’s Docker image (OpenSSL 3.5.5 + gRPC/Protobuf/Abseil, then project build).
   - Runs `ctest --test-dir build --output-on-failure`.
   - Runs `scripts/tls_groups_check.sh`.

2. **Docker e2e**
   - Generates RSA certs, starts services with `docker compose`, then runs `scripts/validate_tls.sh` with `PQC_VALIDATE_SKIP_START=1` against the running ServiceA.

## Future roadmap

- **ML-DSA certificates:** Use `certs/mldsa/` and ML-DSA-65 (or newer) for server/client auth where appropriate.
- **FIPS 140-3:** Evaluate FIPS build and usage of OpenSSL/gRPC in regulated environments.
- **Composite signatures:** Support composite (classical + PQC) signatures when standardized and supported by the stack.
- **Production rollout:** Hardening, key rotation, monitoring of negotiated groups, and operational runbooks for PQC migration.

---

See also: [PRD.md](PRD.md), [docs/DEPENDENCIES.md](docs/DEPENDENCIES.md), [docs/BUILD.md](docs/BUILD.md), and **Build and implementation notes** in [tasks/tasks-quantum-safe-grpc-pqc.md](tasks/tasks-quantum-safe-grpc-pqc.md).
