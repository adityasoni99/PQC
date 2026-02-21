// Integration test: hybrid PQC TLS handshake between client and server.
// Generates temporary RSA certs, starts in-process gRPC server with PQC-enabled
// credentials, connects client with PQC-enabled credentials, calls ProcessData,
// and asserts success and that negotiated_group is present (or "unknown" until
// server exposes real group).

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

const int kTestPort = 50551;

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

}  // namespace

class TlsHandshakeTest : public ::testing::Test {
 protected:
  void SetUp() override {
    project_root_ = GetProjectRoot();
    if (project_root_.empty()) {
      GTEST_SKIP() << "PQC_PROJECT_SOURCE_DIR not set (run via ctest)";
    }
    certs_dir_ = project_root_ + "/build/tests/certs_handshake_" + std::to_string(static_cast<unsigned long>(getpid()));
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

TEST_F(TlsHandshakeTest, HybridHandshakeAndProcessDataSucceeds) {
  pqc::servicea::ServiceAImpl service_impl;
  grpc::ServerBuilder builder;
  std::string server_address = "localhost:" + std::to_string(kTestPort);
  auto creds = pqc_common::CreateServerCredentials(server_config_, true);
  builder.AddListeningPort(server_address, creds);
  builder.RegisterService(&service_impl);
  std::unique_ptr<grpc::Server> server = builder.BuildAndStart();
  ASSERT_NE(server, nullptr);

  auto channel_creds = pqc_common::CreateChannelCredentials(client_config_, true);
  auto channel = grpc::CreateChannel(server_address, channel_creds);
  auto stub = pqc::servicea::ServiceA::NewStub(channel);
  pqc::servicea::DataRequest request;
  request.set_payload("hello-pqc");
  pqc::servicea::DataResponse response;
  grpc::ClientContext ctx;
  ctx.set_deadline(std::chrono::system_clock::now() + std::chrono::seconds(10));
  grpc::Status status = stub->ProcessData(&ctx, request, &response);

  server->Shutdown();
  server->Wait();

  ASSERT_TRUE(status.ok()) << status.error_message();
  EXPECT_EQ(response.result(), "hello-pqc");
  // Server currently returns "unknown" for negotiated_group (gRPC C++ does not expose SSL*).
  // When server reports real group, it should contain MLKEM or X25519MLKEM768.
  EXPECT_FALSE(response.negotiated_group().empty());
  if (response.negotiated_group() != "unknown") {
    EXPECT_TRUE(response.negotiated_group().find("MLKEM") != std::string::npos ||
                response.negotiated_group().find("X25519MLKEM768") != std::string::npos)
        << "negotiated_group: " << response.negotiated_group();
  }
}
