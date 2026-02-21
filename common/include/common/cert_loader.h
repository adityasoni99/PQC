#ifndef PQC_COMMON_CERT_LOADER_H
#define PQC_COMMON_CERT_LOADER_H

#include <string>
#include <stdexcept>
#include <cstdlib>

namespace pqc_common {

// Loads the entire contents of a file at the given path into a string.
// Throws std::runtime_error on failure.
std::string LoadFileContents(const std::string& path);

struct CertConfig {
    std::string cert_chain_path;
    std::string private_key_path;
    std::string ca_cert_path;

    // Factory: Populate from environment variables PQC_CERT_PATH, PQC_KEY_PATH, PQC_CA_PATH
    static CertConfig FromEnv();
};

} // namespace pqc_common

#endif // PQC_COMMON_CERT_LOADER_H
