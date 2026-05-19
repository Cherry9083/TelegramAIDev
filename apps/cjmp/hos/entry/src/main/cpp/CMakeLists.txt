cmake_minimum_required(VERSION 3.5.0)
project(cjmp_ohos_bridge)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(NATIVE_ROOT_PATH ${CMAKE_CURRENT_SOURCE_DIR})
set(TDLIB_PHASE0_ROOT "$ENV{TDLIB_PHASE0_ROOT}")
if("${TDLIB_PHASE0_ROOT}" STREQUAL "")
    get_filename_component(TDLIB_PHASE0_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../../../../.cache/tdlib-phase0" ABSOLUTE)
endif()

set(TDJSON_LIBRARY "${TDLIB_PHASE0_ROOT}/ohos/arm64-v8a/libtdjson.so")
if(NOT EXISTS "${TDJSON_LIBRARY}")
    message(FATAL_ERROR "OHOS TDLib artifact is missing: ${TDJSON_LIBRARY}. Run apps/cjmp/scripts/build_tdlib_phase0.sh ohos first.")
endif()

add_library(tdjson SHARED IMPORTED)
set_target_properties(tdjson PROPERTIES
    IMPORTED_LOCATION "${TDJSON_LIBRARY}"
    IMPORTED_NO_SONAME TRUE
)

add_library(ohoscjmp SHARED cjmp_ohos_bridge.cpp)
target_include_directories(ohoscjmp PRIVATE ${NATIVE_ROOT_PATH})
target_link_libraries(ohoscjmp PUBLIC tdjson libhilog_ndk.z.so libnet_connection.so)

add_custom_command(TARGET ohoscjmp POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        "${TDJSON_LIBRARY}"
        "$<TARGET_FILE_DIR:ohoscjmp>/libtdjson.so"
)

set(OHOS_LIBCXX_SHARED "${OHOS_NDK_HOME}/llvm/lib/aarch64-linux-ohos/c++/libc++_shared.so")
if(EXISTS "${OHOS_LIBCXX_SHARED}")
    add_custom_command(TARGET ohoscjmp POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
            "${OHOS_LIBCXX_SHARED}"
            "$<TARGET_FILE_DIR:ohoscjmp>/libc++_shared.so"
    )
endif()
