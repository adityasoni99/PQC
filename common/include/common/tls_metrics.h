#ifndef PQC_COMMON_TLS_METRICS_H
#define PQC_COMMON_TLS_METRICS_H

#include <string>
struct ssl_st;  // Forward declaration for OpenSSL SSL*

// Non-template overload (defined in .cpp); use for linking from tests.
std::string GetNegotiatedGroupName(ssl_st* ssl);

template <typename SSL_TYPE = ssl_st>
std::string GetNegotiatedGroupName(SSL_TYPE* ssl);

template <typename SSL_TYPE = ssl_st>
void LogNegotiatedGroup(SSL_TYPE* ssl);

// Log a pre-resolved group name (e.g. when SSL* is not available from gRPC context).
void LogNegotiatedGroupName(const std::string& group_name);

#endif // PQC_COMMON_TLS_METRICS_H
