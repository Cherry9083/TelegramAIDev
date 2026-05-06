#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd -P)
APP_DIR=$(cd "$SCRIPT_DIR/.." && pwd -P)
REPO_DIR=$(cd "$APP_DIR/../.." && pwd -P)
TD_SOURCE_DIR="$REPO_DIR/third_party/td"
BUILD_ROOT="$APP_DIR/build/tdlib-phase0"
WORK_ROOT="$BUILD_ROOT/work"
ARTIFACT_ROOT="$BUILD_ROOT"
OPENSSL_VERSION="${OPENSSL_VERSION:-OpenSSL_1_1_1w}"
ANDROID_NDK_VERSION="${ANDROID_NDK_VERSION:-26.3.11579264}"
ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}"
ANDROID_NDK_ROOT="$ANDROID_SDK_ROOT/ndk/$ANDROID_NDK_VERSION"
IOS_SIMULATOR_SDK="${IOS_SIMULATOR_SDK:-$(xcrun --sdk iphonesimulator --show-sdk-path)}"
JOBS="${JOBS:-4}"

export PATH="/opt/homebrew/opt/cmake/bin:/opt/homebrew/opt/ninja/bin:/opt/homebrew/opt/php/bin:$PATH"

if [[ $# -eq 0 ]]; then
    TARGETS=("android" "ios-sim")
else
    TARGETS=("$@")
fi

require_dir() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        echo "error: required directory not found: $dir" >&2
        exit 1
    fi
}

require_tool() {
    local tool="$1"
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "error: required tool not found on PATH: $tool" >&2
        exit 1
    fi
}

find_android_host_tag() {
    local candidate
    for candidate in darwin-x86_64 darwin-arm64; do
        if [[ -d "$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/$candidate" ]]; then
            echo "$candidate"
            return
        fi
    done
    echo "error"
}

prepare_common_environment() {
    require_dir "$TD_SOURCE_DIR"
    require_dir "$ANDROID_SDK_ROOT"
    require_dir "$ANDROID_NDK_ROOT"
    require_tool cmake
    require_tool ninja
    require_tool php
    require_tool perl
    require_tool make
    require_tool git
    require_tool java
    require_tool javadoc
    require_tool jar
    mkdir -p "$WORK_ROOT"
}

fetch_openssl_source() {
    local src_dir="$WORK_ROOT/openssl-src"
    if [[ -d "$src_dir/.git" ]]; then
        echo "$src_dir"
        return
    fi
    rm -rf "$src_dir"
    git clone --depth 1 --branch "$OPENSSL_VERSION" https://github.com/openssl/openssl.git "$src_dir"
    echo "$src_dir"
}

prepare_td_generated_sources() {
    local build_dir="$WORK_ROOT/td-generate"
    cmake \
        -S "$TD_SOURCE_DIR" \
        -B "$build_dir" \
        -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
        -DTD_GENERATE_SOURCE_FILES=ON
    cmake --build "$build_dir" --parallel "$JOBS"
}

build_android_openssl() {
    local openssl_src="$1"
    local out_dir="$ARTIFACT_ROOT/android/openssl/arm64-v8a"
    local work_dir="$WORK_ROOT/openssl-android-arm64"
    local host_tag="$2"

    if [[ -f "$out_dir/lib/libcrypto.a" && -f "$out_dir/lib/libssl.a" ]]; then
        return
    fi

    rm -rf "$work_dir"
    git clone --quiet "$openssl_src" "$work_dir"

    export ANDROID_NDK_ROOT
    export ANDROID_NDK_HOME="$ANDROID_NDK_ROOT"
    PATH="$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/$host_tag/bin:$PATH"

    pushd "$work_dir" >/dev/null
    ./Configure android-arm64 no-shared -U__ANDROID_API__ -D__ANDROID_API__=21
    make depend -s
    make -j"$JOBS" -s
    popd >/dev/null

    rm -rf "$out_dir"
    mkdir -p "$out_dir/lib"
    cp "$work_dir/libcrypto.a" "$work_dir/libssl.a" "$out_dir/lib/"
    cp -R "$work_dir/include" "$out_dir/"
}

build_android_tdjson() {
    local host_tag="$1"
    local build_dir="$WORK_ROOT/td-android-arm64"
    local openssl_dir="$ARTIFACT_ROOT/android/openssl/arm64-v8a"
    local out_dir="$ARTIFACT_ROOT/android/arm64-v8a"
    local lib_path

    if [[ -f "$out_dir/libtdjson.so" ]]; then
        echo "Android libtdjson.so already exists, skipping build"
        return
    fi

    rm -rf "$build_dir"
    cmake \
        -S "$TD_SOURCE_DIR" \
        -B "$build_dir" \
        -GNinja \
        -DCMAKE_MAKE_PROGRAM="$(command -v ninja)" \
        -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
        -DCMAKE_TOOLCHAIN_FILE="$ANDROID_NDK_ROOT/build/cmake/android.toolchain.cmake" \
        -DANDROID_ABI=arm64-v8a \
        -DANDROID_PLATFORM=android-26 \
        -DANDROID_STL=c++_shared \
        -DCMAKE_BUILD_TYPE=RelWithDebInfo \
        -DOPENSSL_FOUND=1 \
        -DOPENSSL_USE_STATIC_LIBS=TRUE \
        -DOPENSSL_ROOT_DIR="$openssl_dir" \
        -DOPENSSL_CRYPTO_LIBRARY="$openssl_dir/lib/libcrypto.a" \
        -DOPENSSL_SSL_LIBRARY="$openssl_dir/lib/libssl.a" \
        -DOPENSSL_INCLUDE_DIR="$openssl_dir/include" \
        -DOPENSSL_LIBRARIES="$openssl_dir/lib/libcrypto.a;$openssl_dir/lib/libssl.a"
    cmake --build "$build_dir" --target tdjson --parallel "$JOBS"

    lib_path=$(find "$build_dir" -name libtdjson.so | head -n 1)
    if [[ -z "$lib_path" ]]; then
        echo "error: failed to locate Android libtdjson.so" >&2
        exit 1
    fi

    rm -rf "$out_dir"
    mkdir -p "$out_dir"
    cp "$lib_path" "$out_dir/libtdjson.so"
    cp "$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/$host_tag/sysroot/usr/lib/aarch64-linux-android/libc++_shared.so" "$out_dir/libc++_shared.so"
}

build_ios_simulator_openssl() {
    local openssl_src="$1"
    local out_dir="$ARTIFACT_ROOT/ios-sim/openssl"
    local work_dir="$WORK_ROOT/openssl-ios-sim"

    if [[ -f "$out_dir/lib/libcrypto.a" && -f "$out_dir/lib/libssl.a" ]]; then
        return
    fi

    rm -rf "$work_dir"
    git clone --quiet "$openssl_src" "$work_dir"

    pushd "$work_dir" >/dev/null
    export CFLAGS="-arch arm64 -isysroot $IOS_SIMULATOR_SDK"
    export CXXFLAGS="$CFLAGS"
    export LDFLAGS="$CFLAGS"
    ./Configure iossimulator-xcrun no-shared
    make -j"$JOBS" -s
    popd >/dev/null

    rm -rf "$out_dir"
    mkdir -p "$out_dir/lib"
    cp "$work_dir/libcrypto.a" "$work_dir/libssl.a" "$out_dir/lib/"
    cp -R "$work_dir/include" "$out_dir/"
}

build_ios_simulator_tdjson() {
    local build_dir="$WORK_ROOT/td-ios-sim"
    local openssl_dir="$ARTIFACT_ROOT/ios-sim/openssl"
    local out_dir="$ARTIFACT_ROOT/ios-sim"
    local lib_path

    if [[ -f "$out_dir/libtdjson.dylib" ]]; then
        echo "iOS simulator libtdjson.dylib already exists, skipping build"
        return
    fi

    rm -rf "$build_dir"
    cmake \
        -S "$TD_SOURCE_DIR" \
        -B "$build_dir" \
        -G "Unix Makefiles" \
        -DCMAKE_MAKE_PROGRAM=/usr/bin/make \
        -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
        -DCMAKE_TOOLCHAIN_FILE="$TD_SOURCE_DIR/CMake/iOS.cmake" \
        -DIOS_PLATFORM=SIMULATOR \
        -DIOS_ARCH=arm64 \
        -DCMAKE_BUILD_TYPE=Release \
        -DOPENSSL_FOUND=1 \
        -DOPENSSL_CRYPTO_LIBRARY="$openssl_dir/lib/libcrypto.a" \
        -DOPENSSL_SSL_LIBRARY="$openssl_dir/lib/libssl.a" \
        -DOPENSSL_INCLUDE_DIR="$openssl_dir/include" \
        -DOPENSSL_LIBRARIES="$openssl_dir/lib/libcrypto.a;$openssl_dir/lib/libssl.a"
    cmake --build "$build_dir" --target tdjson --parallel "$JOBS"

    lib_path=$(find "$build_dir" -name libtdjson.dylib | head -n 1)
    if [[ -z "$lib_path" ]]; then
        echo "error: failed to locate iOS simulator libtdjson.dylib" >&2
        exit 1
    fi

    rm -rf "$out_dir/libtdjson.dylib"
    cp "$lib_path" "$out_dir/libtdjson.dylib"
    install_name_tool -id @rpath/libtdjson.dylib "$out_dir/libtdjson.dylib"
}

build_ios_device_openssl() {
    local openssl_src="$1"
    local out_dir="$ARTIFACT_ROOT/ios/openssl"
    local work_dir="$WORK_ROOT/openssl-ios-device"
    local ios_sdk_path="${IOS_SDK_PATH:-$(xcrun --sdk iphoneos --show-sdk-path)}"

    if [[ -f "$out_dir/lib/libcrypto.a" && -f "$out_dir/lib/libssl.a" ]]; then
        return
    fi

    rm -rf "$work_dir"
    git clone --quiet "$openssl_src" "$work_dir"

    pushd "$work_dir" >/dev/null
    export CFLAGS="-arch arm64 -isysroot $ios_sdk_path"
    export CXXFLAGS="$CFLAGS"
    export LDFLAGS="$CFLAGS"
    ./Configure ios64-xcrun no-shared
    make -j"$JOBS" -s
    popd >/dev/null

    rm -rf "$out_dir"
    mkdir -p "$out_dir/lib"
    cp "$work_dir/libcrypto.a" "$work_dir/libssl.a" "$out_dir/lib/"
    cp -R "$work_dir/include" "$out_dir/"
}

build_ios_device_tdjson() {
    local build_dir="$WORK_ROOT/td-ios-device"
    local openssl_dir="$ARTIFACT_ROOT/ios/openssl"
    local out_dir="$ARTIFACT_ROOT/ios"
    local lib_path

    if [[ -f "$out_dir/libtdjson.dylib" ]]; then
        echo "iOS device libtdjson.dylib already exists, skipping build"
        return
    fi

    rm -rf "$build_dir"
    cmake \
        -S "$TD_SOURCE_DIR" \
        -B "$build_dir" \
        -G "Unix Makefiles" \
        -DCMAKE_MAKE_PROGRAM=/usr/bin/make \
        -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
        -DCMAKE_TOOLCHAIN_FILE="$TD_SOURCE_DIR/CMake/iOS.cmake" \
        -DIOS_PLATFORM=OS \
        -DIOS_ARCH=arm64 \
        -DCMAKE_BUILD_TYPE=Release \
        -DOPENSSL_FOUND=1 \
        -DOPENSSL_CRYPTO_LIBRARY="$openssl_dir/lib/libcrypto.a" \
        -DOPENSSL_SSL_LIBRARY="$openssl_dir/lib/libssl.a" \
        -DOPENSSL_INCLUDE_DIR="$openssl_dir/include" \
        -DOPENSSL_LIBRARIES="$openssl_dir/lib/libcrypto.a;$openssl_dir/lib/libssl.a"
    cmake --build "$build_dir" --target tdjson --parallel "$JOBS"

    lib_path=$(find "$build_dir" -name libtdjson.dylib | head -n 1)
    if [[ -z "$lib_path" ]]; then
        echo "error: failed to locate iOS device libtdjson.dylib" >&2
        exit 1
    fi

    rm -rf "$out_dir/libtdjson.dylib"
    cp "$lib_path" "$out_dir/libtdjson.dylib"
    install_name_tool -id @rpath/libtdjson.dylib "$out_dir/libtdjson.dylib"
}

build_android_target() {
    local openssl_src="$1"
    local host_tag="$2"
    build_android_openssl "$openssl_src" "$host_tag"
    prepare_td_generated_sources
    build_android_tdjson "$host_tag"
}

build_ios_simulator_target() {
    local openssl_src="$1"
    build_ios_simulator_openssl "$openssl_src"
    prepare_td_generated_sources
    build_ios_simulator_tdjson
}

build_ios_device_target() {
    local openssl_src="$1"
    build_ios_device_openssl "$openssl_src"
    prepare_td_generated_sources
    build_ios_device_tdjson
}

main() {
    local openssl_src
    local host_tag

    prepare_common_environment
    openssl_src=$(fetch_openssl_source)
    host_tag=$(find_android_host_tag)
    if [[ "$host_tag" == "error" ]]; then
        echo "error: failed to locate an Android NDK host prebuilt directory" >&2
        exit 1
    fi

    for target in "${TARGETS[@]}"; do
        case "$target" in
            android)
                build_android_target "$openssl_src" "$host_tag"
                ;;
            ios-sim)
                build_ios_simulator_target "$openssl_src"
                ;;
            ios)
                build_ios_device_target "$openssl_src"
                ;;
            all)
                build_android_target "$openssl_src" "$host_tag"
                build_ios_simulator_target "$openssl_src"
                build_ios_device_target "$openssl_src"
                ;;
            *)
                echo "error: unsupported target '$target' (expected: android, ios, ios-sim, all)" >&2
                exit 1
                ;;
        esac
    done

    echo "TDLib phase 0 artifacts:"
    find "$ARTIFACT_ROOT" -maxdepth 3 \( -name 'libtdjson.so' -o -name 'libtdjson.dylib' \) | sort
}

main
