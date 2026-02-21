#ifndef PQC_SERVICE_A_SERVICE_A_IMPL_H
#define PQC_SERVICE_A_SERVICE_A_IMPL_H

#include "service_a.grpc.pb.h"

namespace pqc {
namespace servicea {

class ServiceAImpl : public ServiceA::Service {
 public:
  ::grpc::Status ProcessData(::grpc::ServerContext* context,
                             const ::pqc::servicea::DataRequest* request,
                             ::pqc::servicea::DataResponse* response) override;
};

}  // namespace servicea
}  // namespace pqc

#endif  // PQC_SERVICE_A_SERVICE_A_IMPL_H
