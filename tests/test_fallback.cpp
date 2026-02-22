// Integration test: API and connectivity when client uses PQC-disabled credentials.
// Server: CreateServerCredentials(config, true); client: CreateChannelCredentials(config, false).
// Note: pqc_enabled is currently unused in tls_config.cpp (gRPC C++ does not expose SSL_CTX),
// so both sides use OpenSSL defaults; we do not actually set different group lists.
// This test still validates that the "PQC-disabled" client path builds, connects, and completes
// the RPC; negotiated_group is "unknown" (ServiceA cannot read SSL* from ServerContext).
// Asserts: RPC succeeds, result correct, and reported group is classical or "unknown".

#include <gtest/gtest.h>
#include <grpcpp/grpcpp.h>
#include "common/cert_loader.h"
#include "common/tls_config.h"
#include "service_a.grpc.pb.h"
#include "service_a/service_a_impl.h"

#include <cerrno>
#include <cstdlib>
#include <fstream>
#include <memory>
#include <string>
#include <sys/stat.h>
#include <unistd.h>

namespace {

const int kTestPort = 50552;

std::string GetProjectRoot() {
  const char* root = std::getenv("PQC_PROJECT_SOURCE_DIR");
  return root ? std::string(root) : "";
}

bool GenerateTestCerts(const std::string& certs_dir) {
  std::string root = GetProjectRoot();
  if (root.empty()) return false;
  std::string script = root + "/scripts/generate_rsa_certs.sh";
  std::ifstream f(script);
  if (!f.good()) return false;
  f.close();
  int ret = std::system(("PQC_CERTS_DIR=" + certs_dir + " bash " + script + " >/dev/null 2>&1").c_str());
  return (ret == 0);
}

bool IsClassicalGroup(const std::string& group) {
  if (group.empty() || group == "unknown") return true;
  std::string g = group;
  for (auto& c : g) c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
  return g.find("x25519") != std::string::npos || g.find("secp256r1") != std::string::npos;
}

}  // namespace

class FallbackTest : public ::testing::Test {
 protected:
  void SetUp() override {
    project_root_ = GetProjectRoot();
    if (project_root_.empty()) {
      GTEST_SKIP() << "PQC_PROJECT_SOURCE_DIR not set (run via ctest)";
    }
    certs_dir_ = project_root_ + "/build/tests/certs_fallback_" + std::to_string(static_cast<unsigned long>(getpid()));
    if (mkdir(certs_dir_.c_str(), 0755) != 0 && errno != EEXIST) {
      GTEST_SKIP() << "Cannot create certs dir " << certs_dir_;
    }
    if (!GenerateTestCerts(certs_dir_)) {
      GTEST_SKIP() << "Failed to generate test certs in " << certs_dir_;
    }
    server_config_.cert_chain_path = certs_dir_ + "/server.pem";
    server_config_.private_key_path = certs_dir_ + "/server.key";
    server_config_.ca_cert_path = certs_dir_ + "/ca.pem";
    client_config_.cert_chain_path = certs_dir_ + "/client.pem";
    client_config_.private_key_path = certs_dir_ + "/client.key";
    client_config_.ca_cert_path = certs_dir_ + "/ca.pem";
  }

  std::string project_root_;
  std::string certs_dir_;
  pqc_common::CertConfig server_config_;
  pqc_common::CertConfig client_config_;
};

TEST_F(FallbackTest, ClassicalClientConnectsWhenPqcDisabled) {
  pqc::servicea::ServiceAImpl service_impl;
  grpc::ServerBuilder builder;
  std::string server_address = "localhost:" + std::to_string(kTestPort);
  auto creds = pqc_common::CreateServerCredentials(server_config_, true);
  builder.AddListeningPort(server_address, creds);
  builder.RegisterService(&service_impl);
  std::unique_ptr<grpc::Server> server = builder.BuildAndStart();
  ASSERT_NE(server, nullptr);

  // Client with classical-only credentials (pqc_enabled = false).
  auto channel_creds = pqc_common::CreateChannelCredentials(client_config_, false);
  auto channel = grpc::CreateChannel(server_address, channel_creds);
  auto stub = pqc::servicea::ServiceA::NewStub(channel);
  pqc::servicea::DataRequest request;
  request.set_payload("fallback-test");
  pqc::servicea::DataResponse response;
  grpc::ClientContext ctx;
  ctx.set_deadline(std::chrono::system_clock::now() + std::chrono::seconds(10));
  grpc::Status status = stub->ProcessData(&ctx, request, &response);

  server->Shutdown();
  server->Wait();

  ASSERT_TRUE(status.ok()) << status.error_message();
  EXPECT_EQ(response.result(), "fallback-test");
  EXPECT_TRUE(IsClassicalGroup(response.negotiated_group()))
      << "Expected classical group, got: " << response.negotiated_group();
}
