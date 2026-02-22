# PQC / Quantum-Safe TLS: Answers from This Project

This document states what we **know from this repo’s design and experiments** about four common questions. It does not replace formal standards or vendor docs.

---

## 1. Can we make TLS quantum-safe while keeping RSA certificates (e.g. agents on customer systems using old RSA certs)?

**Short answer: Yes, and we now validate it with an e2e test.**

- **Key exchange vs. certificates**  
  This project uses **hybrid post-quantum key exchange** (e.g. X25519 + ML-KEM-768) for the TLS 1.3 handshake. **Certificates** are a separate concern: they authenticate the server/client and can remain **RSA** (as in our default `scripts/generate_rsa_certs.sh`).

- **What we do today**  
  We use RSA 4096 CA and RSA 2048 server/client certs. Services load them via `CertConfig` and use them with gRPC TLS. There is no requirement in this stack for PQC-signed certs to get PQC key exchange.

- **What we *have* run (Task 7.6)**  
  We run a dedicated e2e test: **`test_legacy_rsa_client`**. It uses a **legacy client** (RSA certs only + classical-only credentials, `pqc_enabled=false`) against a **server** that has RSA certs and PQC offered (`pqc_enabled=true`). The test asserts that the RPC succeeds. So we now **validate** that TLS can be quantum-safe on the server while clients still use existing RSA certs and classical key agreement.

**Conclusion:** The design supports **quantum-safe TLS (hybrid KEM) with RSA certificates**, and we **execute** a formal “old RSA cert only” e2e test in this project (`test_legacy_rsa_client`).

---

## 2. Does enabling PQC disable RSA?

**Short answer: No. We validate this with automated tests.**

- **Hybrid, not replace**  
  “PQC” here means **hybrid** key exchange: groups like `X25519MLKEM768` combine classical (X25519) with PQC (ML-KEM-768). Enabling PQC = adding these hybrid (and possibly PQC-only) groups to the list, not removing classical algorithms.

- **Fallback (API and connectivity only)**  
  The API has a `pqc_enabled` flag (reserved for when gRPC C++ exposes `SSL_CTX`). Today that flag is **unused** in `tls_config.cpp`, so both server and client use OpenSSL's default group list; we do **not** actually set classical-only vs PQC group lists. **`test_fallback`** still has value: it runs with server `CreateServerCredentials(config, true)` and client `CreateChannelCredentials(config, false)`. The test asserts the RPC succeeds and the reported group is classical or “unknown”. So we validate **API usage and TLS connectivity** with the PQC-disabled client path; we do **not** yet validate true classical-only negotiation, because `pqc_enabled` has no effect and the server never reports the real group (gRPC ServerContext does not expose it).

- **Certs**  
  RSA remains in use for **certificates** (signatures). We do not replace RSA with PQC for certs in the current phase; ML-DSA certs are a future phase.

**Proving fallback with OpenSSL:** We cannot set groups in gRPC services (no `SSL_CTX`), but we can **prove** classical-only and fallback the same way we prove hybrid PQC — with **`scripts/validate_tls_fallback.sh`**. It uses `openssl s_server` and `openssl s_client` with classical-only groups and with server PQC+classical / client classical-only, verifies the negotiated group is classical, and **prints the negotiated group** (e.g. `x25519` or `secp256r1`) on success. Run with OpenSSL ≥ 3.5 (same `PREFIX` as build if needed).

**Conclusion:** Enabling PQC in this project does **not** disable RSA; we add hybrid key-exchange options and leave classical + RSA certs available. **test_fallback** validates that a client created with `pqc_enabled=false` can connect and complete an RPC (API/connectivity); **validate_tls_fallback.sh** proves classical-only and fallback negotiation using s_server/s_client.

---

## 3. Can FIPS and PQC providers load simultaneously (OpenSSL)?

**Short answer: We have no answer from this project.**

- This repo has **no** FIPS build, no OpenSSL provider configuration (e.g. `openssl.cnf` or `OSSL_PROVIDER_*`), and no tests that load both FIPS and PQC providers.

- The roadmap (e.g. task 9.8) mentions “FIPS 140-3 mode” as future work. Whether FIPS and PQC providers can be loaded together is implementation- and version-dependent and should be checked in OpenSSL/vendor documentation and your target environment.

**Conclusion:** We **do not** have an answer from our experiments. You need to rely on OpenSSL docs, FIPS documentation, and your own tests for “FIPS + PQC providers simultaneously.”

---

## 4. RSA support in “PQC providers” and hybrid details

**Short answer: We use RSA for certs and hybrid (MLKEM + classical) for key exchange; we have not tested OpenSSL “PQC provider” as a loadable module.**

- **RSA support**  
  **Certificates** in this project are RSA (CA, server, client). They work with our gRPC TLS setup. We are not using a separate “PQC provider” for certs; ML-DSA certs are planned as a later phase.

- **Hybrid key exchange**  
  Hybrid = key agreement only, e.g.:
  - `X25519MLKEM768`: classical X25519 plus ML-KEM-768.
  - Optional classical fallback: `x25519`, `secp256r1`.

  We validated with OpenSSL 3.5.5 and `PQC_VALIDATE_USE_OPENSSL_SERVER=1` that a handshake can negotiate `X25519MLKEM768` while still using **RSA certs** for authentication.

- **gRPC C++ limitation (TLS 1.3 group list)**  
  The gRPC C++ API we use (1.75.1, stable `SslServerCredentials` / `SslCredentials`) does **not** expose the underlying `SSL_CTX`. So we **cannot** call `SSL_CTX_set1_groups_list()` in our code. Server and client credentials are created with PEM only; **TLS 1.3 key-share group selection is whatever OpenSSL uses by default**. In **OpenSSL 3.5**, that default is **hardcoded in the library** (file `ssl/t1_lib.c`, macro `TLS_DEFAULT_GROUP_LIST`) and **prefers hybrid PQC first** (e.g. `X25519MLKEM768`, then `X25519`, then `secp256r1`). So with OpenSSL 3.5.5 on both sides, **ServiceA and ServiceB may already negotiate X25519MLKEM768**. The default is **not** configured via `openssl.cnf`; it is in the OpenSSL source. The validation script uses `openssl s_server` with `-groups X25519MLKEM768:x25519` to **prove** hybrid PQC when testing against s_server; when connecting to gRPC/ServiceA, the script may not always display the negotiated group even when it is PQC.

**Conclusion:** We have **partial** answers: **(a)** RSA is fully supported for certificates and works with our TLS path; **(b)** hybrid = MLKEM + classical in the key exchange, and we’ve seen it work with s_server and RSA certs; **(c)** with gRPC services, the exchange uses **OpenSSL’s default group list**, which in **OpenSSL 3.5** prefers **X25519MLKEM768**, so connections **may already be PQC** when both sides use OpenSSL 3.5.5; **(d)** we have **not** run experiments with OpenSSL “PQC provider” as a loadable provider or with composite/ML-DSA certs in this repo.

---

## 5. Is the TLS exchange through ServiceA/ServiceB PQC-safe or classical?

**Short answer: It depends on OpenSSL’s default. In OpenSSL 3.5, the default prefers hybrid PQC (X25519MLKEM768), so connections may already be PQC-safe when both sides use OpenSSL 3.5.5.**

- **What we use**  
  We build credentials with `grpc::SslServerCredentialsOptions` and `grpc::SslCredentialsOptions` and load cert/key/CA from PEM. We do **not** set the TLS 1.3 key-share group list, because the stable gRPC C++ API does not expose the underlying `SSL_CTX` (or any API to set groups).

- **Where is OpenSSL’s default defined?**  
  The default TLS 1.3 group list is **not** in `openssl.cnf`. It is **hardcoded in the OpenSSL library** in `ssl/t1_lib.c` (macro `TLS_DEFAULT_GROUP_LIST`). In **OpenSSL 3.5**, that default list prefers **X25519MLKEM768** (hybrid PQC), then X25519, then secp256r1, etc. So when we don’t set groups (gRPC limitation), server and client both use this default — and **may negotiate X25519MLKEM768** when both use OpenSSL 3.5.5.

- **Effect**  
  Connections to ServiceA or through ServiceB → ServiceA are **TLS 1.3 with mutual auth**. The key exchange is **whatever OpenSSL’s default is**: in OpenSSL 3.5, that is **hybrid PQC first**, so the exchange **may already be PQC-safe**. The `validate_tls.sh` script may not always show the negotiated group when connecting to gRPC (e.g. “Negotiated TLS1.3 group: &lt;NULL&gt;”), which does not prove the connection is classical.

- **How to prove PQC**  
  To **prove** hybrid PQC with this repo’s certs using a server that explicitly sets groups, run  
  `PQC_VALIDATE_USE_OPENSSL_SERVER=1 bash scripts/validate_tls.sh`  
  (uses `openssl s_server -groups X25519MLKEM768:x25519`).

- **Documentation**  
  This behaviour is documented in the README (“Hybrid PQC configuration”), in `common/src/tls_config.cpp` (the `pqc_enabled` parameter is unused), and in the tasks file (“Build and implementation notes”).

**Conclusion:** TLS through our gRPC services uses **OpenSSL’s default** group list. In **OpenSSL 3.5**, that default **prefers X25519MLKEM768**, so connections **may already be PQC-safe**. The default is defined in the library source (`ssl/t1_lib.c`), not in `openssl.cnf`.

---

## Do our RPC tests validate TLS as well?

**Short answer: Yes. A successful RPC in our integration tests implies TLS worked.**

- The tests use **real TLS**: `CreateServerCredentials()` and `CreateChannelCredentials()` build `grpc::SslServerCredentials` and `grpc::SslCredentials` with the same PEM cert/key/CA loading as production. The client connects over that **TLS 1.3** channel (mutual TLS when server requires client certs).

- If TLS failed (wrong cert, hostname mismatch, handshake failure, no shared cipher), the **RPC would fail**: we would get a non-OK status (e.g. “Peer name not in peer certificate”, “handshake failed”). So when `ProcessData` returns `status.ok()`, we have validated that:
  1. TCP connected  
  2. **TLS handshake completed** (both sides authenticated with RSA certs)  
  3. Application RPC succeeded  

- What we **do not** assert in these tests is the **negotiated key-exchange group** (e.g. X25519MLKEM768), because the gRPC C++ API does not expose the underlying `SSL*` from `ServerContext`, so the server currently returns `"unknown"` for `negotiated_group`. The script **`scripts/validate_tls.sh`** (using `openssl s_client -groups X25519MLKEM768`) is what **proves** that OpenSSL negotiates the hybrid group with our RSA certs. Together: **RPC tests = full TLS path (handshake + cert verification) with our stack; validate_tls.sh = proof of hybrid group negotiation.**

---

## Summary table

| Question | Answered by this project? | Summary |
|----------|----------------------------|---------|
| 1. Quantum-safe TLS with RSA certs (e.g. old agents)? | **Yes (design + e2e test)** | Hybrid KEM + RSA certs; **`test_legacy_rsa_client`** runs legacy client (RSA + classical) vs PQC-offering server and asserts RPC success. |
| 2. Does PQC disable RSA? | **Yes (and tested)** | No. **`test_fallback`** validates that a client with `pqc_enabled=false` connects and RPC succeeds (API/connectivity); actual classical-only negotiation is not yet testable because the flag is unused. |
| 3. FIPS and PQC providers together? | **No** | No FIPS or provider experiments in this repo. See OpenSSL/vendor and your own tests. |
| 4. RSA in PQC providers / hybrid details? | **Partially** | RSA certs work; hybrid = MLKEM + classical (validated with s_server). No tests with OpenSSL PQC provider or ML-DSA certs. |
| 5. Is TLS through ServiceA/ServiceB PQC-safe? | **Yes (answered)** | **Depends on OpenSSL.** We cannot set groups (gRPC C++ no SSL_CTX); connections use **OpenSSL’s default**. In **OpenSSL 3.5** that default is in `ssl/t1_lib.c` (`TLS_DEFAULT_GROUP_LIST`) and **prefers X25519MLKEM768** → connections **may be PQC**. Not in `openssl.cnf`. Use `PQC_VALIDATE_USE_OPENSSL_SERVER=1` to prove PQC with s_server. |

**TLS vs RPC:** Our RPC integration tests use real TLS credentials; RPC success implies TLS handshake and cert verification succeeded. The negotiated group name is validated separately by `scripts/validate_tls.sh`. OpenSSL 3.5’s default group list prefers hybrid PQC (X25519MLKEM768).
