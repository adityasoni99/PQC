cmake_minimum_required(VERSION 3.22)

add_executable(service_b
  src/main.cpp
  src/service_b_impl.cpp
)

target_include_directories(service_b PRIVATE
  ${CMAKE_CURRENT_SOURCE_DIR}/include
)

target_link_libraries(service_b PRIVATE
  pqc_proto
  pqc_common
)
