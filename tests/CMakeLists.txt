cmake_minimum_required(VERSION 3.22)
project(pqc_tests)

include(FetchContent)
FetchContent_Declare(
	googletest
	URL https://github.com/google/googletest/archive/refs/tags/v1.14.0.zip
)
FetchContent_MakeAvailable(googletest)

enable_testing()

add_executable(test_cert_loading test_cert_loading.cpp)
target_link_libraries(test_cert_loading PRIVATE pqc_common gtest_main)

add_executable(test_metrics test_metrics.cpp)
target_link_libraries(test_metrics PRIVATE pqc_common gtest_main)

# Integration tests: need ServiceA impl and proto, generate certs via script.
set(SERVICE_A_IMPL_SRC ${CMAKE_SOURCE_DIR}/service_a/src/service_a_impl.cpp)

add_executable(test_tls_handshake test_tls_handshake.cpp ${SERVICE_A_IMPL_SRC})
target_include_directories(test_tls_handshake PRIVATE ${CMAKE_SOURCE_DIR}/service_a/include)
target_link_libraries(test_tls_handshake PRIVATE pqc_common pqc_proto gtest_main)

add_executable(test_fallback test_fallback.cpp ${SERVICE_A_IMPL_SRC})
target_include_directories(test_fallback PRIVATE ${CMAKE_SOURCE_DIR}/service_a/include)
target_link_libraries(test_fallback PRIVATE pqc_common pqc_proto gtest_main)

add_executable(test_legacy_rsa_client test_legacy_rsa_client.cpp ${SERVICE_A_IMPL_SRC})
target_include_directories(test_legacy_rsa_client PRIVATE ${CMAKE_SOURCE_DIR}/service_a/include)
target_link_libraries(test_legacy_rsa_client PRIVATE pqc_common pqc_proto gtest_main)

add_test(NAME test_cert_loading COMMAND test_cert_loading)
add_test(NAME test_metrics COMMAND test_metrics)
add_test(NAME test_tls_handshake COMMAND test_tls_handshake)
add_test(NAME test_fallback COMMAND test_fallback)
add_test(NAME test_legacy_rsa_client COMMAND test_legacy_rsa_client)

# Pass project root so integration tests can run generate_rsa_certs.sh.
set(PQC_PROJECT_ENV "PQC_PROJECT_SOURCE_DIR=${CMAKE_SOURCE_DIR}")
set_tests_properties(test_tls_handshake test_fallback test_legacy_rsa_client
  PROPERTIES ENVIRONMENT "${PQC_PROJECT_ENV}")

# Ensure test executables are built by default
add_custom_target(run_tests ALL
	DEPENDS test_cert_loading test_metrics test_tls_handshake test_fallback test_legacy_rsa_client
)
