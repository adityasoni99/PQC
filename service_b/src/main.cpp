#include "service_b/service_b_impl.h"
#include "common/cert_loader.h"
#include "common/tls_config.h"
#include <grpcpp/grpcpp.h>
#include <grpcpp/server.h>
#include <grpcpp/server_builder.h>
#include <grpcpp/server_context.h>
#include <iostream>
#include <memory>
#include <string>
#include <cstdlib>

static const int kDefaultPort = 50052;
static const char kDefaultServiceAAddr[] = "localhost:50051";

int main(int argc, char** argv) {
  int port = kDefaultPort;
  std::string service_a_addr = kDefaultServiceAAddr;

  for (int i = 1; i < argc; ++i) {
    std::string arg = argv[i];
    if (arg == "--port" && i + 1 < argc) {
      port = std::atoi(argv[++i]);
    } else if (arg == "--service-a-addr" && i + 1 < argc) {
      service_a_addr = argv[++i];
    }
  }

  pqc_common::CertConfig config;
  try {
    config = pqc_common::CertConfig::FromEnv();
  } catch (const std::exception& e) {
    std::cerr << "Certificate config failed: " << e.what() << std::endl;
    return 1;
  }

  auto creds = pqc_common::CreateServerCredentials(config, true);
  if (!creds) {
    std::cerr << "Failed to create server credentials" << std::endl;
    return 1;
  }

  std::string server_address = "0.0.0.0:" + std::to_string(port);
  grpc::ServerBuilder builder;
  builder.AddListeningPort(server_address, creds);
  pqc::serviceb::ServiceBImpl service(service_a_addr, config);
  builder.RegisterService(&service);

  std::unique_ptr<grpc::Server> server(builder.BuildAndStart());
  if (!server) {
    std::cerr << "Failed to start server" << std::endl;
    return 1;
  }

  std::cout << "ServiceB listening on " << server_address
            << ", forwarding to ServiceA at " << service_a_addr << std::endl;
  server->Wait();
  return 0;
}
