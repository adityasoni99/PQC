#include <gtest/gtest.h>
#include "common/cert_loader.h"
#include <fstream>
#include <cstdlib>

using namespace pqc_common;

TEST(CertLoaderTest, LoadFileContents_ValidFile) {
    const std::string test_path = "test_cert.txt";
    std::ofstream ofs(test_path);
    ofs << "test123";
    ofs.close();
    std::string content = LoadFileContents(test_path);
    EXPECT_EQ(content, "test123");
    std::remove(test_path.c_str());
}

TEST(CertLoaderTest, LoadFileContents_InvalidFile) {
    EXPECT_THROW(LoadFileContents("nonexistent_file.txt"), std::runtime_error);
}

TEST(CertLoaderTest, CertConfig_FromEnv) {
    setenv("PQC_CERT_PATH", "cert.pem", 1);
    setenv("PQC_KEY_PATH", "key.pem", 1);
    setenv("PQC_CA_PATH", "ca.pem", 1);
    CertConfig config = CertConfig::FromEnv();
    EXPECT_EQ(config.cert_chain_path, "cert.pem");
    EXPECT_EQ(config.private_key_path, "key.pem");
    EXPECT_EQ(config.ca_cert_path, "ca.pem");
}

TEST(CertLoaderTest, CertConfig_FromEnv_Missing) {
    unsetenv("PQC_CERT_PATH");
    unsetenv("PQC_KEY_PATH");
    unsetenv("PQC_CA_PATH");
    EXPECT_THROW(CertConfig::FromEnv(), std::runtime_error);
}
