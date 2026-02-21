#ifndef PQC_COMMON_TLS_CONFIG_H
#define PQC_COMMON_TLS_CONFIG_H

#include <memory>
#include <grpcpp/grpcpp.h>
#include "common/cert_loader.h"

namespace pqc_common {

// Creates gRPC server credentials with hybrid PQC groups if pqc_enabled is true.
std::shared_ptr<grpc::ServerCredentials> CreateServerCredentials(const CertConfig& config, bool pqc_enabled = true);

// Creates gRPC channel credentials with hybrid PQC groups if pqc_enabled is true.
std::shared_ptr<grpc::ChannelCredentials> CreateChannelCredentials(const CertConfig& config, bool pqc_enabled = true);

} // namespace pqc_common

#endif // PQC_COMMON_TLS_CONFIG_H
