#include "service_a/service_a_impl.h"
#include "common/tls_metrics.h"
#include <grpcpp/grpcpp.h>

namespace pqc {
namespace servicea {

namespace {

// gRPC C++ ServerContext does not expose the underlying SSL* for the connection.
// We log the group name when available; until then we use "unknown".
std::string GetNegotiatedGroupFromContext(::grpc::ServerContext* context) {
  (void)context;
  return "unknown";
}

}  // namespace

::grpc::Status ServiceAImpl::ProcessData(::grpc::ServerContext* context,
                                         const ::pqc::servicea::DataRequest* request,
                                         ::pqc::servicea::DataResponse* response) {
  std::string group = GetNegotiatedGroupFromContext(context);
  LogNegotiatedGroupName(group);

  response->set_result(request->payload());
  response->set_negotiated_group(group);
  return ::grpc::Status::OK;
}

}  // namespace servicea
}  // namespace pqc
