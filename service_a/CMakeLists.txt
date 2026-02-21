cmake_minimum_required(VERSION 3.22)

add_executable(service_a
  src/main.cpp
  src/service_a_impl.cpp
)

target_include_directories(service_a PRIVATE
  ${CMAKE_CURRENT_SOURCE_DIR}/include
)

target_link_libraries(service_a PRIVATE
  pqc_proto
  pqc_common
)
