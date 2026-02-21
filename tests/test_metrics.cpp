#include <gtest/gtest.h>
#include "common/tls_metrics.h"

TEST(TlsMetricsTest, GetNegotiatedGroupName_NullSSL) {
    EXPECT_EQ(GetNegotiatedGroupName(static_cast<ssl_st*>(nullptr)), "unknown");
}

// Real SSL group name is tested in integration test (test_tls_handshake)
