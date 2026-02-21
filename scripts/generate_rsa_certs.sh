#!/usr/bin/env bash
# Generate RSA CA (4096), server (2048), and client (2048) certificates for TLS.
# Output: certs/ca.pem, certs/ca.key, certs/server.pem, certs/server.key,
#         certs/client.pem, certs/client.key.
# Use: PQC_CERT_PATH=certs/server.pem PQC_KEY_PATH=certs/server.key PQC_CA_PATH=certs/ca.pem

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# Allow tests to override output directory (e.g. PQC_CERTS_DIR=/tmp/pqc-certs-xyz)
CERTS_DIR="${PQC_CERTS_DIR:-${REPO_ROOT}/certs}"
DAYS=365
SUBJ_CA="/CN=PQC-Test-CA"
SUBJ_SERVER="/CN=localhost"
SUBJ_CLIENT="/CN=PQC-Test-Client"

mkdir -p "$CERTS_DIR"
cd "$CERTS_DIR"

# CA: RSA 4096
openssl genrsa -out ca.key 4096
openssl req -new -x509 -key ca.key -out ca.pem -days "$DAYS" -subj "$SUBJ_CA"

# Server: RSA 2048, signed by CA; SANs for localhost and Docker hostnames (service_a, service_b)
openssl genrsa -out server.key 2048
echo "[req]
distinguished_name = dn
req_extensions = ext
[dn]
CN = localhost
[ext]
subjectAltName = DNS:localhost,DNS:service_a,DNS:service_b,IP:127.0.0.1" > server_san.cnf
openssl req -new -key server.key -out server.csr -subj "$SUBJ_SERVER" -config server_san.cnf
openssl x509 -req -in server.csr -CA ca.pem -CAkey ca.key -CAcreateserial -out server.pem -days "$DAYS" -extfile server_san.cnf -extensions ext
rm -f server.csr server_san.cnf

# Client: RSA 2048, signed by CA
openssl genrsa -out client.key 2048
openssl req -new -key client.key -out client.csr -subj "$SUBJ_CLIENT"
openssl x509 -req -in client.csr -CA ca.pem -CAkey ca.key -CAcreateserial -out client.pem -days "$DAYS"
rm -f client.csr

# Remove CA serial artifact if created
rm -f ca.srl

echo "RSA certificates written to $CERTS_DIR"
echo "  CA:       ca.pem, ca.key"
echo "  Server:   server.pem, server.key  (use for PQC_CERT_PATH / PQC_KEY_PATH)"
echo "  Client:   client.pem, client.key"
echo "  Set:      PQC_CERT_PATH=$CERTS_DIR/server.pem PQC_KEY_PATH=$CERTS_DIR/server.key PQC_CA_PATH=$CERTS_DIR/ca.pem"
