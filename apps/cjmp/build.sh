#!/bin/bash
#!/usr/bin/env bash
set -e

# Build configuration
export buildType="${1}"
export buildTarget="${2}"
export buildProfile="${3}"
export cangjieFolder="cangjie-${buildTarget}"

# Script directory
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd -P)

# TDLib phase0 build artifact root (libtdjson.so/.dylib per target)
export TDLIB_PHASE0_ROOT="${TDLIB_PHASE0_ROOT:-$SCRIPT_DIR/.cache/tdlib-phase0}"

# Base paths
CJMP_UI_PATH="$CJMP_SDK_HOME/cjmp-ui"
CJMP_ENGINE_PATH="$CJMP_SDK_HOME/ui-engine"
CJMP_TOOL_PATH="$CJMP_SDK_HOME/cjmp-tools"
CJMP_TEST_PATH="$CJMP_SDK_HOME/cjmp-test"
CJMP_LIBS_PATH="$CJMP_SDK_HOME/cjmp-libs"
CJMP_TOOLS_LIBS_PATH="$CJMP_TOOL_PATH/libs"
CANGJIE_STDX_PATH="$CJMP_TOOL_PATH/third_party/cangjie-stdx"

# Platform-specific configuration
if [[ "${buildTarget}" == "android" ]]; then
    cangjiePath="${CJMP_TOOL_PATH}/third_party/cangjie-android"
    cangjiePlatform="linux_android_aarch64_cjnative"
    cangjieTarget="aarch64-linux-android26"
    export ANDROID_CJ_FRONTEND="$CJMP_UI_PATH/android"
    export ANDROID_NDK_DIR="$ANDROID_SDK_ROOT/ndk/27.2.12479018"
    export ANDROID_ENGINE_PATH="$CJMP_ENGINE_PATH/android"
    export ANDROID_CANGJIE_PATH="$cangjiePath"
    export ANDROID_CANGJIE_RUNTIME_PATH="${cangjiePath}/runtime/lib/${cangjiePlatform}"
    export ANDROID_CANGJIE_STDX_PATH="$CANGJIE_STDX_PATH/linux_android_aarch64_cjnative/dynamic/stdx"
    export ANDROID_TEST_PATH="$CJMP_TEST_PATH/android/ohos"
    export ANDROID_CJMP_LIBS_PATH="$CJMP_LIBS_PATH/android/dynamic"
    export ANDROID_BRIDGE="${4:-$SCRIPT_DIR/android/app/build/intermediates/cmake/${buildType}/obj/arm64-v8a}"
    os_name=$(uname -s)
    if [ "$os_name" = "Darwin" ]; then
        export SYSTEM_STRING="darwin-x86_64"
    else
        export SYSTEM_STRING="windows-x86_64"
    fi
    lib_share_path="$ANDROID_NDK_DIR/toolchains/llvm/prebuilt/${SYSTEM_STRING}/sysroot/usr/lib/aarch64-linux-android/libc++_shared.so"

elif [[ "${buildTarget}" == "ios" ]]; then
    cangjiePath="${CJMP_TOOL_PATH}/third_party/cangjie-ios"
    cangjiePlatform="ios_aarch64_cjnative"
    cangjieTarget="aarch64-apple-ios"
    platform_name="iphoneos"
    export cangjieFolder="cangjie-ios"
    export IOS_SDK_DIR="/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk"
    export IOS_CJ_FRONTEND="$CJMP_UI_PATH/ios"
    export IOS_CANGJIE_PATH="${cangjiePath}/runtime/lib/${cangjiePlatform}"
    export IOS_ENGINE_PATH="$CJMP_ENGINE_PATH/ios/libkeels_ios.framework"
    export IOS_CANGJIE_STDX_PATH="$CANGJIE_STDX_PATH/ios_aarch64_cjnative/dynamic/stdx"
    export IOS_CJMP_LIBS_PATH="$CJMP_LIBS_PATH/ios/dynamic"
    export IOS_TEST_PATH="$CJMP_TEST_PATH/ios/ohos"
    export IOS_BRIDGE="$SCRIPT_DIR/ios/oc_bridge"
    SDK_PATH="$IOS_SDK_DIR"

elif [[ "${buildTarget}" == "ios-sim" ]]; then
    cangjiePath="${CJMP_TOOL_PATH}/third_party/cangjie-ios"
    cangjiePlatform="ios_simulator_aarch64_cjnative"
    cangjieTarget="aarch64-apple-ios-simulator"
    platform_name="iphonesimulator"
    export cangjieFolder="cangjie-ios"
    export IOS_SIM_SDK_DIR="/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk"
    export IOS_SIM_CJ_FRONTEND="$CJMP_UI_PATH/ios-sim"
    export IOS_SIM_CANGJIE_PATH="${cangjiePath}/runtime/lib/${cangjiePlatform}"
    export IOS_SIM_ENGINE_PATH="$CJMP_ENGINE_PATH/ios-sim/libkeels_ios.framework"
    export IOS_SIM_CANGJIE_STDX_PATH="$CANGJIE_STDX_PATH/ios_simulator_aarch64_cjnative/dynamic/stdx"
    export IOS_SIM_CJMP_LIBS_PATH="$CJMP_LIBS_PATH/ios-sim-arm64/dynamic"
    export IOS_SIM_TEST_PATH="$CJMP_TEST_PATH/ios-sim/ohos"
    export IOS_BRIDGE="$SCRIPT_DIR/ios/oc_bridge"
    SDK_PATH="$IOS_SIM_SDK_DIR"

fi


# Build TDLib phase0 (libtdjson.so/.dylib) for the requested target before packaging.
# Android/iOS/iOS-sim produce native artifacts that the Cangjie FFI bridges dlopen at runtime.
# Non-fatal: if TDLib build fails, the app still builds/launches; TDLib features degrade gracefully at runtime.
if [[ "${buildTarget}" == "android" || "${buildTarget}" == "ios" || "${buildTarget}" == "ios-sim" ]]; then
    tdlib_build_script="$SCRIPT_DIR/scripts/build_tdlib_phase0.sh"
    if [[ -f "$tdlib_build_script" ]]; then
        echo "Building TDLib for ${buildTarget}..."
        if ! bash "$tdlib_build_script" "${buildTarget}"; then
            echo "warning: TDLib build failed for ${buildTarget}; TDLib runtime features will be unavailable." >&2
        fi
    else
        echo "warning: TDLib build script not found at $tdlib_build_script; TDLib runtime features will be unavailable." >&2
    fi
fi


# CJMP required interoplib to be placed properly: by package and along with cjo
# Usage: copy_interop_libraries <dst_path>
copy_interop_libraries() {
    local dst_path="$1"
    cjMods="$cangjiePath/modules/$cangjiePlatform"
    cjLibs="$cangjiePath/runtime/lib/$cangjiePlatform"
    if [[ "${buildTarget}" == "android" ]]; then
        mkdir -p "$dst_path/java"
        cp "$cjLibs/libjava.internal.so" "$cjMods/java.internal.cjo" "$dst_path/java/"
        cp "$cjLibs/libjava.lang.so"     "$cjMods/java.lang.cjo"     "$dst_path/java/"

    elif [[ "${buildTarget}" == "ios" || "${buildTarget}" == "ios-sim" ]]; then
        mkdir -p "${dst_path}/objc"
        cp "${cjLibs}/libobjc.internal.dylib" "${cjMods}/objc.internal.cjo" "${dst_path}/objc/"
        cp "${cjLibs}/libobjc.lang.dylib"     "${cjMods}/objc.lang.cjo"     "${dst_path}/objc/"

    fi
}

# Generated objc mirrors
# Usage: gen_objc_mirrors <dir_with_mirrors> <mirror_gen_config> <mirror_gen_backup_config>
gen_objc_mirrors() {
    local dir_with_mirrors="$1"
    local mirror_gen_config="$2"
    local mirror_gen_backup_config="$3"
    echo Generating mirrors with ObjCInteropGen
    cd $IOS_BRIDGE

    if [[ -d "$dir_with_mirrors" ]]; then
        rm -rf "$dir_with_mirrors"
    fi

    cp -p "$mirror_gen_config" "$mirror_gen_backup_config"
    python3 "${CJMP_TOOL_PATH}/tools/keels_tools/utils/update_objc_mirrors_toml.py" "$platform_name" "$mirror_gen_config"
    ObjCInteropGen "$mirror_gen_config"

    cd - > /dev/null
    echo "ObjCInteropGen mirror generation success"
}

# Build type configuration
if [[ "${buildType}" == "debug" ]]; then
    cangjieExtraArgs="-g --debug"
else
    cangjieExtraArgs="--release"
fi

# Build cangjie libraries
build_path="$SCRIPT_DIR/build"
src_path="${KEELS_CJ_SRC_PATH:-$SCRIPT_DIR/lib}"
packageOutputRoot="${build_path}/${cangjieTarget}/${buildType}"

cd "$src_path"
cjpm_path="$src_path/cjpm.toml"
cjpm_backup_path=""
dependency_cjpm_path="$SCRIPT_DIR/lib/cjpm.toml"
dependency_cjpm_backup_path=""
mirror_gen_config="${IOS_BRIDGE}/objc_mirrors.toml"
mirror_gen_backup_config=""
mirror_gen_config_lastused="${IOS_BRIDGE}/objc_mirrors.last_used.toml"

restore_tomls() {
    if [[ -n "$cjpm_backup_path" && -f "$cjpm_backup_path" ]]; then
        mv "$cjpm_backup_path" "$cjpm_path"
    fi
    if [[ -n "$dependency_cjpm_backup_path" && -f "$dependency_cjpm_backup_path" ]]; then
        mv "$dependency_cjpm_backup_path" "$dependency_cjpm_path"
    fi
    if [[ -n "$mirror_gen_backup_config" && -f "$mirror_gen_backup_config" ]]; then
        cp -p -f "$mirror_gen_config" "$mirror_gen_config_lastused"
        mv "$mirror_gen_backup_config" "$mirror_gen_config"
    fi
}

source "$CJMP_TOOL_PATH/third_party/${cangjieFolder}/envsetup.sh"
[[ -n $mirror_gen_config && -f $mirror_gen_config ]] && withinterop=true || withinterop=false

if [[ "$buildTarget" == "android" ]]; then
    cjpm build --target-dir "$build_path" --target="$cangjieTarget" $cangjieExtraArgs

elif [[ "$buildTarget" == "ios" || "$buildTarget" == "ios-sim" ]]; then
    cjpm_backup_path=$(mktemp "${cjpm_path}.backup.XXXXXX")
    cp "$cjpm_path" "$cjpm_backup_path"
    trap restore_tomls EXIT
    active_tools_source_root="${KEELS_ACTIVE_TOOLS_SOURCE_ROOT:-$CJMP_TOOL_PATH/tools}"
    update_toml_script_path="$active_tools_source_root/keels_tools/utils/update_toml.py"
    if [[ ! -f "$update_toml_script_path" ]]; then
        echo "error: update_toml.py not found: $update_toml_script_path" >&2
        exit 1
    fi
    echo "CJMP Tools source: $active_tools_source_root"
    python3 "$update_toml_script_path" "$cjpm_path"
    if [[ "${KEELS_IS_TEST_BUILD:-false}" == "true" && -f "$dependency_cjpm_path" ]]; then
        dependency_cjpm_backup_path=$(mktemp "${dependency_cjpm_path}.backup.XXXXXX")
        cp "$dependency_cjpm_path" "$dependency_cjpm_backup_path"
        python3 "$update_toml_script_path" "$dependency_cjpm_path"
    fi

    oc_bridge_dir="$SCRIPT_DIR/ios/oc_bridge"
    if $withinterop; then
        # generate mirrors only when needed
        dir_with_mirrors="${IOS_BRIDGE}/cangjie/cangjie_bridge/mirrors/bridge_mirrors"
        if [[ ! -d "$dir_with_mirrors" || "$mirror_gen_config" -nt "$mirror_gen_config_lastused" ]]; then
            mirror_gen_backup_config=$(mktemp "${mirror_gen_config}.backup.XXXXXX")
            gen_objc_mirrors "$dir_with_mirrors" "$mirror_gen_config" "$mirror_gen_backup_config"
        fi

        # properly placed interoplib for building mirrors
        export SCRIPT_BUILD_PATH="$packageOutputRoot"
        copy_interop_libraries "$SCRIPT_BUILD_PATH"

        # mirrors dependency
        echo "
[dependencies]
  bridge_mirrors = { path = \"../ios/oc_bridge/cangjie/cangjie_bridge/mirrors\" }
" >> "$cjpm_path"

        oc_bridge_sources="$oc_bridge_dir/cjmp.m"
        oc_bridge_libname="libcjmp_interop.dylib"
        featureArgs="--withinterop"

    else
        oc_bridge_sources="$oc_bridge_dir/cjmp.m $oc_bridge_dir/cjmp_ffi.m"
        oc_bridge_libname="libcjmp_ffi.dylib"
        featureArgs="--withffi"

    fi

    echo "Compiling Objective-C code in $oc_bridge_dir"
    find "$oc_bridge_dir" -type f -name "*.dylib" -delete
    xcrun --sdk $platform_name clang \
        -dynamiclib \
        -arch arm64 \
        -m${platform_name}-version-min=12.0 \
        -isysroot "$SDK_PATH" \
        -framework Foundation \
        -install_name "@rpath/${oc_bridge_libname}" \
        $oc_bridge_sources \
        -o "$oc_bridge_dir/${oc_bridge_libname}"

    cjpm build --target-dir "$build_path" --target="$cangjieTarget" $cangjieExtraArgs $featureArgs

    restore_tomls
    trap - EXIT
fi

cd $SCRIPT_DIR

# Copy files with specified extensions
# Usage: copy_libs <input_dir> <output_dir> <extension1> [extension2] ...
copy_libs() {
    local input_dir="$1"
    local output_dir="$2"
    shift 2
    local extensions=("$@")
    echo "extension: $extensions"

    if [[ ! -d "$input_dir" ]]; then
        echo "error: $input_dir not exist"
        return 1
    fi

    local file_count=0

    # Process each extension
    for ext in "${extensions[@]}"; do
        ext="${ext#.}"
        # Use find with maxdepth 1 to search only current directory (not subdirectories)
        while IFS= read -r -d '' file; do
            echo "copy: $(basename "$file")"
            cp -f "$file" "$output_dir/"
            ((file_count++)) || true
        done < <(find "$input_dir" -maxdepth 1 -name "*.${ext}" -type f -print0 2>/dev/null)
    done

    if [[ $file_count -gt 0 ]]; then
        echo "Success! Copied $file_count files to $output_dir"
    else
        echo "No matching files found"
    fi
}

# Analyze library dependencies
# Usage: analyze_dependencies <target_dir> <platform> <search_path1> [search_path2] ...
analyze_dependencies() {
    local target_dir="$1"
    local platform="$2"
    shift 2
    local search_paths=("$@")

    if [[ ! -d "$target_dir" ]]; then
        echo "error: target_dir not exist: $target_dir" >&2
        return 1
    fi

    local PYTHON_SCRIPT="$CJMP_TOOL_PATH/tools/keels_tools/utils/dependency.py"

    local dep_file
    if command -v mktemp >/dev/null 2>&1; then
        dep_file=$(mktemp -t cj_deps_XXXXXX)
    else
        dep_file="$SCRIPT_DIR/cj_deps_$$.txt"
        : > "$dep_file"
    fi

    python3 "$PYTHON_SCRIPT" "$target_dir" "$platform" "${search_paths[@]}" > "$dep_file"

    echo "$dep_file"
}

# Copy dependency files
# Usage: copy_dependencies <output_dir> <dependency1> [dependency2] ...
copy_dependencies() {
    local output_dir="$1"
    local dep_file="$2"

    echo "Starting to copy dependencies to: $output_dir"
    local copied_count=0

    mkdir -p "$output_dir"

    if [[ ! -f "$dep_file" ]]; then
        echo "warning: dependency list file not found: $dep_file"
        return 0
    fi

    while IFS= read -r dep_path; do
        [[ -z "$dep_path" ]] && continue
        if [[ -f "$dep_path" ]] || [[ -d "$dep_path" ]]; then
            local dep_file_name
            dep_file_name=$(basename "$dep_path")
            local dest_path="$output_dir/$dep_file_name"
            # Skip if source and destination resolve to the same path
            if [[ -e "$dest_path" ]] && [[ "$(realpath "$dep_path")" == "$(realpath "$dest_path")" ]]; then
                echo "Skipped (same file): $dep_file_name"
                continue
            fi
            if [[ -d "$dep_path" ]]; then
                cp -Rf "$dep_path" "$output_dir/" && ((copied_count++)) || true
            else
                cp -f "$dep_path" "$output_dir/" && ((copied_count++)) || true
            fi
        fi
    done < "$dep_file"

    echo "Dependency copy completed. Total files copied: $copied_count"

    rm -f "$dep_file" || true
}

copy_package_libs() {
    local input_dir="$1"
    local output_dir="$2"
    local copy_cjo="$3"
    shift 3
    local extensions=("$@")

    if [[ ! -d "$input_dir" ]]; then
        echo "error: $input_dir not exist"
        return 1
    fi

    if [[ "$copy_cjo" == "true" ]]; then
        copy_libs "$input_dir" "$output_dir" "${extensions[@]}" "cjo"
    else
        copy_libs "$input_dir" "$output_dir" "${extensions[@]}"
    fi
}

fix_ios_dylib_rpaths() {
    local frameworks_dir="$1"

    if [[ ! -d "$frameworks_dir" ]]; then
        echo "error: $frameworks_dir not exist"
        return 1
    fi

    while IFS= read -r -d '' dylib; do
        local dylib_name
        dylib_name=$(basename "$dylib")
        install_name_tool -id "@rpath/$dylib_name" "$dylib"
    done < <(find "$frameworks_dir" -maxdepth 1 -type f -name "*.dylib" -print0 2>/dev/null)

    while IFS= read -r -d '' dylib; do
        while IFS= read -r dep; do
            [[ -z "$dep" ]] && continue
            [[ "$dep" != /* ]] && continue
            local dep_name
            dep_name=$(basename "$dep")
            if [[ -f "$frameworks_dir/$dep_name" ]]; then
                install_name_tool -change "$dep" "@rpath/$dep_name" "$dylib"
            fi
        done < <(otool -L "$dylib" | awk 'NR > 1 { print $1 }')
    done < <(find "$frameworks_dir" -maxdepth 1 -type f -name "*.dylib" -print0 2>/dev/null)
}

cangjiePackageName="${KEELS_CJ_PACKAGE_NAME:-ohos_app_cangjie_entry}"
if [[ "${buildTarget}" == "android" ]]; then
    sourceSet="android"
elif [[ "${buildTarget}" == "ios" ]] || [[ "${buildTarget}" == "ios-sim" ]]; then
    sourceSet=ios
fi
if [[ "${KEELS_IS_TEST_BUILD:-false}" == "true" ]]; then
    inputDir="${packageOutputRoot}/${cangjiePackageName}"
else
    inputDir="${packageOutputRoot}/${cangjiePackageName}/${sourceSet}/product"
fi
if [[ "${buildTarget}" == "android" ]]; then
    # output: dependency storage path
    outputDir="${SCRIPT_DIR}/android/app/libs"

    # Clean and recreate output directory
    if [[ -d "$outputDir" ]]; then
        rm -rf "$outputDir"
    fi
    mkdir -p "$outputDir"
    mkdir -p "$outputDir/arm64-v8a"

    # copy: main library files
    copy_libs "$ANDROID_ENGINE_PATH" "$outputDir" "jar" # keels_android_adapter.jar
    copy_package_libs "$inputDir" "$outputDir/arm64-v8a" false "so"
    cp "${lib_share_path}" "$outputDir/arm64-v8a" #libc++_shared.so

    # copy: library dependencies
    dep_file="$(analyze_dependencies "$outputDir/arm64-v8a" "android" "$packageOutputRoot" "$ANDROID_CANGJIE_RUNTIME_PATH" "$ANDROID_CJ_FRONTEND" "$ANDROID_CANGJIE_STDX_PATH" "$ANDROID_CJMP_LIBS_PATH" "$ANDROID_TEST_PATH")"
    copy_dependencies "$outputDir/arm64-v8a" "$dep_file"
    cp "$ANDROID_ENGINE_PATH/arm64-v8a/libkeels_android.so" "$outputDir/arm64-v8a" # libkeels_android.so

    # copy: TDLib native library (dlopened by android/app/src/main/cpp/cjmp.cpp at runtime)
    if [[ -f "$TDLIB_PHASE0_ROOT/android/arm64-v8a/libtdjson.so" ]]; then
        cp "$TDLIB_PHASE0_ROOT/android/arm64-v8a/libtdjson.so" "$outputDir/arm64-v8a/" # libtdjson.so
    else
        echo "warning: libtdjson.so not found for android; TDLib runtime features will be unavailable." >&2
    fi

    if [[ "${buildProfile}" == "true" ]]; then
        # copy: debugger library
        cp "$CJMP_TOOLS_LIBS_PATH/android/libdevtools_debugger.so" "$outputDir/arm64-v8a" # libdevtools_debugger.so
    fi

elif [[ "${buildTarget}" == "ios" ]]; then
    # output: dependency storage path
    frameworksDir="./ios/frameworks"

     # Clean and recreate output directory
    if [[ -d "$frameworksDir" ]]; then
        rm -rf "$frameworksDir"
    fi
    mkdir -p "$frameworksDir"

    # copy: main library files
    copy_package_libs "$inputDir" "$frameworksDir" false "dylib"
    copy_libs "$IOS_BRIDGE" "$frameworksDir" "dylib" # libcjmp_[ffi|interop].dylib
    cp -r "$IOS_ENGINE_PATH" "$frameworksDir" # libkeels_ios.framework

    # copy: library dependencies
    dep_file="$(analyze_dependencies "$frameworksDir" "ios" "$packageOutputRoot" "$IOS_CANGJIE_PATH" "$IOS_CJ_FRONTEND" "$IOS_CANGJIE_STDX_PATH" "$IOS_CJMP_LIBS_PATH" "$IOS_TEST_PATH")"
    copy_dependencies "$frameworksDir" "$dep_file"
    # copy: TDLib native library (dlopened by ios/oc_bridge/cjmp_ffi.m at runtime; auto-embedded & signed by keels embed_and_sign_dylibs)
    if [[ -f "$TDLIB_PHASE0_ROOT/ios/libtdjson.dylib" ]]; then
        cp "$TDLIB_PHASE0_ROOT/ios/libtdjson.dylib" "$frameworksDir/" # libtdjson.dylib
    else
        echo "warning: libtdjson.dylib not found for ios; TDLib runtime features will be unavailable." >&2
    fi
    fix_ios_dylib_rpaths "$frameworksDir"

    if [[ "${buildProfile}" == "true" ]]; then
        # copy: debugger library
        cp "$CJMP_TOOLS_LIBS_PATH/ios/libdevtools_debugger.dylib" "$frameworksDir" # libdevtools_debugger.dylib
    fi

elif [[ "${buildTarget}" == "ios-sim" ]]; then
    # output: dependency storage path
    frameworksDir="./ios/frameworks"

     # Clean and recreate output directory
    if [[ -d "$frameworksDir" ]]; then
        rm -rf "$frameworksDir"
    fi
    mkdir -p "$frameworksDir"

    # copy: main library files
    copy_package_libs "$inputDir" "$frameworksDir" false "dylib"
    copy_libs "$IOS_BRIDGE" "$frameworksDir" "dylib" # libcjmp_[ffi|interop].dylib
    cp -r "$IOS_SIM_ENGINE_PATH" "$frameworksDir" # libkeels_ios.framework

    # copy: library dependencies
    dep_file="$(analyze_dependencies "$frameworksDir" "ios" "$packageOutputRoot" "$IOS_SIM_CANGJIE_PATH" "$IOS_SIM_CJ_FRONTEND" "$IOS_SIM_CANGJIE_STDX_PATH" "$IOS_SIM_CJMP_LIBS_PATH" "$IOS_SIM_TEST_PATH}")"
    copy_dependencies "$frameworksDir" "$dep_file"
    # copy: TDLib native library (dlopened by ios/oc_bridge/cjmp_ffi.m at runtime; auto-embedded & signed by keels embed_and_sign_dylibs)
    if [[ -f "$TDLIB_PHASE0_ROOT/ios-sim/libtdjson.dylib" ]]; then
        cp "$TDLIB_PHASE0_ROOT/ios-sim/libtdjson.dylib" "$frameworksDir/" # libtdjson.dylib (simulator)
    else
        echo "warning: libtdjson.dylib not found for ios-sim; TDLib runtime features will be unavailable on simulator." >&2
    fi
    fix_ios_dylib_rpaths "$frameworksDir"
fi
