#include "common/cert_loader.h"
#include <fstream>
#include <sstream>

namespace pqc_common {

std::string LoadFileContents(const std::string& path) {
    std::ifstream file(path, std::ios::in | std::ios::binary);
    if (!file) {
        throw std::runtime_error("Failed to open file: " + path);
    }
    std::ostringstream ss;
    ss << file.rdbuf();
    return ss.str();
}

CertConfig CertConfig::FromEnv() {
    const char* cert = std::getenv("PQC_CERT_PATH");
    const char* key = std::getenv("PQC_KEY_PATH");
    const char* ca = std::getenv("PQC_CA_PATH");
    if (!cert || !key || !ca) {
        throw std::runtime_error("Missing one or more PQC cert env vars: PQC_CERT_PATH, PQC_KEY_PATH, PQC_CA_PATH");
    }
    return CertConfig{cert, key, ca};
}

} // namespace pqc_common
