## Plan: Quantum-Safe gRPC PQC Microservices

**TL;DR:** Scaffold a two-service C++ gRPC project in `/home/asoni/PQC` with hybrid post-quantum key exchange over TLS 1.3. The build uses CMake with system-installed gRPC 1.75.1, Protobuf 31.1, and Abseil 20250512.1 (see docs/DEPENDENCIES.md and scripts/install_grpc_deps.sh), links against a system-installed OpenSSL 3.5.5, and wraps all TLS configuration (group selection, cert loading, fallback) in a shared library. CI runs on GitHub Actions using a custom Docker image that bundles OpenSSL 3.5.5. Certificate generation scripts cover both RSA (current) and ML-DSA (future). Automated tests validate hybrid handshakes, fallback behavior, and negotiated cipher groups.

---

### Directory Layout

```
PQC/
├── PRD.md
├── README.md
├── CMakeLists.txt                 # Root CMake — options, deps, subdirs
├── cmake/
│   └── FindOpenSSL35.cmake        # Custom find module enforcing >=3.5
├── proto/
│   ├── CMakeLists.txt             # Proto lib target
│   ├── service_a.proto            # ServiceA RPC definitions
│   └── service_b.proto            # ServiceB RPC definitions
├── common/
│   ├── CMakeLists.txt
│   ├── include/common/
│   │   ├── tls_config.h           # TLS helper API
│   │   ├── tls_metrics.h          # Negotiated-group logging
│   │   └── cert_loader.h          # Cert/key path config
│   └── src/
│       ├── tls_config.cpp
│       ├── tls_metrics.cpp
│       └── cert_loader.cpp
├── service_a/
│   ├── CMakeLists.txt
│   ├── src/
│   │   ├── main.cpp               # Server binary
│   │   └── service_a_impl.cpp     # RPC handlers
│   └── include/service_a/
│       └── service_a_impl.h
├── service_b/
│   ├── CMakeLists.txt
│   ├── src/
│   │   ├── main.cpp               # Client binary calling ServiceA
│   │   └── service_b_impl.cpp
│   └── include/service_b/
│       └── service_b_impl.h
├── tests/
│   ├── CMakeLists.txt
│   ├── test_tls_handshake.cpp     # Hybrid handshake validation
│   ├── test_fallback.cpp          # Classical fallback
│   ├── test_cert_loading.cpp      # Cert/key loading
│   └── test_metrics.cpp           # Negotiated group logging
├── scripts/
│   ├── generate_rsa_certs.sh      # RSA cert gen (current default)
│   ├── generate_mldsa_certs.sh    # ML-DSA cert gen (future phase)
│   ├── validate_tls.sh            # End-to-end TLS validation
│   └── tls_groups_check.sh        # Verify MLKEM groups available
├── docker/
│   ├── Dockerfile                 # Build image with OpenSSL 3.5.5
│   └── docker-compose.yml         # ServiceA + ServiceB containers
└── .github/
    └── workflows/
        └── ci.yml                 # GitHub Actions pipeline
```

---

### Steps

**Step 1 — Create PRD.md**
Write the full PRD at PRD.md using the user-provided content verbatim, formatted in clean Markdown with sections: Overview, Functional Requirements, Non-Functional Requirements, Deployment Environments, Detailed Task List, Validation Plan, and Example Validation Script.

**Step 2 — Root CMake & Dependency Setup**
Create CMakeLists.txt:
- Set `cmake_minimum_required(VERSION 3.22)`, `project(PQC_gRPC)`, C++17 standard.
- Use `find_package` for gRPC 1.75.1, Protobuf 31.1, and Abseil 20250512.1 (system-installed; install via `scripts/install_grpc_deps.sh` — see docs/DEPENDENCIES.md). gRPC must use the **system OpenSSL** (`gRPC_SSL_PROVIDER=package` when building gRPC from source).
- Create cmake/FindOpenSSL35.cmake — a custom find module that calls `find_package(OpenSSL 3.5 REQUIRED)` and sets a compile definition `OPENSSL_35_AVAILABLE`. Fatal error if < 3.5.
- Add subdirectories: `proto`, `common`, `service_a`, `service_b`, `tests`.

**Step 3 — Proto Definitions**
Create proto/service_a.proto:
- Package `pqc.servicea`; define `ServiceA` with an RPC like `ProcessData(DataRequest) returns (DataResponse)`.

Create proto/service_b.proto:
- Package `pqc.serviceb`; define `ServiceB` with an RPC like `ForwardRequest(ForwardReq) returns (ForwardResp)`.

Create proto/CMakeLists.txt:
- Use gRPC's `protobuf_generate` and `grpc_cpp_plugin` to produce C++ sources. Build as a static library target `pqc_proto`.

**Step 4 — Common TLS Library**
Create common/include/common/tls_config.h and common/src/tls_config.cpp:
- `CreateServerCredentials(cert_path, key_path, ca_path)` → `std::shared_ptr<grpc::ServerCredentials>` — builds TLS credentials, obtains the underlying `SSL_CTX*` via gRPC's `TlsServerCredentials` experimental API, then calls `SSL_CTX_set1_groups_list(ctx, "X25519MLKEM768:SecP256r1MLKEM768:x25519:secp256r1")`.
- `CreateChannelCredentials(ca_path)` → `std::shared_ptr<grpc::ChannelCredentials>` — same pattern for channel side with `TlsChannelCredentials`.
- Both functions accept an optional `bool pqc_enabled` flag; when `false`, only classical groups are set (fallback mode).

Create common/include/common/tls_metrics.h and common/src/tls_metrics.cpp:
- After handshake, call `SSL_get_negotiated_group()` to retrieve the negotiated group NID.
- Convert NID to name via `OBJ_nid2sn()`.
- Log and expose via a `GetNegotiatedGroupName(SSL*)` utility.

Create common/include/common/cert_loader.h and common/src/cert_loader.cpp:
- `LoadFileContents(path)` → `std::string` helper.
- `CertConfig` struct with `cert_chain_path`, `private_key_path`, `ca_cert_path` members, populated from environment variables or CLI flags.

**Step 5 — ServiceA (Server)**
Create service_a/src/service_a_impl.cpp:
- Implement `ServiceA::ProcessData` — a simple echo/transform RPC.
- After each call, log the negotiated TLS group using the metrics utility.

Create service_a/src/main.cpp:
- Parse cert paths from env/flags.
- Call `CreateServerCredentials()` from common lib.
- Build and run the gRPC server on a configurable port (default 50051).

**Step 6 — ServiceB (Client → ServiceA)**
Create service_b/src/service_b_impl.cpp:
- Implement `ServiceB::ForwardRequest` — creates a channel to ServiceA, calls `ProcessData`, returns the result.

Create service_b/src/main.cpp:
- Can run as both a gRPC server (exposing `ServiceB`) and a client to ServiceA.
- Uses `CreateChannelCredentials()` for the outbound connection.

**Step 7 — Certificate Generation Scripts**
Create scripts/generate_rsa_certs.sh:
- Generate a self-signed RSA 4096 CA.
- Generate server and client certs signed by the CA.
- Output to `certs/` directory.

```bash
# Key commands (to be scripted):
openssl req -x509 -newkey rsa:4096 -keyout ca-key.pem -out ca-cert.pem -days 365 -nodes -subj "/CN=PQC-CA"
openssl req -newkey rsa:2048 -keyout server-key.pem -out server-csr.pem -nodes -subj "/CN=localhost"
openssl x509 -req -in server-csr.pem -CA ca-cert.pem -CAkey ca-key.pem -CAcreateserial -out server-cert.pem -days 365
```

Create scripts/generate_mldsa_certs.sh:
- ML-DSA certificate generation (requires OpenSSL 3.5+ with PQC provider).

```bash
# Future-phase commands:
openssl genpkey -algorithm mldsa65 -out ca-mldsa-key.pem
openssl req -x509 -new -key ca-mldsa-key.pem -out ca-mldsa-cert.pem -days 365 -subj "/CN=PQC-CA-MLDSA"
openssl genpkey -algorithm mldsa65 -out server-mldsa-key.pem
openssl req -new -key server-mldsa-key.pem -out server-mldsa-csr.pem -subj "/CN=localhost"
openssl x509 -req -in server-mldsa-csr.pem -CA ca-mldsa-cert.pem -CAkey ca-mldsa-key.pem -CAcreateserial -out server-mldsa-cert.pem -days 365
```

**Step 8 — Validation Scripts**
Create scripts/validate_tls.sh:
- Start ServiceA in background, use `openssl s_client -connect localhost:50051 -groups X25519MLKEM768` to verify the handshake, parse output for `Server Temp Key` line confirming hybrid group.

Create scripts/tls_groups_check.sh:
- Run `openssl version` (assert ≥ 3.5).
- Run `openssl list -kem-algorithms | grep -i mlkem` to confirm PQC KEM availability.
- Run `openssl list -signature-algorithms | grep -i mldsa` for future cert readiness.

**Step 9 — Automated Tests**
Create tests/CMakeLists.txt — use GoogleTest (fetched via FetchContent).

Create tests/test_tls_handshake.cpp:
- Spin up ServiceA server in-process on a random port with hybrid TLS.
- Connect a gRPC client with hybrid groups.
- Assert RPC succeeds.
- Assert `GetNegotiatedGroupName()` contains "MLKEM" or "X25519MLKEM768".

Create tests/test_fallback.cpp:
- Configure client with only classical groups (`x25519`).
- Connect to server that offers both hybrid and classical.
- Assert handshake succeeds with a classical group.

Create tests/test_cert_loading.cpp:
- Unit test `LoadFileContents` with valid/invalid paths.
- Unit test `CertConfig` population.

Create tests/test_metrics.cpp:
- Mock or real `SSL*` to verify `GetNegotiatedGroupName` returns expected strings.

**Step 10 — Docker Environment**
Create docker/Dockerfile:
- Base: `ubuntu:24.04`.
- Install build-essential, cmake, git, perl, wget.
- Build OpenSSL 3.5.5 from source (`./Configure --prefix=/opt/openssl-3.5.5 enable-unstable-qlog && make -j && make install`).
- Set `OPENSSL_ROOT_DIR=/opt/openssl-3.5.5`, `LD_LIBRARY_PATH`, `PATH`.
- Copy project source, build with CMake, run tests.

Create docker/docker-compose.yml:
- `service_a` container: runs ServiceA, mounts `certs/` volume.
- `service_b` container: runs ServiceB, depends on `service_a`, mounts same `certs/` volume.
- Shared bridge network.

**Step 11 — GitHub Actions CI**
Create .github/workflows/ci.yml:
- Trigger on push/PR to `main`.
- Job `build-and-test`:
  - Use the Docker image from Step 10 (or build it inline with a `services` block / `docker build`).
  - Run `cmake -B build -DCMAKE_PREFIX_PATH=/opt/openssl-3.5.5`, `cmake --build build -j$(nproc)`.
  - Run `ctest --test-dir build --output-on-failure`.
  - Run `scripts/tls_groups_check.sh`.
- Job `docker-e2e`:
  - `docker-compose up --abort-on-container-exit`.
  - Run `scripts/validate_tls.sh` against the composed services.

**Step 12 — README.md**
Create README.md covering:
- Project overview and architecture diagram (ASCII).
- Prerequisites (OpenSSL 3.5.5, CMake 3.22+, C++17 compiler).
- Build instructions (local and Docker).
- Certificate generation walkthrough.
- Hybrid PQC configuration explanation (groups list, fallback logic).
- Running tests.
- CI pipeline description.
- Future roadmap: ML-DSA certificates, FIPS mode, composite signatures.

---

### Verification

1. **Build check:** `cmake -B build && cmake --build build` completes without errors.
2. **Unit tests:** `ctest --test-dir build --output-on-failure` — all 4 test suites pass.
3. **Hybrid handshake proof:** `scripts/validate_tls.sh` output contains `X25519MLKEM768` in the negotiated group.
4. **PQC availability:** `scripts/tls_groups_check.sh` exits 0.
5. **Fallback:** `test_fallback` test confirms classical negotiation when hybrid is disabled client-side.
6. **Docker e2e:** `docker-compose up` shows ServiceB successfully calling ServiceA over hybrid TLS.
7. **CI green:** GitHub Actions pipeline passes on push.

---

### Decisions

- **FetchContent over git submodules** for gRPC/Protobuf: simpler CMake integration, no submodule sync issues, version-pinned in CMakeLists.txt.
- **System-installed OpenSSL 3.5.5** (not FetchContent): gRPC must link the same OpenSSL, and building OpenSSL via FetchContent is fragile. Docker image pre-builds it.
- **gRPC experimental TLS API** (`TlsChannelCredentialsOptions` / `TlsServerCredentialsOptions`): required to access `SSL_CTX` for custom group configuration — the stable `SslCredentials` API doesn't expose this.
- **GoogleTest** for unit testing: industry standard for C++, integrates well with CMake/CTest.
- **RSA certs as default, ML-DSA as future phase**: OpenSSL 3.5.x ML-DSA support is available but gRPC's certificate handling for PQC signatures is not yet fully validated upstream — safer to separate phases.
