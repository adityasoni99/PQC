
cmake_minimum_required(VERSION 3.22)
project(PQC_gRPC LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# System-installed dependencies. Required versions:
#   gRPC     1.75.1   (install via scripts/install_grpc_deps.sh — use git clone + submodules, not tarball)
#   Protobuf 31.1     https://github.com/protocolbuffers/protobuf/releases/download/v31.1/protobuf-31.1.tar.gz
#   Abseil  20250512.1  https://github.com/abseil/abseil-cpp/releases/download/20250512.1/abseil-cpp-20250512.1.tar.gz
# See docs/DEPENDENCIES.md for full install instructions.
# Find OpenSSL first so gRPC config can resolve OpenSSL::SSL (must create OpenSSL::SSL target).
list(APPEND CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/cmake")
find_package(OpenSSL 3.5 REQUIRED)
find_package(OpenSSL35 REQUIRED)

# Protobuf and Abseil via CONFIG (avoids FindProtobuf 6.31.1 vs 31.1 and mixed target redefinition).
find_package(Protobuf CONFIG REQUIRED)
if(Protobuf_VERSION VERSION_LESS 31.1)
  message(FATAL_ERROR "Protobuf ${Protobuf_VERSION} found; project requires 31.1. Run scripts/check_installed_versions.sh.")
endif()
find_package(absl CONFIG REQUIRED)
if(absl_VERSION VERSION_LESS 20250512)
  message(FATAL_ERROR "Abseil ${absl_VERSION} found; project requires 20250512 or later.")
endif()
find_package(gRPC 1.75.1 REQUIRED)

enable_testing()
add_subdirectory(proto)
add_subdirectory(common)
add_subdirectory(service_a)
add_subdirectory(service_b)
add_subdirectory(tests)
