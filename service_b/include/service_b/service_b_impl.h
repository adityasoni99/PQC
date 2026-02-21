#ifndef PQC_SERVICE_B_SERVICE_B_IMPL_H
#define PQC_SERVICE_B_SERVICE_B_IMPL_H

#include "common/cert_loader.h"
#include "service_a.grpc.pb.h"
#include "service_b.grpc.pb.h"
#include <memory>
#include <string>

namespace pqc {
namespace serviceb {

class ServiceBImpl : public ServiceB::Service {
 public:
  explicit ServiceBImpl(const std::string& service_a_address,
                        const pqc_common::CertConfig& cert_config);

  ::grpc::Status ForwardRequest(::grpc::ServerContext* context,
                                const ::pqc::serviceb::ForwardReq* request,
                                ::pqc::serviceb::ForwardResp* response) override;

 private:
  std::string service_a_address_;
  pqc_common::CertConfig cert_config_;
};

}  // namespace serviceb
}  // namespace pqc

#endif  // PQC_SERVICE_B_SERVICE_B_IMPL_H
