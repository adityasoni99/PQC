#include "common/tls_metrics.h"
#include <openssl/ssl.h>
#include <openssl/objects.h>
#include <iostream>

std::string GetNegotiatedGroupName(SSL* ssl) {
    if (!ssl) return "unknown";
    int group_nid = SSL_get_negotiated_group(ssl);
    if (group_nid == 0) return "unknown";
    const char* name = OBJ_nid2sn(group_nid);
    return name ? std::string(name) : "unknown";
}

void LogNegotiatedGroup(SSL* ssl) {
    std::string group = GetNegotiatedGroupName(ssl);
    std::cout << "[TLS-METRICS] Negotiated group: " << group << std::endl;
}

void LogNegotiatedGroupName(const std::string& group_name) {
    std::cout << "[TLS-METRICS] Negotiated group: " << group_name << std::endl;
}
