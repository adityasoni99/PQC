cmake_minimum_required(VERSION 3.22)
project(pqc_common)

add_library(pqc_common STATIC
	src/cert_loader.cpp
	src/tls_config.cpp
	src/tls_metrics.cpp
)

target_include_directories(pqc_common PUBLIC include)

find_package(OpenSSL 3.5 REQUIRED)
find_package(gRPC REQUIRED)

target_link_libraries(pqc_common
	PUBLIC
		OpenSSL::SSL
		OpenSSL::Crypto
		gRPC::grpc++
		gRPC::grpc
)
