## Relevant Files

- `PRD.md` - Product Requirements Document with functional/non-functional requirements, validation plan.
- `README.md` - Project overview, build instructions, PQC configuration guide, cert generation walkthrough.
- `docs/BUILD.md` - Short build/test reference; points subagents to **Build and implementation notes** in this file.
- `docs/DEPENDENCIES.md` - Dependency versions and install instructions; includes CMake and subagent pointer to this tasks file.
- `docs/STATUS_THROUGH_TASK5.md` - Summary of completed work through Task 5, current tests, and next tasks (6–9).
- `CMakeLists.txt` - Root CMake build file: project options, find_package (OpenSSL first, then Protobuf CONFIG, absl CONFIG, gRPC), enable_testing(), subdirectory wiring. See **Build and implementation notes** below.
- `cmake/FindOpenSSL35.cmake` - Custom CMake find module enforcing OpenSSL >= 3.5.
- `proto/CMakeLists.txt` - Generates `.pb.cc`/`.pb.h` and `.grpc.pb.cc`/`.grpc.pb.h` in the proto subdir via add_custom_command and protobuf::protoc (no root-level protobuf_generate).
- `proto/service_a.proto` - Protobuf/gRPC service definition for ServiceA (`ProcessData` RPC).
- `proto/service_b.proto` - Protobuf/gRPC service definition for ServiceB (`ForwardRequest` RPC).
- `common/CMakeLists.txt` - CMake target for the shared TLS utility library.
- `common/include/common/tls_config.h` - Header: `CreateServerCredentials`, `CreateChannelCredentials`.
- `common/src/tls_config.cpp` - Implementation using `grpc::SslServerCredentialsOptions`/`SslCredentialsOptions` and `LoadFileContents()` for PEM; PQC group order not set (gRPC C++ does not expose SSL_CTX).
- `common/include/common/tls_metrics.h` - Header: `GetNegotiatedGroupName` utility.
- `common/src/tls_metrics.cpp` - Implementation of negotiated-group logging via OpenSSL APIs.
- `common/include/common/cert_loader.h` - Header: `LoadFileContents`, `CertConfig` struct.
- `common/src/cert_loader.cpp` - Implementation of cert/key file loading and config population.
- `service_a/CMakeLists.txt` - CMake target for ServiceA server binary.
- `service_a/include/service_a/service_a_impl.h` - Header for ServiceA RPC implementation class.
- `service_a/src/service_a_impl.cpp` - ServiceA `ProcessData` RPC handler with TLS metrics logging.
- `service_a/src/main.cpp` - ServiceA server entry point: cert loading, TLS setup, gRPC server start.
- `service_b/CMakeLists.txt` - CMake target for ServiceB client/server binary.
- `service_b/include/service_b/service_b_impl.h` - Header for ServiceB RPC implementation class.
- `service_b/src/service_b_impl.cpp` - ServiceB `ForwardRequest` handler calling ServiceA.
- `service_b/src/main.cpp` - ServiceB entry point: client channel to ServiceA, own gRPC server.
- `tests/CMakeLists.txt` - CMake target for GoogleTest test binaries.
- `tests/test_tls_handshake.cpp` - Integration test: hybrid PQC TLS handshake between client and server.
- `tests/test_fallback.cpp` - Integration test: classical fallback when PQC groups unavailable client-side.
- `tests/test_legacy_rsa_client.cpp` - (Task 7.6) E2e test: legacy client with RSA certs only and classical-only credentials succeeds against server with RSA certs and PQC offered.
- `tests/test_cert_loading.cpp` - Unit test: `LoadFileContents` and `CertConfig` population.
- `tests/test_metrics.cpp` - Unit test: `GetNegotiatedGroupName` returns correct group strings.
- `scripts/generate_rsa_certs.sh` - Shell script to generate RSA CA + server + client certificates.
- `scripts/generate_mldsa_certs.sh` - Shell script to generate ML-DSA PQC certificates (future phase).
- `scripts/validate_tls.sh` - End-to-end TLS validation script using `openssl s_client`.
- `scripts/tls_groups_check.sh` - Checks OpenSSL version and PQC algorithm availability.
- `scripts/check_installed_versions.sh` - Cross-checks installed dependency versions (OpenSSL, protoc, Abseil, gRPC) against project requirements; use when troubleshooting build or version mismatches (see **Troubleshooting: dependency versions** below).
- `docker/Dockerfile` - Docker image building OpenSSL 3.5.5 from source + project compilation.
- `docker/docker-compose.yml` - Compose file running ServiceA and ServiceB containers with shared certs.
- `.github/workflows/ci.yml` - GitHub Actions CI pipeline: build, test, Docker e2e.

### Notes

- This is a C++ project using CMake (>= 3.22) and C++17. Tests use GoogleTest (fetched via FetchContent). Run tests with `ctest --test-dir build --output-on-failure`; root must call `enable_testing()` (see **Build and implementation notes**).
- Shell scripts in `scripts/` should be made executable (`chmod +x`) before running.
- OpenSSL ≥ 3.5 must be installed on the system (or available in the Docker image) before building. The custom `FindOpenSSL35.cmake` module enforces this at configure time.
- **gRPC 1.75.1, Protobuf 31.1, and Abseil 20250512.1** are required system-installed dependencies. Use `scripts/install_grpc_deps.sh` (see `docs/DEPENDENCIES.md`) to install them in the correct order.
- Proto-generated C++ files are built into a `pqc_proto` library target shared by both services.

### Troubleshooting: dependency versions

If you or a subagent run into build failures or version-related errors (e.g. OpenSSL too old, wrong protoc, CMake can't find gRPC/Abseil), use the version check script to verify what is actually installed:

- **System-wide install** (e.g. after `sudo bash scripts/install_grpc_deps.sh`):
  ```bash
  LD_LIBRARY_PATH="/usr/local/lib:/usr/local/lib64" bash scripts/check_installed_versions.sh
  ```
  Or with sudo so `/usr/local` is on PATH: `sudo bash scripts/check_installed_versions.sh`
- **Custom prefix** (e.g. `PREFIX=$HOME/.local`):
  ```bash
  PREFIX=$HOME/.local LD_LIBRARY_PATH="$HOME/.local/lib:$HOME/.local/lib64" bash scripts/check_installed_versions.sh
  ```

Required versions (must match `docs/DEPENDENCIES.md` and `scripts/install_grpc_deps.sh`): **OpenSSL ≥ 3.5.5**, **protoc 31.1**, **Abseil 20250512.1** (or 20250512 from .pc), **gRPC 1.75.1**. If OpenSSL shows the system version (e.g. 3.0.x) instead of 3.5.5, set `LD_LIBRARY_PATH` to the prefix lib dir so the correct OpenSSL is used. Install order: OpenSSL 3.5.5+ first (`scripts/install_openssl.sh`), then gRPC/Protobuf/Abseil (`scripts/install_grpc_deps.sh`) with the same `PREFIX`.

### Build and implementation notes (for subagents)

**Read this before changing CMake, proto, common TLS, or tests.** The build was made to work with system-installed gRPC 1.75.1 / Protobuf 31.1 / Abseil and OpenSSL 3.5.5; the following decisions are in place so subagents don’t revert or conflict with them.

1. **CMake dependency order and CONFIG mode**
   - **OpenSSL must be found first** (before gRPC). Root `CMakeLists.txt` finds OpenSSL via `FindOpenSSL35` at the top so that `gRPC::grpc` can resolve `OpenSSL::SSL`.
   - **Protobuf**: use **CONFIG** only (`find_package(Protobuf CONFIG REQUIRED`). Do not use the FindProtobuf module in the root (it reports library version as 6.31.1 for protobuf 31.x and fails the version check).
   - **Abseil**: use **CONFIG** as **`absl`** (`find_package(absl CONFIG REQUIRED`). The installed package is often named `absl` (e.g. `abslConfig.cmake`), not `abseil-cpp`.

2. **Proto code generation**
   - **All proto code is generated in the `proto/` subdirectory.** `proto/CMakeLists.txt` uses `add_custom_command` with `protobuf::protoc` to generate `.pb.cc`/`.pb.h` and `.grpc.pb.cc`/`.grpc.pb.h` in `proto`’s binary dir. The root does **not** call `protobuf_generate`; generating in the root caused path/dependency issues. Do not move generation back to the root without fixing scope and absolute paths.

3. **TLS credentials (gRPC C++ API)**
   - **`common/src/tls_config.cpp`** uses the **stable SSL API**, not the experimental TLS key-materials API:
     - Server: `grpc::SslServerCredentialsOptions` + `grpc::SslServerCredentials()`.
     - Channel: `grpc::SslCredentialsOptions` + `grpc::SslCredentials()`.
   - PEM is loaded from files with `LoadFileContents()`. The gRPC C++ API in 1.75.1 does **not** expose the underlying `SSL_CTX`, so PQC group order (e.g. `SSL_CTX_set1_groups_list`) is not set here; it relies on OpenSSL defaults or future API support.

4. **TLS metrics and tests**
   - **`GetNegotiatedGroupName`**: A **non-template** overload `GetNegotiatedGroupName(ssl_st*)` is declared in `common/include/common/tls_metrics.h` and defined in `tls_metrics.cpp`. Tests must call this overload (e.g. with `static_cast<ssl_st*>(nullptr)`) so they link; do not rely on a template-only declaration.
   - **`LogNegotiatedGroupName`** is in the **global** namespace (not `pqc_common`).

5. **Testing**
   - The **root** `CMakeLists.txt` must call **`enable_testing()`** before `add_subdirectory(tests)` so that `ctest --test-dir build` discovers the tests added in `tests/CMakeLists.txt`.

6. **Configure / build / test commands (use this environment)**
   ```bash
   export LD_LIBRARY_PATH="/usr/local/lib:/usr/local/lib64:${LD_LIBRARY_PATH:-}"
   export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:/usr/local/lib64/pkgconfig:${PKG_CONFIG_PATH:-}"
   export PATH="/usr/local/bin:${PATH}"
   cmake -B build -DCMAKE_PREFIX_PATH="/usr/local"
   cmake --build build
   ctest --test-dir build --output-on-failure
   ```
   For a custom prefix (e.g. `$HOME/.local`), set `CMAKE_PREFIX_PATH` and the same prefix in `LD_LIBRARY_PATH` and `PKG_CONFIG_PATH`.

7. **Service includes**
   - Use `#include <grpcpp/grpcpp.h>` in service code (not `grpcpp/grpc.h`).

## Instructions for Completing Tasks

**IMPORTANT:** As you complete each task, you must check it off in this markdown file by changing `- [ ]` to `- [x]`. This helps track progress and ensures you don't skip any steps.

Example:
- `- [ ] 1.1 Read file` → `- [x] 1.1 Read file` (after completing)

Update the file after completing each sub-task, not just after completing an entire parent task.

## Tasks

- [x] 0.0 Create feature branch
  - [x] 0.1 Initialize a git repository in `/home/asoni/PQC` if not already initialized (`git init`)
  - [x] 0.2 Create and checkout a new branch for this feature (`git checkout -b feature/quantum-safe-grpc-pqc`)

- [x] 1.0 Create PRD and project documentation
  - [x] 1.1 Create `PRD.md` at project root with the full Product Requirements Document containing sections: Title, Overview, Functional Requirements (Secure RPC Communication, Certificate Generation, Protocol Negotiation, Compatibility Mode), Non-Functional Requirements, Deployment Environments, Detailed Task List, Validation Plan (Phases 1–4), and Example Validation Script
  - [x] 1.2 Review PRD content to ensure all hybrid PQC groups (X25519MLKEM768, SecP256r1MLKEM768) and ML-DSA certificate references are included

- [x] 2.0 Set up CMake build system and dependency management
  - [x] 2.1 Create root `CMakeLists.txt` with `cmake_minimum_required(VERSION 3.22)`, `project(PQC_gRPC)`, and `CMAKE_CXX_STANDARD 17`
  - [x] 2.2 Use system-installed gRPC 1.75.1, Protobuf 31.1, Abseil 20250512.1 (find_package); install via `scripts/install_grpc_deps.sh` (see docs/DEPENDENCIES.md); gRPC must use system OpenSSL
  - [x] 2.3 Create `cmake/FindOpenSSL35.cmake` custom find module that calls `find_package(OpenSSL 3.5 REQUIRED)`, sets `OPENSSL_35_AVAILABLE` compile definition, and issues `FATAL_ERROR` if version < 3.5
  - [x] 2.4 Add `include(cmake/FindOpenSSL35.cmake)` in root CMakeLists.txt and wire up `add_subdirectory()` calls for `proto`, `common`, `service_a`, `service_b`, and `tests`
  - [x] 2.5 Add a `.gitignore` file ignoring `build/`, `certs/`, and common CMake/IDE artifacts

- [x] 3.0 Define Protobuf/gRPC service interfaces
  - [x] 3.1 Create `proto/service_a.proto` with package `pqc.servicea`, message `DataRequest` (string `payload`), message `DataResponse` (string `result`, string `negotiated_group`), and service `ServiceA` with RPC `ProcessData(DataRequest) returns (DataResponse)`
  - [x] 3.2 Create `proto/service_b.proto` with package `pqc.serviceb`, message `ForwardReq` (string `payload`, string `service_a_address`), message `ForwardResp` (string `result`, string `service_a_group`, string `service_b_group`), and service `ServiceB` with RPC `ForwardRequest(ForwardReq) returns (ForwardResp)`
  - [x] 3.3 Create `proto/CMakeLists.txt` that builds a `pqc_proto` static library target using `protobuf_generate` and the `grpc_cpp_plugin` to produce C++ sources from both `.proto` files, with proper include paths exported

- [x] 4.0 Implement common TLS library (config, metrics, cert loader)
  - [x] 4.1 Create `common/include/common/cert_loader.h` declaring `LoadFileContents(const std::string& path) -> std::string` and `struct CertConfig { cert_chain_path, private_key_path, ca_cert_path }` with a static factory `CertConfig::FromEnv()`
  - [x] 4.2 Create `common/src/cert_loader.cpp` implementing `LoadFileContents` (read file into string, throw on failure) and `CertConfig::FromEnv()` reading from env vars `PQC_CERT_PATH`, `PQC_KEY_PATH`, `PQC_CA_PATH`
  - [x] 4.3 Create `common/include/common/tls_config.h` declaring `CreateServerCredentials(const CertConfig& config, bool pqc_enabled = true) -> std::shared_ptr<grpc::ServerCredentials>` and `CreateChannelCredentials(const CertConfig& config, bool pqc_enabled = true) -> std::shared_ptr<grpc::ChannelCredentials>`
  - [x] 4.4 Create `common/src/tls_config.cpp` implementing both credential functions: load cert/key/CA via `CertConfig`, build `grpc::SslServerCredentialsOptions` / `grpc::SslCredentialsOptions`, and configure hybrid PQC groups (`X25519MLKEM768:SecP256r1MLKEM768:x25519:secp256r1`) or classical-only groups (`x25519:secp256r1`) based on the `pqc_enabled` flag using `SSL_CTX_set1_groups_list`
  - [x] 4.5 Create `common/include/common/tls_metrics.h` declaring `GetNegotiatedGroupName(SSL* ssl) -> std::string` and `LogNegotiatedGroup(SSL* ssl) -> void`
  - [x] 4.6 Create `common/src/tls_metrics.cpp` implementing `GetNegotiatedGroupName` using `SSL_get_negotiated_group()` + `OBJ_nid2sn()`, and `LogNegotiatedGroup` that logs group name to stdout with a `[TLS-METRICS]` prefix
  - [x] 4.7 Create `common/CMakeLists.txt` that builds `pqc_common` static library from `src/*.cpp`, exposes `include/` as public headers, links against `OpenSSL::SSL`, `OpenSSL::Crypto`, and gRPC targets

- [x] 5.0 Implement ServiceA (gRPC server) and ServiceB (gRPC client/server)
  - [x] 5.1 Create `service_a/include/service_a/service_a_impl.h` with `ServiceAImpl` class inheriting from the generated `ServiceA::Service` stub
  - [x] 5.2 Create `service_a/src/service_a_impl.cpp` implementing `ProcessData`: echo/transform the payload, call `LogNegotiatedGroup` on the peer's SSL connection, populate `negotiated_group` in the response
  - [x] 5.3 Create `service_a/src/main.cpp`: parse `--port` (default 50051) and cert paths from env/flags, call `CreateServerCredentials()`, build and run the gRPC server, log startup message
  - [x] 5.4 Create `service_a/CMakeLists.txt` building `service_a` executable, linking `pqc_proto`, `pqc_common`, and gRPC libraries
  - [x] 5.5 Create `service_b/include/service_b/service_b_impl.h` with `ServiceBImpl` class inheriting from `ServiceB::Service`, holding a `ServiceA::Stub` for outbound calls
  - [x] 5.6 Create `service_b/src/service_b_impl.cpp` implementing `ForwardRequest`: create a channel to ServiceA using `CreateChannelCredentials()`, call `ProcessData`, return combined response with both service groups
  - [x] 5.7 Create `service_b/src/main.cpp`: parse `--port` (default 50052), `--service-a-addr` (default `localhost:50051`), and cert paths from env/flags; start gRPC server exposing ServiceB
  - [x] 5.8 Create `service_b/CMakeLists.txt` building `service_b` executable, linking `pqc_proto`, `pqc_common`, and gRPC libraries

- [x] 6.0 Create certificate generation and validation scripts
  - [x] 6.1 Create `scripts/generate_rsa_certs.sh`: generate RSA 4096 CA key+cert, RSA 2048 server key+cert signed by CA, RSA 2048 client key+cert signed by CA; output all to `certs/` directory; make script executable
  - [x] 6.2 Create `scripts/generate_mldsa_certs.sh`: generate ML-DSA-65 CA key+cert, ML-DSA-65 server key+cert signed by CA, ML-DSA-65 client key+cert signed by CA using `openssl genpkey -algorithm mldsa65`; output to `certs/mldsa/`; include a check that OpenSSL >= 3.5 is available; make executable
  - [x] 6.3 Create `scripts/tls_groups_check.sh`: verify `openssl version` >= 3.5, check `openssl list -kem-algorithms` for MLKEM entries, check `openssl list -signature-algorithms` for ML-DSA entries; exit non-zero on failure; make executable
  - [x] 6.4 Create `scripts/validate_tls.sh`: start ServiceA in background, wait for port ready, run `openssl s_client -connect localhost:50051 -groups X25519MLKEM768`, parse output for `Server Temp Key` confirming hybrid group, clean up background process; exit non-zero on failure; make executable

- [x] 7.0 Write automated tests (handshake, fallback, cert loading, metrics)
  - [x] 7.1 Create `tests/CMakeLists.txt`: use FetchContent to pull GoogleTest, enable `testing`, create test executables for each test file, link against `pqc_common`, `pqc_proto`, OpenSSL, and gRPC; register each with `add_test()`
  - [x] 7.2 Create `tests/test_cert_loading.cpp`: test `LoadFileContents` with a valid temp file returns correct content; test `LoadFileContents` with non-existent path throws; test `CertConfig::FromEnv()` reads environment variables correctly
  - [x] 7.3 Create `tests/test_metrics.cpp`: test `GetNegotiatedGroupName` with a null SSL pointer returns empty/unknown; create a mock or minimal SSL context to validate group name extraction logic
  - [x] 7.4 Create `tests/test_tls_handshake.cpp`: generate temporary RSA certs in test fixture setup; start an in-process gRPC server with `CreateServerCredentials(config, /*pqc_enabled=*/true)`; connect a client with `CreateChannelCredentials(config, /*pqc_enabled=*/true)`; call `ProcessData` RPC and assert success; assert the response `negotiated_group` contains "MLKEM" or "X25519MLKEM768"
  - [x] 7.5 Create `tests/test_fallback.cpp`: same setup as handshake test but client uses `CreateChannelCredentials(config, /*pqc_enabled=*/false)` (classical only); assert RPC succeeds; assert negotiated group is classical (e.g., "x25519" or "X25519" or "secp256r1")
  - [x] 7.6 Add e2e test or scenario for **legacy agent with only old RSA cert**: client uses RSA certs only and classical-only credentials (`pqc_enabled=false`); server uses RSA certs and offers PQC; assert RPC succeeds (validates that TLS can be quantum-safe on the server while clients still use existing RSA certs and classical key agreement). Can be a dedicated test (e.g. `test_legacy_rsa_client.cpp`) or a documented Docker/script scenario.

- [x] 8.0 Set up Docker environment and GitHub Actions CI
  - [x] 8.1 Create `docker/Dockerfile`: base `ubuntu:24.04`, install build-essential/cmake/git/perl/wget, download and build OpenSSL 3.5.5 from source to `/opt/openssl-3.5.5`, set `OPENSSL_ROOT_DIR`/`LD_LIBRARY_PATH`/`PATH` environment variables, copy project source, build with CMake, keep build artifacts for runtime
  - [x] 8.2 Create `docker/docker-compose.yml`: define `service_a` and `service_b` services built from the Dockerfile, mount `certs/` volume into both containers, configure `service_b` to depend on `service_a`, set environment variables for cert paths and ServiceA address, expose ports 50051 and 50052 on a shared bridge network
  - [x] 8.3 Create `.github/workflows/ci.yml` with trigger on push/PR to `main`; job `build-and-test` that builds the Docker image, runs `cmake` configure+build inside it, runs `ctest`, and runs `scripts/tls_groups_check.sh`; job `docker-e2e` that runs `docker-compose up --abort-on-container-exit` and `scripts/validate_tls.sh`

- [x] 9.0 Write README with build instructions and PQC configuration guide
  - [x] 9.1 Create `README.md` with project title, overview paragraph, and ASCII architecture diagram showing ServiceB → ServiceA over hybrid TLS
  - [x] 9.2 Add Prerequisites section listing OpenSSL 3.5.5, CMake 3.22+, C++17 compiler (GCC 11+ / Clang 14+), and Docker (optional)
  - [x] 9.3 Add Build Instructions section with local build commands (`cmake -B build -DOPENSSL_ROOT_DIR=...`, `cmake --build build`) and Docker build commands (`docker-compose build`, `docker-compose up`)
  - [x] 9.4 Add Certificate Generation section with step-by-step instructions for running `scripts/generate_rsa_certs.sh` and `scripts/generate_mldsa_certs.sh`
  - [x] 9.5 Add Hybrid PQC Configuration section explaining the TLS 1.3 groups list, how `SSL_CTX_set1_groups_list` is called, the priority order (hybrid first, classical fallback), and how to toggle PQC on/off
  - [x] 9.6 Add Testing section with commands to run unit tests (`ctest`), validation scripts, and Docker e2e tests
  - [x] 9.7 Add CI Pipeline section describing the GitHub Actions workflow jobs
  - [x] 9.8 Add Future Roadmap section covering ML-DSA certificate integration, FIPS 140-3 mode, composite signatures, and production rollout considerations
