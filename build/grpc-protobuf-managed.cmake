include(FetchContent)

# turn off some parts of gRPC we don't care about.

set(gRPC_BUILD_TESTS OFF)
# set(gRPC_BUILD_CODEGEN OFF)
set(gRPC_BUILD_CSHARP_EXT OFF)
set(gRPC_BUILD_GRPC_CSHARP_PLUGIN OFF)
set(gRPC_BUILD_GRPC_NODE_PLUGIN OFF)
set(gRPC_BUILD_GRPC_OBJECTIVE_C_PLUGIN OFF)
set(gRPC_BUILD_GRPC_PHP_PLUGIN OFF)
set(gRPC_BUILD_GRPC_PYTHON_PLUGIN OFF)
set(gRPC_BUILD_GRPC_RUBY_PLUGIN OFF)
set(gRPC_USE_PROTO_LITE ON)

FetchContent_Declare(
  gRPC
  GIT_REPOSITORY https://github.com/grpc/grpc
  GIT_TAG        v1.30.2
  )
set(FETCHCONTENT_QUIET OFF)
FetchContent_MakeAvailable(gRPC)

# Since FetchContent uses add_subdirectory under the hood, we can use
# the grpc and protobuf targets directly from this build.
set(_PROTOBUF_LIBPROTOBUF libprotobuf-lite)
set(PROTOBUF_LIBRARY libprotobuf-lite)
set(PROTOBUF_INCLUDE_DIR ${FETCHCONTENT_BASE_DIR}/grpc-src/third_party/protobuf/src)
set(_REFLECTION grpc++_reflection)
set(_PROTOBUF_PROTOC $<TARGET_FILE:protoc>)
set(_GRPC_GRPCPP grpc++)
set(GRPC_LIBRARY grpc++)
set(GRPC_INCLUDE_DIR ${FETCHCONTENT_BASE_DIR}/grpc-src/include)
if(CMAKE_CROSSCOMPILING)
  find_program(_GRPC_CPP_PLUGIN_EXECUTABLE grpc_cpp_plugin)
else()
  set(_GRPC_CPP_PLUGIN_EXECUTABLE $<TARGET_FILE:grpc_cpp_plugin>)
endif()

# gRPC needs WINNT defined appropriately, which isn't done for us by CMake.
# credit to alalek on https://github.com/opencv/opencv/pull/15891/files
if(CMAKE_SYSTEM_NAME STREQUAL "Windows") 
  get_directory_property(__DIRECTORY_COMPILE_DEFINITIONS COMPILE_DEFINITIONS) 
  if(NOT " ${CMAKE_CXX_FLAGS} ${CMAKE_CXX_FLAGS_RELEASE} ${__DIRECTORY_COMPILE_DEFINITIONS}" MATCHES "_WIN32_WINNT")
    # https://docs.microsoft.com/en-us/cpp/porting/modifying-winver-and-win32-winnt 
    # Target Windows 7 API 
    set(GRPC_CMAKE_MACRO_WIN32_WINNT "0x0601" CACHE STRING "Value of _WIN32_WINNT macro") 
    add_definitions(-D_WIN32_WINNT=${GRPC_CMAKE_MACRO_WIN32_WINNT}) 
  endif() 
endif()

# A utility function that:
# 1) Adds a build system rule for generating C++ headers and sources from the protobuf file <protofile_name>
# 2) Appends output filenames to the following lists:
#   - generated_pb_srcs: list of all .pb.cc files.
#   - generated_grpc_srcs: list of all .grpc.pb.cc files.
#   - generated_pb_hdrs: list of all .pb.h files.
#   - generated_grpc_hdrs: list of all .grpc.pb.h files.
#   - generated_protobuf_header_dir: a path to you should add to include all of the generated headers.
#
# Make sure to add the srcs lists to your executable or library so that your protobuf cc files get built,
# and to add generated_header_dir to your include path, so that your headers are findable.
#
function(generate_cpp_from_protofile protofile_name)
  # Slice and dice the input protofile name.
  get_filename_component(absolute_protofile_name ${protofile_name} ABSOLUTE)
  get_filename_component(base_protofile_name ${protofile_name} NAME_WE)
  get_filename_component(protofile_path "${absolute_protofile_name}" PATH)

  # Assemble generated protoc output file names.
  set(output_dir "${CMAKE_CURRENT_BINARY_DIR}")
  set(proto_src "${output_dir}/${base_protofile_name}.pb.cc")
  set(proto_hdr "${output_dir}/${base_protofile_name}.pb.h")
  set(grpc_src "${output_dir}/${base_protofile_name}.grpc.pb.cc")
  set(grpc_hdr "${output_dir}/${base_protofile_name}.grpc.pb.h")

  # Abort if a generated file name matches one we've already written a rule for-
  # they must be uniquely named or the protoc step will overwrite the one that runs first.
  if (${proto_src} IN_LIST generated_pb_srcs)
    message(FATAL_ERROR "Tried to make a rule for ${proto_src}, but one has already been generated. Protofile names must be globally unique.")
  endif()

  # Add a build rule for protoc to write out the files determined above.
  add_custom_command(
        OUTPUT "${proto_src}" "${proto_hdr}" "${grpc_src}" "${grpc_hdr}"
        COMMAND ${_PROTOBUF_PROTOC}
        ARGS --grpc_out "${output_dir}"
          --cpp_out "${output_dir}"
          -I "${protofile_path}"
          --plugin=protoc-gen-grpc="${_GRPC_CPP_PLUGIN_EXECUTABLE}"
          "${absolute_protofile_name}"
        DEPENDS "${absolute_protofile_name}")

  # Add the generated file names to the list of generated proto files, so that they can be included in builds.
  set(generated_pb_srcs ${proto_src} ${generated_pb_srcs} PARENT_SCOPE)
  set(generated_grpc_srcs ${grpc_src} ${generated_grpc_srcs} PARENT_SCOPE)
  set(generated_pb_hdrs ${proto_hdr} ${generated_pb_hdrs} PARENT_SCOPE)
  set(generated_grpc_hdrs ${proto_src} ${generated_grpc_hdrs} PARENT_SCOPE)
  set(generated_protobuf_header_dir ${output_dir} PARENT_SCOPE)

endfunction()
