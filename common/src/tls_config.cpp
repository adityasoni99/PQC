#include "common/tls_config.h"
#include "common/cert_loader.h"
#include <grpcpp/security/credentials.h>
#include <grpcpp/security/server_credentials.h>
#include <memory>
#include <string>
#include <iostream>

namespace pqc_common {

std::shared_ptr<grpc::ServerCredentials> CreateServerCredentials(const CertConfig& config, bool pqc_enabled) {
    (void)pqc_enabled;  // PQC group order requires SSL_CTX access; gRPC C++ API does not expose it.
    grpc::SslServerCredentialsOptions::PemKeyCertPair pair;
    pair.private_key = LoadFileContents(config.private_key_path);
    pair.cert_chain = LoadFileContents(config.cert_chain_path);
    grpc::SslServerCredentialsOptions opts(GRPC_SSL_REQUEST_AND_REQUIRE_CLIENT_CERTIFICATE_AND_VERIFY);
    opts.pem_root_certs = LoadFileContents(config.ca_cert_path);
    opts.pem_key_cert_pairs.push_back(std::move(pair));
    return grpc::SslServerCredentials(opts);
}

std::shared_ptr<grpc::ChannelCredentials> CreateChannelCredentials(const CertConfig& config, bool pqc_enabled) {
    (void)pqc_enabled;  // PQC group order requires SSL_CTX access; gRPC C++ API does not expose it.
    grpc::SslCredentialsOptions opts;
    opts.pem_root_certs = LoadFileContents(config.ca_cert_path);
    opts.pem_private_key = LoadFileContents(config.private_key_path);
    opts.pem_cert_chain = LoadFileContents(config.cert_chain_path);
    return grpc::SslCredentials(opts);
}

}  // namespace pqc_common
