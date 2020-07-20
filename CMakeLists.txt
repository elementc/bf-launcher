cmake_minimum_required(VERSION 3.15)
project(bf_launcher)

include(build/grpc-protobuf-managed.cmake)

# Process our Protobuf definitions.
generate_cpp_from_protofile(src/steam.proto)

# Include generated *.pb.h files
include_directories("${generated_protobuf_header_dir}")

# The main application.
add_executable(bf_launcher src/bf_launcher.cc ${generated_pb_srcs} ${generated_grpc_srcs})
target_link_libraries(bf_launcher ${GRPC_LIBRARY} ${PROTOBUF_LIBRARY} )