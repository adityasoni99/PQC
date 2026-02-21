cmake_minimum_required(VERSION 3.22)
project(pqc_proto)

find_package(gRPC REQUIRED)

set(PROTO_FILES
  ${CMAKE_CURRENT_SOURCE_DIR}/service_a.proto
  ${CMAKE_CURRENT_SOURCE_DIR}/service_b.proto
)

# Generate .pb.cc and .pb.h in this dir (same scope as target so dependencies resolve).
foreach(proto_file ${PROTO_FILES})
  get_filename_component(proto_name ${proto_file} NAME_WE)
  set(pb_src "${CMAKE_CURRENT_BINARY_DIR}/${proto_name}.pb.cc")
  set(pb_hdr "${CMAKE_CURRENT_BINARY_DIR}/${proto_name}.pb.h")
  add_custom_command(
    OUTPUT ${pb_src} ${pb_hdr}
    COMMAND protobuf::protoc
      --proto_path=${CMAKE_CURRENT_SOURCE_DIR}
      --cpp_out=${CMAKE_CURRENT_BINARY_DIR}
      ${proto_file}
    DEPENDS ${proto_file}
    COMMENT "Generating C++ sources for ${proto_file}"
    VERBATIM
  )
  list(APPEND PROTO_SRCS ${pb_src})
  list(APPEND PROTO_HDRS ${pb_hdr})
endforeach()

# Generate gRPC sources using protoc
foreach(proto_file ${PROTO_FILES})
  get_filename_component(proto_name ${proto_file} NAME_WE)
  set(grpc_src "${CMAKE_CURRENT_BINARY_DIR}/${proto_name}.grpc.pb.cc")
  set(grpc_hdr "${CMAKE_CURRENT_BINARY_DIR}/${proto_name}.grpc.pb.h")
  add_custom_command(
    OUTPUT ${grpc_src} ${grpc_hdr}
    COMMAND protobuf::protoc
      --proto_path=${CMAKE_CURRENT_SOURCE_DIR}
      --grpc_out=${CMAKE_CURRENT_BINARY_DIR}
      --plugin=protoc-gen-grpc=$<TARGET_FILE:gRPC::grpc_cpp_plugin>
      ${proto_file}
    DEPENDS ${proto_file}
    COMMENT "Generating gRPC sources for ${proto_file}"
    VERBATIM
  )
  list(APPEND GRPC_SRCS ${grpc_src})
  list(APPEND GRPC_HDRS ${grpc_hdr})
endforeach()

add_library(pqc_proto STATIC
  ${PROTO_SRCS}
  ${PROTO_HDRS}
  ${GRPC_SRCS}
  ${GRPC_HDRS}
)

target_link_libraries(pqc_proto
  PUBLIC
    protobuf::libprotobuf
    gRPC::grpc++
)

target_include_directories(pqc_proto PUBLIC ${CMAKE_CURRENT_BINARY_DIR})
