#include "service_a/service_a_impl.h"
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

static const int kDefaultPort = 50051;

int main(int argc, char** argv) {
  int port = kDefaultPort;
  for (int i = 1; i < argc; ++i) {
    std::string arg = argv[i];
    if (arg == "--port" && i + 1 < argc) {
      port = std::atoi(argv[++i]);
      break;
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
  pqc::servicea::ServiceAImpl service;
  builder.RegisterService(&service);

  std::unique_ptr<grpc::Server> server(builder.BuildAndStart());
  if (!server) {
    std::cerr << "Failed to start server" << std::endl;
    return 1;
  }

  std::cout << "ServiceA listening on " << server_address << std::endl;
  server->Wait();
  return 0;
}
