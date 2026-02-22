# Project status through Task 9

**Last updated:** After completing Tasks 8–9 (Docker, CI, README) and proof of hybrid PQC.  
**Branch:** `feature/quantum-safe-grpc-pqc`.

## Summary

- **Tasks 0–9 are complete.** All sub-tasks under 0.0–9.0 are done (see `tasks/tasks-quantum-safe-grpc-pqc.md`).
- **Build:** Full project builds successfully with the environment described in the tasks file (see **Build and implementation notes**).
- **Tests:** All 5 test executables pass: `test_cert_loading`, `test_metrics`, `test_tls_handshake`, `test_fallback`, `test_legacy_rsa_client`.
- **Scripts:** `generate_rsa_certs.sh`, `generate_mldsa_certs.sh`, `tls_groups_check.sh`, `validate_tls.sh`, `check_installed_versions.sh`. `validate_tls.sh` prints the negotiated TLS 1.3 group (e.g. X25519MLKEM768) on success; use `PQC_VALIDATE_USE_OPENSSL_SERVER=1` to prove hybrid PQC without ServiceA.
- **Docker & CI:** `docker/Dockerfile`, `docker/docker-compose.yml`, `.github/workflows/ci.yml` — build, ctest, and Docker e2e on push/PR to `main`.
- **Docs:** `README.md` (overview, build, certs, PQC config, testing, CI, roadmap); `docs/BUILD.md` (quick reference + proof of hybrid PQC); `docs/DEPENDENCIES.md`, `docs/PQC_FAQ.md`.

---

## Completed scope (Tasks 0–9)

| Task | Description | Delivered |
|------|-------------|-----------|
| **0** | Feature branch | Git repo, branch `feature/quantum-safe-grpc-pqc` |
| **1** | PRD and docs | `PRD.md` with requirements, validation plan, PQC groups |
| **2** | CMake and deps | Root `CMakeLists.txt`, `FindOpenSSL35.cmake`, subdirs: proto, common, service_a, service_b, tests; `.gitignore` |
| **3** | Proto/gRPC APIs | `service_a.proto`, `service_b.proto`, `proto/CMakeLists.txt` → `pqc_proto` lib; DataResponse has `negotiated_group`; ForwardResp has `service_a_group`, `service_b_group` |
| **4** | Common TLS lib | `cert_loader` (LoadFileContents, CertConfig::FromEnv), `tls_config` (CreateServerCredentials, CreateChannelCredentials using Ssl* API), `tls_metrics` (GetNegotiatedGroupName, LogNegotiatedGroup, LogNegotiatedGroupName), `pqc_common` lib |
| **5** | ServiceA & ServiceB | ServiceA: `ServiceAImpl`, ProcessData, main (--port, certs from env); ServiceB: `ServiceBImpl`, ForwardRequest to ServiceA, main (--port, --service-a-addr, certs); both executables build and link correctly |
| **6** | Cert and validation scripts | `generate_rsa_certs.sh` (RSA 4096 CA, 2048 server/client → `certs/`); `generate_mldsa_certs.sh` (ML-DSA-65 → `certs/mldsa/`, OpenSSL ≥ 3.5 check); `tls_groups_check.sh` (OpenSSL ≥ 3.5, MLKEM, ML-DSA); `validate_tls.sh` (ServiceA or s_server, s_client with X25519MLKEM768, prints negotiated group on success) |
| **7** | Automated tests | `tests/CMakeLists.txt`, GoogleTest; `test_cert_loading`, `test_metrics`, `test_tls_handshake`, `test_fallback`, `test_legacy_rsa_client` — all pass |
| **8** | Docker and CI | `docker/Dockerfile` (OpenSSL 3.5.5 + project build); `docker/docker-compose.yml` (service_a, service_b, certs mount); `.github/workflows/ci.yml` (build-and-test, docker-e2e on push/PR to `main`) |
| **9** | README and docs | `README.md` (overview, prerequisites, build, certs, hybrid PQC config, testing, CI, roadmap); `docs/DEPENDENCIES.md`, `docs/BUILD.md` (quick reference + proof of hybrid PQC), `docs/PQC_FAQ.md` |

---

## Tests (current)

| Test executable | Description | Status |
|-----------------|-------------|--------|
| `test_cert_loading` | LoadFileContents (valid/invalid file), CertConfig::FromEnv | 4 passed |
| `test_metrics` | GetNegotiatedGroupName(null SSL) → `"unknown"` | 1 passed |
| `test_tls_handshake` | Integration: RSA certs, server+client PQC-enabled, ProcessData; assert negotiated_group | Passed |
| `test_fallback` | Integration: server/client use PQC-enabled vs PQC-disabled API; assert RPC succeeds and reported group is classical or unknown (pqc_enabled is unused; server does not report real group) | Passed |
| `test_legacy_rsa_client` | E2E: legacy client (RSA + classical creds) vs server (RSA + PQC offered); assert RPC succeeds | Passed |

**How to run:** With dependencies and env set (see tasks file):

```bash
ctest --test-dir build --output-on-failure
```

Integration tests use `PQC_PROJECT_SOURCE_DIR` (set by CTest) to run `scripts/generate_rsa_certs.sh` with `PQC_CERTS_DIR` for temporary certs.

---

## Build artifacts

- **Libraries:** `libpqc_proto.a`, `libpqc_common.a`
- **Executables:** `service_a`, `service_b` (require certs and env at runtime: `PQC_CERT_PATH`, `PQC_KEY_PATH`, `PQC_CA_PATH`)
- **Tests:** `test_cert_loading`, `test_metrics`, `test_tls_handshake`, `test_fallback`, `test_legacy_rsa_client`

---

## Next work (future)

No remaining tasks from the original 0–9 list. Future work is described in **README.md** (Future roadmap): ML-DSA certificate integration, FIPS 140-3, composite signatures, production rollout (hardening, key rotation, monitoring).

---

## Proof of hybrid PQC (quantum-safe TLS)

With OpenSSL 3.5.5 and `PQC_VALIDATE_USE_OPENSSL_SERVER=1`, `scripts/validate_tls.sh` prints the negotiated TLS 1.3 group (e.g. **X25519MLKEM768**). Captured success output and how to reproduce: **`docs/BUILD.md`** → **Proof of hybrid PQC (quantum-safe TLS)**.

---

## References

- **Task list and build notes:** `tasks/tasks-quantum-safe-grpc-pqc.md`
- **Build commands and env:** `docs/BUILD.md`, **Build and implementation notes** in tasks file
- **Dependencies:** `docs/DEPENDENCIES.md`, `scripts/check_installed_versions.sh`
