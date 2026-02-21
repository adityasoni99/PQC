#include "service_b/service_b_impl.h"
#include "common/tls_config.h"
#include <grpcpp/channel.h>
#include <grpcpp/client_context.h>
#include <grpcpp/create_channel.h>
#include <grpcpp/grpcpp.h>

namespace pqc {
namespace serviceb {

namespace {

std::string GetNegotiatedGroupFromContext(::grpc::ServerContext* context) {
  (void)context;
  return "unknown";
}

}  // namespace

ServiceBImpl::ServiceBImpl(const std::string& service_a_address,
                           const pqc_common::CertConfig& cert_config)
    : service_a_address_(service_a_address), cert_config_(cert_config) {}

::grpc::Status ServiceBImpl::ForwardRequest(::grpc::ServerContext* context,
                                            const ::pqc::serviceb::ForwardReq* request,
                                            ::pqc::serviceb::ForwardResp* response) {
  std::string service_b_group = GetNegotiatedGroupFromContext(context);

  auto creds = pqc_common::CreateChannelCredentials(cert_config_, true);
  if (!creds) {
    return ::grpc::Status(::grpc::StatusCode::INTERNAL, "Failed to create channel credentials");
  }

  auto channel = grpc::CreateChannel(service_a_address_, creds);
  auto stub = pqc::servicea::ServiceA::NewStub(channel);

  ::pqc::servicea::DataRequest data_req;
  data_req.set_payload(request->payload());

  ::pqc::servicea::DataResponse data_resp;
  ::grpc::ClientContext client_ctx;
  ::grpc::Status status = stub->ProcessData(&client_ctx, data_req, &data_resp);

  if (!status.ok()) {
    return status;
  }

  response->set_result(data_resp.result());
  response->set_service_a_group(data_resp.negotiated_group());
  response->set_service_b_group(service_b_group);
  return ::grpc::Status::OK;
}

}  // namespace serviceb
}  // namespace pqc
