#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd -P)
APP_DIR=$(cd "$SCRIPT_DIR/.." && pwd -P)
REPO_DIR=$(cd "$APP_DIR/../.." && pwd -P)
TD_SOURCE_DIR="$REPO_DIR/third_party/td"
LOCAL_OPENSSL_REPO_DIR="${LOCAL_OPENSSL_REPO_DIR:-$REPO_DIR/third_party/openssl_for_ios_and_android}"
BUILD_ROOT="${TDLIB_PHASE0_ROOT:-$APP_DIR/.cache/tdlib-phase0}"
WORK_ROOT="$BUILD_ROOT/work"
ARTIFACT_ROOT="$BUILD_ROOT"
ANDROID_OPENSSL_ROOT_FOR_TDLIB=""
IOS_OPENSSL_ROOT_FOR_TDLIB=""
OHOS_OPENSSL_ROOT_FOR_TDLIB=""
OPENSSL_VERSION="${OPENSSL_VERSION:-OpenSSL_1_1_1w}"
OPENSSL_SOURCE_VERSION="${OPENSSL_SOURCE_VERSION:-1.1.1w}"
OPENSSL_SOURCE_DIR="${OPENSSL_SOURCE_DIR:-}"
OPENSSL_ANDROID_ROOT="${OPENSSL_ANDROID_ROOT:-}"
OPENSSL_IOS_ROOT="${OPENSSL_IOS_ROOT:-}"
OHOS_OPENSSL_ROOT="${OHOS_OPENSSL_ROOT:-$REPO_DIR/third_party/ohos-openssl/prelude/arm64-v8a}"
OHOS_TDLIB_PREBUILT_ROOT="${OHOS_TDLIB_PREBUILT_ROOT:-$REPO_DIR/third_party/tdlib-prebuilt/ohos/arm64-v8a}"
ALLOW_GITHUB_OPENSSL_FETCH="${ALLOW_GITHUB_OPENSSL_FETCH:-0}"
CJMP_THIRD_PARTY_OPENSSL_DIR="${CJMP_THIRD_PARTY_OPENSSL_DIR:-${CJMP_SDK_HOME:-}/cjmp-tools/third_party/openssl}"
ANDROID_NDK_VERSION="${ANDROID_NDK_VERSION:-26.3.11579264}"
ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}"
ANDROID_NDK_ROOT="$ANDROID_SDK_ROOT/ndk/$ANDROID_NDK_VERSION"
IOS_SIMULATOR_SDK="${IOS_SIMULATOR_SDK:-$(xcrun --sdk iphonesimulator --show-sdk-path)}"
JOBS="${JOBS:-4}"

if [[ -z "${OHOS_NATIVE_HOME:-}" ]]; then
    if [[ -n "${DEVECO_OH_NATIVE_HOME:-}" ]]; then
        OHOS_NATIVE_HOME="$DEVECO_OH_NATIVE_HOME"
    elif [[ -n "${DEVECO_SDK_HOME:-}" ]]; then
        OHOS_NATIVE_HOME="$DEVECO_SDK_HOME/default/openharmony/native"
    else
        OHOS_NATIVE_HOME=""
    fi
fi

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

require_file() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        echo "error: required file not found: $file" >&2
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
    require_tool cmake
    require_tool ninja
    require_tool php
    require_tool perl
    require_tool make
    require_tool tar
    require_tool curl
    require_tool git
    require_tool java
    require_tool javadoc
    require_tool jar
    mkdir -p "$WORK_ROOT"
}

prepare_android_environment() {
    require_dir "$ANDROID_SDK_ROOT"
    require_dir "$ANDROID_NDK_ROOT"
}

prepare_ohos_environment() {
    require_dir "$OHOS_NATIVE_HOME"
    require_file "$OHOS_NATIVE_HOME/build/cmake/ohos.toolchain.cmake"
    require_file "$OHOS_NATIVE_HOME/llvm/bin/llvm-ar"
    require_file "$OHOS_NATIVE_HOME/llvm/bin/llvm-readelf"
}

normalize_android_openssl_artifacts() {
    local stable_root="$LOCAL_OPENSSL_REPO_DIR/output/android/openssl-arm64-v8a"
    local example_root="$LOCAL_OPENSSL_REPO_DIR/example/android/demo2/test_curl_with_ssl_and_http2_android/app/src/main/cpp/test"
    local example_lib_dir="$example_root/lib/arm64-v8a"
    local example_include_dir="$example_root/include"

    if is_android_openssl_root "$stable_root"; then
        return
    fi

    if [[ -f "$example_lib_dir/libcrypto.a" && -f "$example_lib_dir/libssl.a" && -d "$example_include_dir/openssl" ]]; then
        echo "Staging Android OpenSSL artifacts from $example_root to $stable_root"
        mkdir -p "$stable_root/lib" "$stable_root/include"
        cp "$example_lib_dir/libcrypto.a" "$example_lib_dir/libssl.a" "$stable_root/lib/"
        cp -R "$example_include_dir/openssl" "$stable_root/include/"
    fi
}

normalize_ios_device_openssl_artifacts() {
    local stable_root="$LOCAL_OPENSSL_REPO_DIR/output/ios/openssl-arm64"
    local example_root="$LOCAL_OPENSSL_REPO_DIR/example/ios/demo2/test_curl_with_ssl_and_http2_ios/test"
    local example_lib_dir="$example_root/lib"
    local example_include_dir="$example_root/include"

    if is_ios_device_openssl_root "$stable_root"; then
        return
    fi

    if [[ -f "$example_lib_dir/libcrypto-universal.a" && -f "$example_lib_dir/libssl-universal.a" && -d "$example_include_dir/openssl" ]]; then
        echo "Staging iOS OpenSSL artifacts from $example_root to $stable_root"
        mkdir -p "$stable_root/lib" "$stable_root/include"
        lipo "$example_lib_dir/libcrypto-universal.a" -thin arm64 -output "$stable_root/lib/libcrypto.a"
        lipo "$example_lib_dir/libssl-universal.a" -thin arm64 -output "$stable_root/lib/libssl.a"
        cp -R "$example_include_dir/openssl" "$stable_root/include/"
    fi
}

fetch_openssl_source() {
    local src_dir="$WORK_ROOT/openssl-src"
    local archive="$WORK_ROOT/openssl-${OPENSSL_SOURCE_VERSION}.tar.gz"
    local unpack_root="$WORK_ROOT/openssl-unpack"
    local unpacked_dir
    local urls=(
        "https://distfiles.macports.org/openssl11/openssl-${OPENSSL_SOURCE_VERSION}.tar.gz"
        "https://www.openssl.org/source/openssl-${OPENSSL_SOURCE_VERSION}.tar.gz"
        "https://www.openssl.org/source/old/1.1.1/openssl-${OPENSSL_SOURCE_VERSION}.tar.gz"
    )
    local url

    if [[ -f "$src_dir/Configure" ]]; then
        echo "$src_dir"
        return
    fi

    if [[ -n "$OPENSSL_SOURCE_DIR" && -f "$OPENSSL_SOURCE_DIR/Configure" ]]; then
        echo "$OPENSSL_SOURCE_DIR"
        return
    fi

    if [[ -n "${CJMP_SDK_HOME:-}" && -f "$CJMP_THIRD_PARTY_OPENSSL_DIR/Configure" ]]; then
        echo "$CJMP_THIRD_PARTY_OPENSSL_DIR"
        return
    fi

    if [[ -n "${CJMP_SDK_HOME:-}" && ! -f "$CJMP_THIRD_PARTY_OPENSSL_DIR/Configure" ]]; then
        echo "No OpenSSL source tree found under $CJMP_THIRD_PARTY_OPENSSL_DIR; downloading source for TDLib." >&2
    fi

    rm -rf "$src_dir"
    rm -rf "$unpack_root"
    mkdir -p "$unpack_root"

    if [[ "$ALLOW_GITHUB_OPENSSL_FETCH" == "1" ]]; then
        urls+=("https://github.com/openssl/openssl/archive/refs/tags/${OPENSSL_VERSION}.tar.gz")
    fi

    for url in "${urls[@]}"; do
        echo "Downloading OpenSSL source from $url" >&2
        if curl -fL --connect-timeout 15 --max-time 120 --retry 2 --retry-delay 2 -o "$archive" "$url"; then
            tar -xzf "$archive" -C "$unpack_root"
            unpacked_dir=$(find "$unpack_root" -mindepth 1 -maxdepth 1 -type d | head -n 1)
            if [[ -n "$unpacked_dir" && -f "$unpacked_dir/Configure" ]]; then
                mv "$unpacked_dir" "$src_dir"
                rm -rf "$unpack_root"
                echo "$src_dir"
                return
            fi
        fi
        rm -rf "$unpack_root"
        mkdir -p "$unpack_root"
    done

    if [[ "$ALLOW_GITHUB_OPENSSL_FETCH" == "1" ]]; then
        echo "OpenSSL source archive download failed, trying git clone fallback" >&2
        git -c http.lowSpeedLimit=1 -c http.lowSpeedTime=20 clone --depth 1 --branch "$OPENSSL_VERSION" \
            https://github.com/openssl/openssl.git "$src_dir"
        echo "$src_dir"
        return
    fi

    echo "error: failed to fetch OpenSSL source. Set OPENSSL_SOURCE_DIR to a local source tree, set OPENSSL_ANDROID_ROOT to Android libssl/libcrypto artifacts, or set ALLOW_GITHUB_OPENSSL_FETCH=1 to allow GitHub fallback." >&2
    exit 1
}

is_android_openssl_root() {
    local candidate="$1"
    local lib_dir
    [[ -n "$candidate" ]] || return 1
    lib_dir=$(android_openssl_lib_dir "$candidate") || return 1
    [[ -f "$lib_dir/libcrypto.a" ]] || return 1
    [[ -f "$lib_dir/libssl.a" ]] || return 1
    [[ -f "$candidate/include/openssl/ssl.h" || -f "$candidate/include/openssl/opensslv.h" ]]
}

is_ios_device_openssl_root() {
    local candidate="$1"
    [[ -n "$candidate" ]] || return 1
    [[ -f "$candidate/lib/libcrypto.a" ]] || return 1
    [[ -f "$candidate/lib/libssl.a" ]] || return 1
    [[ -f "$candidate/include/openssl/ssl.h" || -f "$candidate/include/openssl/opensslv.h" ]]
}

is_ohos_openssl_root() {
    local candidate="$1"
    [[ -n "$candidate" ]] || return 1
    [[ -f "$candidate/lib/libcrypto.a" ]] || return 1
    [[ -f "$candidate/lib/libssl.a" ]] || return 1
    [[ -f "$candidate/include/openssl/ssl.h" || -f "$candidate/include/openssl/opensslv.h" ]]
}

android_openssl_lib_dir() {
    local candidate="$1"
    if [[ -f "$candidate/lib/libcrypto.a" && -f "$candidate/lib/libssl.a" ]]; then
        echo "$candidate/lib"
        return
    fi
    if [[ -f "$candidate/lib/arm64-v8a/libcrypto.a" && -f "$candidate/lib/arm64-v8a/libssl.a" ]]; then
        echo "$candidate/lib/arm64-v8a"
        return
    fi
    return 1
}

android_static_library_is_arm64() {
    local library="$1"
    local host_tag="$2"
    local toolchain_bin="$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/$host_tag/bin"
    local ar_tool="$toolchain_bin/llvm-ar"
    local readelf_tool="$toolchain_bin/llvm-readelf"
    local temp_dir
    local first_object

    [[ -f "$ar_tool" && -f "$readelf_tool" ]] || return 1
    temp_dir=$(mktemp -d)
    (
        cd "$temp_dir"
        "$ar_tool" x "$library"
    ) >/dev/null 2>&1 || {
        rm -rf "$temp_dir"
        return 1
    }
    first_object=$(find "$temp_dir" -type f | head -n 1)
    if [[ -z "$first_object" ]]; then
        rm -rf "$temp_dir"
        return 1
    fi
    if "$readelf_tool" -h "$first_object" | grep -q "Machine:.*AArch64"; then
        rm -rf "$temp_dir"
        return 0
    fi
    rm -rf "$temp_dir"
    return 1
}

ios_static_library_is_iphoneos_arm64() {
    local library="$1"
    local temp_dir
    local first_object

    temp_dir=$(mktemp -d)
    (
        cd "$temp_dir"
        ar -x "$library"
    ) >/dev/null 2>&1 || {
        rm -rf "$temp_dir"
        return 1
    }
    first_object=$(find "$temp_dir" -type f | head -n 1)
    if [[ -z "$first_object" ]]; then
        rm -rf "$temp_dir"
        return 1
    fi
    if file "$first_object" | grep -q "Mach-O 64-bit object arm64" &&
        otool -l "$first_object" | grep -Eq "LC_VERSION_MIN_IPHONEOS|platform IOS"; then
        rm -rf "$temp_dir"
        return 0
    fi
    rm -rf "$temp_dir"
    return 1
}

ohos_static_library_is_arm64() {
    local library="$1"
    local ar_tool="$OHOS_NATIVE_HOME/llvm/bin/llvm-ar"
    local readelf_tool="$OHOS_NATIVE_HOME/llvm/bin/llvm-readelf"
    local temp_dir
    local member
    local object_path
    local inspected=0

    [[ -f "$ar_tool" && -f "$readelf_tool" ]] || return 1
    temp_dir=$(mktemp -d)

    while IFS= read -r member; do
        [[ -n "$member" ]] || continue
        object_path="$temp_dir/member.o"
        if "$ar_tool" p "$library" "$member" > "$object_path" 2>/dev/null &&
            "$readelf_tool" -h "$object_path" 2>/dev/null | grep -q "Machine:.*AArch64"; then
            rm -rf "$temp_dir"
            return 0
        fi
        inspected=$((inspected + 1))
        if [[ "$inspected" -ge 50 ]]; then
            break
        fi
    done < <("$ar_tool" t "$library")

    rm -rf "$temp_dir"
    return 1
}

require_android_openssl_arm64() {
    local root="$1"
    local host_tag="$2"
    local lib_dir

    lib_dir=$(android_openssl_lib_dir "$root") || {
        echo "error: OpenSSL root is missing libssl.a/libcrypto.a: $root" >&2
        exit 1
    }
    if ! android_static_library_is_arm64 "$lib_dir/libcrypto.a" "$host_tag"; then
        echo "error: $lib_dir/libcrypto.a is not an Android arm64-v8a static library" >&2
        exit 1
    fi
    if ! android_static_library_is_arm64 "$lib_dir/libssl.a" "$host_tag"; then
        echo "error: $lib_dir/libssl.a is not an Android arm64-v8a static library" >&2
        exit 1
    fi
}

require_ios_device_openssl_arm64() {
    local root="$1"

    if ! ios_static_library_is_iphoneos_arm64 "$root/lib/libcrypto.a"; then
        echo "error: $root/lib/libcrypto.a is not an iPhoneOS arm64 static library" >&2
        exit 1
    fi
    if ! ios_static_library_is_iphoneos_arm64 "$root/lib/libssl.a"; then
        echo "error: $root/lib/libssl.a is not an iPhoneOS arm64 static library" >&2
        exit 1
    fi
}

require_ohos_openssl_arm64() {
    local root="$1"

    if ! is_ohos_openssl_root "$root"; then
        echo "error: OHOS OpenSSL root is missing libssl.a/libcrypto.a or headers: $root" >&2
        exit 1
    fi
    if ! ohos_static_library_is_arm64 "$root/lib/libcrypto.a"; then
        echo "error: $root/lib/libcrypto.a is not an OHOS arm64 static library" >&2
        exit 1
    fi
    if ! ohos_static_library_is_arm64 "$root/lib/libssl.a"; then
        echo "error: $root/lib/libssl.a is not an OHOS arm64 static library" >&2
        exit 1
    fi
}

find_android_openssl_root() {
    local candidate
    local candidates=(
        "$OPENSSL_ANDROID_ROOT"
        "$LOCAL_OPENSSL_REPO_DIR/output/android/openssl-arm64-v8a"
        "$LOCAL_OPENSSL_REPO_DIR/example/android/demo2/test_curl_with_ssl_and_http2_android/app/src/main/cpp/test"
        "$ARTIFACT_ROOT/android/openssl/arm64-v8a"
        "$CJMP_THIRD_PARTY_OPENSSL_DIR/android/arm64-v8a"
        "$CJMP_THIRD_PARTY_OPENSSL_DIR/linux_android_aarch64_cjnative"
        "$CJMP_THIRD_PARTY_OPENSSL_DIR"
    )

    for candidate in "${candidates[@]}"; do
        if is_android_openssl_root "$candidate"; then
            echo "$candidate"
            return
        fi
    done
}

find_ios_device_openssl_root() {
    local candidate
    local candidates=(
        "$OPENSSL_IOS_ROOT"
        "$LOCAL_OPENSSL_REPO_DIR/output/ios/openssl-arm64"
        "$ARTIFACT_ROOT/ios/openssl"
        "$CJMP_THIRD_PARTY_OPENSSL_DIR/ios/arm64"
        "$CJMP_THIRD_PARTY_OPENSSL_DIR/ios_aarch64_cjnative"
        "$CJMP_THIRD_PARTY_OPENSSL_DIR"
    )

    for candidate in "${candidates[@]}"; do
        if is_ios_device_openssl_root "$candidate"; then
            echo "$candidate"
            return
        fi
    done
}

find_ohos_openssl_root() {
    local candidate
    local candidates=(
        "$OHOS_OPENSSL_ROOT"
        "$REPO_DIR/third_party/ohos-openssl/prelude/arm64-v8a"
        "$ARTIFACT_ROOT/ohos/openssl/arm64-v8a"
        "$CJMP_THIRD_PARTY_OPENSSL_DIR/ohos/arm64-v8a"
        "$CJMP_THIRD_PARTY_OPENSSL_DIR/ohos_aarch64_cjnative"
    )

    for candidate in "${candidates[@]}"; do
        if is_ohos_openssl_root "$candidate"; then
            echo "$candidate"
            return
        fi
    done
}

copy_android_openssl_root() {
    local source_dir="$1"
    local out_dir="$2"
    local lib_dir

    lib_dir=$(android_openssl_lib_dir "$source_dir")

    rm -rf "$out_dir"
    mkdir -p "$out_dir/lib"
    cp "$lib_dir/libcrypto.a" "$lib_dir/libssl.a" "$out_dir/lib/"
    cp -R "$source_dir/include" "$out_dir/"
}

copy_openssl_source_tree() {
    local source_dir="$1"
    local work_dir="$2"

    rm -rf "$work_dir"
    if [[ -d "$source_dir/.git" ]]; then
        git clone --quiet "$source_dir" "$work_dir"
    else
        mkdir -p "$work_dir"
        tar -C "$source_dir" -cf - . | tar -C "$work_dir" -xf -
    fi
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
    local host_tag="$1"
    local out_dir="$ARTIFACT_ROOT/android/openssl/arm64-v8a"
    local work_dir="$WORK_ROOT/openssl-android-arm64"
    local openssl_root
    local openssl_src

    if [[ -f "$out_dir/lib/libcrypto.a" && -f "$out_dir/lib/libssl.a" ]]; then
        ANDROID_OPENSSL_ROOT_FOR_TDLIB="$out_dir"
        return
    fi

    normalize_android_openssl_artifacts
    openssl_root=$(find_android_openssl_root)
    if [[ -n "$openssl_root" ]]; then
        require_android_openssl_arm64 "$openssl_root" "$host_tag"
        echo "Using Android OpenSSL artifacts from $openssl_root"
        ANDROID_OPENSSL_ROOT_FOR_TDLIB="$openssl_root"
        return
    fi

    openssl_src=$(fetch_openssl_source)
    copy_openssl_source_tree "$openssl_src" "$work_dir"

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
    ANDROID_OPENSSL_ROOT_FOR_TDLIB="$out_dir"
}

strip_android_shared_library() {
    local library_path="$1"
    local host_tag="$2"
    local strip_tool="$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/$host_tag/bin/llvm-strip"

    if [[ -f "$strip_tool" && -f "$library_path" ]]; then
        "$strip_tool" --strip-unneeded "$library_path"
    fi
}

build_android_tdjson() {
    local host_tag="$1"
    local build_dir="$WORK_ROOT/td-android-arm64"
    local openssl_dir="${ANDROID_OPENSSL_ROOT_FOR_TDLIB:-$ARTIFACT_ROOT/android/openssl/arm64-v8a}"
    local out_dir="$ARTIFACT_ROOT/android/arm64-v8a"
    local lib_path

    if [[ -f "$out_dir/libtdjson.so" ]]; then
        echo "Android libtdjson.so already exists, skipping build"
        strip_android_shared_library "$out_dir/libtdjson.so" "$host_tag"
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
    strip_android_shared_library "$out_dir/libtdjson.so" "$host_tag"
    cp "$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/$host_tag/sysroot/usr/lib/aarch64-linux-android/libc++_shared.so" "$out_dir/libc++_shared.so"
}

build_ios_simulator_openssl() {
    local openssl_src="$1"
    local out_dir="$ARTIFACT_ROOT/ios-sim/openssl"
    local work_dir="$WORK_ROOT/openssl-ios-sim"

    if [[ -f "$out_dir/lib/libcrypto.a" && -f "$out_dir/lib/libssl.a" ]]; then
        return
    fi

    copy_openssl_source_tree "$openssl_src" "$work_dir"

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
    mkdir -p "$out_dir"
    cp "$lib_path" "$out_dir/libtdjson.dylib"
    install_name_tool -id @rpath/libtdjson.dylib "$out_dir/libtdjson.dylib"
}

build_ios_device_openssl() {
    local out_dir="$ARTIFACT_ROOT/ios/openssl"
    local work_dir="$WORK_ROOT/openssl-ios-device"
    local ios_sdk_path="${IOS_SDK_PATH:-$(xcrun --sdk iphoneos --show-sdk-path)}"
    local openssl_root
    local openssl_src

    if [[ -f "$out_dir/lib/libcrypto.a" && -f "$out_dir/lib/libssl.a" ]]; then
        IOS_OPENSSL_ROOT_FOR_TDLIB="$out_dir"
        return
    fi

    normalize_ios_device_openssl_artifacts
    openssl_root=$(find_ios_device_openssl_root)
    if [[ -n "$openssl_root" ]]; then
        require_ios_device_openssl_arm64 "$openssl_root"
        echo "Using iOS OpenSSL artifacts from $openssl_root"
        IOS_OPENSSL_ROOT_FOR_TDLIB="$openssl_root"
        return
    fi

    openssl_src=$(fetch_openssl_source)
    copy_openssl_source_tree "$openssl_src" "$work_dir"

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
    local openssl_dir="${IOS_OPENSSL_ROOT_FOR_TDLIB:-$ARTIFACT_ROOT/ios/openssl}"
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

build_ohos_openssl() {
    local out_dir="$ARTIFACT_ROOT/ohos/openssl/arm64-v8a"
    local openssl_root

    if is_ohos_openssl_root "$out_dir"; then
        OHOS_OPENSSL_ROOT_FOR_TDLIB="$out_dir"
        return
    fi

    openssl_root=$(find_ohos_openssl_root)
    if [[ -z "$openssl_root" ]]; then
        echo "error: failed to locate OHOS OpenSSL artifacts. Set OHOS_OPENSSL_ROOT to a root containing lib/libssl.a, lib/libcrypto.a, and include/openssl." >&2
        exit 1
    fi

    require_ohos_openssl_arm64 "$openssl_root"
    echo "Using OHOS OpenSSL artifacts from $openssl_root"
    OHOS_OPENSSL_ROOT_FOR_TDLIB="$openssl_root"
}

strip_ohos_shared_library() {
    local library_path="$1"
    local strip_tool="$OHOS_NATIVE_HOME/llvm/bin/llvm-strip"

    if [[ -f "$strip_tool" && -f "$library_path" ]]; then
        "$strip_tool" --strip-unneeded "$library_path"
    fi
}

ohos_tdjson_has_packaged_soname() {
    local library_path="$1"
    local readelf_tool="$OHOS_NATIVE_HOME/llvm/bin/llvm-readelf"
    local dynamic_section

    [[ -f "$library_path" && -f "$readelf_tool" ]] || return 1
    dynamic_section=$("$readelf_tool" -d "$library_path")
    [[ "$dynamic_section" == *"Library soname: [libtdjson.so]"* ]]
}

ohos_shared_library_is_arm64() {
    local library_path="$1"
    local readelf_tool="$OHOS_NATIVE_HOME/llvm/bin/llvm-readelf"
    local elf_header

    [[ -f "$library_path" && -f "$readelf_tool" ]] || return 1
    elf_header=$("$readelf_tool" -h "$library_path")
    [[ "$elf_header" == *"Machine:"*"AArch64"* ]]
}

stage_ohos_prebuilt_tdjson() {
    local prebuilt_path="$OHOS_TDLIB_PREBUILT_ROOT/libtdjson.so"
    local out_dir="$ARTIFACT_ROOT/ohos/arm64-v8a"

    [[ -f "$prebuilt_path" ]] || return 1
    if ! ohos_shared_library_is_arm64 "$prebuilt_path"; then
        echo "error: OHOS TDLib prebuilt is not an AArch64 shared library: $prebuilt_path" >&2
        exit 1
    fi
    if ! ohos_tdjson_has_packaged_soname "$prebuilt_path"; then
        echo "error: OHOS TDLib prebuilt must use SONAME libtdjson.so for HAP packaging: $prebuilt_path" >&2
        exit 1
    fi

    echo "Using OHOS TDLib prebuilt from $prebuilt_path"
    rm -rf "$out_dir"
    mkdir -p "$out_dir"
    cp "$prebuilt_path" "$out_dir/libtdjson.so"
    strip_ohos_shared_library "$out_dir/libtdjson.so"
    return 0
}

persist_ohos_tdjson_prebuilt() {
    local tdjson_path="$ARTIFACT_ROOT/ohos/arm64-v8a/libtdjson.so"

    require_file "$tdjson_path"
    if ! ohos_shared_library_is_arm64 "$tdjson_path"; then
        echo "error: generated OHOS libtdjson.so is not AArch64: $tdjson_path" >&2
        exit 1
    fi
    if ! ohos_tdjson_has_packaged_soname "$tdjson_path"; then
        echo "error: generated OHOS libtdjson.so does not use SONAME libtdjson.so" >&2
        exit 1
    fi
    mkdir -p "$OHOS_TDLIB_PREBUILT_ROOT"
    cp "$tdjson_path" "$OHOS_TDLIB_PREBUILT_ROOT/libtdjson.so"
}

stage_ohos_hap_libraries() {
    local tdjson_path="$ARTIFACT_ROOT/ohos/arm64-v8a/libtdjson.so"
    local hap_lib_dir="$APP_DIR/hos/entry/src/main/libs/arm64-v8a"
    local libcxx_path="$OHOS_NATIVE_HOME/llvm/lib/aarch64-linux-ohos/c++/libc++_shared.so"

    require_file "$tdjson_path"
    mkdir -p "$hap_lib_dir"
    cp "$tdjson_path" "$hap_lib_dir/libtdjson.so"
    if [[ -f "$libcxx_path" ]]; then
        cp "$libcxx_path" "$hap_lib_dir/libc++_shared.so"
    fi
}

build_ohos_tdjson() {
    local build_dir="$WORK_ROOT/td-ohos-arm64"
    local openssl_dir="${OHOS_OPENSSL_ROOT_FOR_TDLIB:-$ARTIFACT_ROOT/ohos/openssl/arm64-v8a}"
    local out_dir="$ARTIFACT_ROOT/ohos/arm64-v8a"
    local lib_path
    local ninja_path

    if [[ -f "$out_dir/libtdjson.so" ]]; then
        echo "OHOS libtdjson.so already exists, skipping build"
        strip_ohos_shared_library "$out_dir/libtdjson.so"
        return
    fi

    if [[ -x "$OHOS_NATIVE_HOME/build-tools/cmake/bin/ninja" ]]; then
        ninja_path="$OHOS_NATIVE_HOME/build-tools/cmake/bin/ninja"
    else
        ninja_path="$(command -v ninja)"
    fi

    rm -rf "$build_dir"
    cmake \
        -S "$TD_SOURCE_DIR" \
        -B "$build_dir" \
        -GNinja \
        -DCMAKE_MAKE_PROGRAM="$ninja_path" \
        -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
        -DCMAKE_TOOLCHAIN_FILE="$OHOS_NATIVE_HOME/build/cmake/ohos.toolchain.cmake" \
        -DOHOS_ARCH=arm64-v8a \
        -DOHOS_STL=c++_shared \
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
        echo "error: failed to locate OHOS libtdjson.so" >&2
        exit 1
    fi

    rm -rf "$out_dir"
    mkdir -p "$out_dir"
    cp "$lib_path" "$out_dir/libtdjson.so"
    strip_ohos_shared_library "$out_dir/libtdjson.so"
}

build_android_target() {
    local host_tag="$1"
    local out_dir="$ARTIFACT_ROOT/android/arm64-v8a"

    if [[ -f "$out_dir/libtdjson.so" ]]; then
        echo "Android libtdjson.so already exists, skipping TDLib build"
        strip_android_shared_library "$out_dir/libtdjson.so" "$host_tag"
        return
    fi

    build_android_openssl "$host_tag"
    prepare_td_generated_sources
    build_android_tdjson "$host_tag"
}

build_ios_simulator_target() {
    local out_dir="$ARTIFACT_ROOT/ios-sim"
    local openssl_src

    if [[ -f "$out_dir/libtdjson.dylib" ]]; then
        echo "iOS simulator libtdjson.dylib already exists, skipping TDLib build"
        return
    fi

    openssl_src=$(fetch_openssl_source)
    build_ios_simulator_openssl "$openssl_src"
    prepare_td_generated_sources
    build_ios_simulator_tdjson
}

build_ios_device_target() {
    local out_dir="$ARTIFACT_ROOT/ios"

    if [[ -f "$out_dir/libtdjson.dylib" ]]; then
        echo "iOS device libtdjson.dylib already exists, skipping TDLib build"
        return
    fi

    build_ios_device_openssl
    prepare_td_generated_sources
    build_ios_device_tdjson
}

build_ohos_target() {
    local out_dir="$ARTIFACT_ROOT/ohos/arm64-v8a"

    prepare_ohos_environment
    if [[ -f "$out_dir/libtdjson.so" ]]; then
        if ! ohos_tdjson_has_packaged_soname "$out_dir/libtdjson.so"; then
            echo "OHOS libtdjson.so has a versioned SONAME, rebuilding for HAP packaging"
            rm -rf "$out_dir" "$WORK_ROOT/td-ohos-arm64"
        else
            echo "OHOS libtdjson.so already exists, skipping TDLib build"
            strip_ohos_shared_library "$out_dir/libtdjson.so"
            stage_ohos_hap_libraries
            return
        fi
    fi

    if stage_ohos_prebuilt_tdjson; then
        stage_ohos_hap_libraries
        return
    fi

    build_ohos_openssl
    prepare_td_generated_sources
    build_ohos_tdjson
    persist_ohos_tdjson_prebuilt
    stage_ohos_hap_libraries
}

main() {
    local host_tag=""

    prepare_common_environment

    for target in "${TARGETS[@]}"; do
        case "$target" in
            android)
                prepare_android_environment
                host_tag=$(find_android_host_tag)
                if [[ "$host_tag" == "error" ]]; then
                    echo "error: failed to locate an Android NDK host prebuilt directory" >&2
                    exit 1
                fi
                build_android_target "$host_tag"
                ;;
            ios-sim)
                build_ios_simulator_target
                ;;
            ios)
                build_ios_device_target
                ;;
            ohos)
                build_ohos_target
                ;;
            all)
                prepare_android_environment
                host_tag=$(find_android_host_tag)
                if [[ "$host_tag" == "error" ]]; then
                    echo "error: failed to locate an Android NDK host prebuilt directory" >&2
                    exit 1
                fi
                build_android_target "$host_tag"
                build_ios_simulator_target
                build_ios_device_target
                build_ohos_target
                ;;
            *)
                echo "error: unsupported target '$target' (expected: android, ios, ios-sim, ohos, all)" >&2
                exit 1
                ;;
        esac
    done

    echo "TDLib phase 0 artifacts:"
    find "$ARTIFACT_ROOT" -maxdepth 3 \( -name 'libtdjson.so' -o -name 'libtdjson.dylib' \) | sort
}

main
