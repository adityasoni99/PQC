# Custom FindOpenSSL35.cmake — enforces OpenSSL >= 3.5
find_package(OpenSSL 3.5 REQUIRED)
if (NOT OpenSSL_FOUND)
  message(FATAL_ERROR "OpenSSL >= 3.5 is required!")
endif()
add_compile_definitions(OPENSSL_35_AVAILABLE)
