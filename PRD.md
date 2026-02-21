# Quantum-Safe gRPC PQC Microservices — Product Requirements Document (PRD)

## Overview

This project scaffolds a two-service C++ gRPC microservices system with hybrid post-quantum key exchange over TLS 1.3. The build system uses CMake with system-installed gRPC 1.75.1, Protobuf 31.1, and Abseil 20250512.1 (see [docs/DEPENDENCIES.md](docs/DEPENDENCIES.md)), links against a system-installed OpenSSL 3.5.5, and encapsulates all TLS configuration (group selection, certificate loading, fallback) in a shared library. CI runs on GitHub Actions using a custom Docker image that bundles OpenSSL 3.5.5. Certificate generation scripts support both RSA (current) and ML-DSA (future). Automated tests validate hybrid handshakes, fallback behavior, and negotiated cipher groups.

## Functional Requirements

- Two C++17 gRPC microservices: ServiceA (server) and ServiceB (client/server)
- Hybrid post-quantum key exchange (MLKEM + classical) over TLS 1.3
- All TLS configuration (group selection, cert loading, fallback) in a shared library
- System-installed OpenSSL 3.5.5 (not vendored)
- Certificate generation scripts for RSA (default) and ML-DSA (future)
- Automated tests for handshake, fallback, and group negotiation
- Dockerized build and test environment
- GitHub Actions CI pipeline

## Non-Functional Requirements

- CMake-based build; gRPC, Protobuf, and Abseil are system-installed (see docs/DEPENDENCIES.md)
- gRPC 1.75.1, Protobuf 31.1, Abseil 20250512.1
- gRPC must link against the same OpenSSL as the system
- All TLS group selection and certificate logic is reusable and testable
- All code is C++17-compliant
- All scripts are POSIX shell compatible
- CI must run on GitHub Actions with a custom Docker image

## Deployment Environments

- Local Linux (Ubuntu 24.04 recommended)
- Docker (custom image with OpenSSL 3.5.5)
- GitHub Actions CI

## Detailed Task List

1. **Create PRD.md** (this file)
2. **Root CMake & Dependency Setup**
   - Root CMakeLists.txt using find_package for gRPC 1.75.1, Protobuf 31.1, Abseil 20250512.1 (system-installed; install via scripts/install_grpc_deps.sh — see docs/DEPENDENCIES.md)
   - cmake/FindOpenSSL35.cmake enforcing OpenSSL >= 3.5
   - Add subdirectories: proto, common, service_a, service_b, tests
3. **Proto Definitions**
   - proto/service_a.proto: ServiceA RPC
   - proto/service_b.proto: ServiceB RPC
   - proto/CMakeLists.txt: protobuf_generate, grpc_cpp_plugin, pqc_proto static lib
4. **Common TLS Library**
   - common/include/common/tls_config.h, src/tls_config.cpp: TLS credential helpers
   - common/include/common/tls_metrics.h, src/tls_metrics.cpp: negotiated group logging
   - common/include/common/cert_loader.h, src/cert_loader.cpp: cert/key loading
5. **ServiceA (Server)**
   - service_a/src/service_a_impl.cpp: implement ServiceA::ProcessData
   - service_a/src/main.cpp: parse cert paths, run gRPC server
6. **ServiceB (Client → ServiceA)**
   - service_b/src/service_b_impl.cpp: implement ServiceB::ForwardRequest
   - service_b/src/main.cpp: gRPC server/client, outbound connection
7. **Certificate Generation Scripts**
   - scripts/generate_rsa_certs.sh: RSA certs
   - scripts/generate_mldsa_certs.sh: ML-DSA certs (future)
8. **Validation Scripts**
   - scripts/validate_tls.sh: handshake validation
   - scripts/tls_groups_check.sh: PQC group/cert readiness
9. **Automated Tests**
   - tests/CMakeLists.txt: GoogleTest
   - tests/test_tls_handshake.cpp, test_fallback.cpp, test_cert_loading.cpp, test_metrics.cpp
10. **Docker Environment**
    - docker/Dockerfile: build/test image
    - docker/docker-compose.yml: service containers
11. **GitHub Actions CI**
    - .github/workflows/ci.yml: build, test, e2e
12. **README.md**: overview, build, usage, CI, roadmap. **docs/DEPENDENCIES.md**: dependency versions and install instructions.

## Validation Plan

- **Dependencies:** gRPC 1.75.1, Protobuf 31.1, Abseil 20250512.1, and OpenSSL ≥ 3.5 must be installed (see docs/DEPENDENCIES.md and `scripts/install_grpc_deps.sh`).
- **Build check:** `cmake -B build && cmake --build build` completes without errors
- **Unit tests:** `ctest --test-dir build --output-on-failure` — all 4 test suites pass
- **Hybrid handshake proof:** `scripts/validate_tls.sh` output contains `X25519MLKEM768` in the negotiated group
- **PQC availability:** `scripts/tls_groups_check.sh` exits 0
- **Fallback:** `test_fallback` test confirms classical negotiation when hybrid is disabled client-side
- **Docker e2e:** `docker-compose up` shows ServiceB successfully calling ServiceA over hybrid TLS
- **CI green:** GitHub Actions pipeline passes on push

## Example Validation Script

```
# Validate hybrid handshake
scripts/validate_tls.sh | grep 'Server Temp Key' | grep 'X25519MLKEM768'

# Check PQC group availability
scripts/tls_groups_check.sh

# Run all tests
cmake -B build && cmake --build build && ctest --test-dir build --output-on-failure
```
