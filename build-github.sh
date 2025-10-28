#!/bin/bash

# Go cross-compilation build script with CGO support
# Supports both CGO_ENABLED=0 (static) and CGO_ENABLED=1 (dynamic/static linking)

set -euo pipefail

# Platform definitions - comprehensive list
PLATFORMS=(
    'linux/amd64'
    'linux/arm64'
    'linux/arm/7'
    'linux/arm/5'
    'linux/386'
    'windows/amd64'
    'windows/386'
    'darwin/amd64'
    'darwin/arm64'
    'freebsd/amd64'
    'freebsd/arm/7'
    'linux/mips'
    'linux/mipsle'
    'linux/mips64'
    'linux/mips64le'
    'linux/riscv64'
)

# Android specific platforms
ANDROID_PLATFORMS=(
    'android/arm/7'
    'android/arm64'
    'android/386'
    'android/amd64'
)

# Build configuration
BUILD_TARGET=${BUILD_TARGET:-}
BUILD_MODE=${BUILD_MODE:-"both"}  # Options: "cgo", "static", "both"
ENABLE_STATIC_PIE=${ENABLE_STATIC_PIE:-"false"}
GOBIN=${GOBIN:-"go"}
ROOT=${PWD}
OUTPUT="${ROOT}/dist/TorrServer"
FAILURES=""
BUILT_ANY=0

# Flags and build configuration
LDFLAGS="-s -w -checklinkname=0"
BUILD_FLAGS="-tags=nosqlite -trimpath"

# Print build configuration
echo "=== Go Cross-Compilation Build Script ==="
echo "Build mode: ${BUILD_MODE}"
echo "Target: ${BUILD_TARGET:-"all platforms"}"
echo "Static PIE: ${ENABLE_STATIC_PIE}"
echo "Go version: $($GOBIN version)"
echo

# Utility functions
log_info() {
    echo "[INFO] $1"
}

log_warn() {
    echo "[WARN] $1"
}

log_error() {
    echo "[ERROR] $1" >&2
}

should_build_target() {
    local candidate="$1"
    [[ -z "${BUILD_TARGET}" || "${candidate}" == "${BUILD_TARGET}" ]]
}

should_build_android_section() {
    [[ -z "${BUILD_TARGET}" || "${BUILD_TARGET}" == android/* ]]
}

# Architecture-specific settings
set_goarm() {
    local arch="$1"
    if [[ "${arch}" =~ ^arm/([57])$ ]]; then
        GOARCH="arm"
        GOARM="${BASH_REMATCH[1]}"
        GO_ARM="GOARM=${GOARM}"
    else
        GOARM=""
        GO_ARM=""
    fi
}

set_gomips() {
    local arch="$1"
    if [[ "${arch}" =~ mips ]]; then
        local MIPS64=""
        [[ "${arch}" =~ mips64 ]] && MIPS64="64"
        GO_MIPS="GOMIPS${MIPS64}=softfloat"
    else
        GO_MIPS=""
    fi
}

# Cross-compiler setup for CGO
setup_cross_compiler() {
    local goos="$1"
    local goarch="$2"
    local cgo_enabled="$3"

    unset CC CXX PKG_CONFIG_PATH

    if [[ "${cgo_enabled}" != "1" ]]; then
        return 0
    fi

    case "${goos}/${goarch}" in
        linux/amd64)
            export CC="gcc"
            ;;
        linux/386)
            export CC="gcc -m32"
            ;;
        linux/arm64)
            export CC="aarch64-linux-gnu-gcc"
            ;;
        linux/arm)
            export CC="arm-linux-gnueabihf-gcc"
            ;;
        linux/mips)
            export CC="mips-linux-gnu-gcc"
            ;;
        linux/mipsle)
            export CC="mipsel-linux-gnu-gcc"
            ;;
        linux/mips64)
            export CC="mips64-linux-gnuabi64-gcc"
            ;;
        linux/mips64le)
            export CC="mips64el-linux-gnuabi64-gcc"
            ;;
        linux/riscv64)
            export CC="riscv64-linux-gnu-gcc"
            ;;
        windows/amd64)
            export CC="x86_64-w64-mingw32-gcc"
            export CXX="x86_64-w64-mingw32-g++"
            ;;
        windows/386)
            export CC="i686-w64-mingw32-gcc"
            export CXX="i686-w64-mingw32-g++"
            ;;
        darwin/amd64)
            # Darwin cross-compilation with CGO is complex
            # Requires osxcross or similar toolchain
            log_warn "Darwin cross-compilation with CGO requires osxcross toolchain"
            return 1
            ;;
        darwin/arm64)
            log_warn "Darwin ARM64 cross-compilation with CGO requires osxcross toolchain"
            return 1
            ;;
        *)
            log_warn "No cross-compiler configured for ${goos}/${goarch}"
            return 1
            ;;
    esac

    log_info "Using CC=${CC:-unset} for ${goos}/${goarch}"
    return 0
}

# Determine CGO support for platform
platform_supports_cgo() {
    local platform="$1"
    case "${platform}" in
        linux/amd64|linux/386|linux/arm64|linux/arm/*|windows/amd64|windows/386)
            return 0
            ;;
        linux/mips*|linux/riscv64)
            # Limited CGO support, may work with proper toolchain
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

supports_dynamic_nocgo() {
    local goos="$1"
    local goarch="$2"

    if [[ "${ENABLE_NOCGO_DYNAMIC:-false}" != "true" ]]; then
        return 1
    fi

    if [[ "${goos}" == "linux" ]]; then
        case "${goarch}" in
            amd64|arm64)
                return 0
                ;;
        esac
    fi

    return 1
}

# Build function for a specific configuration
build_binary() {
    local goos="$1"
    local goarch="$2"
    local goarm_suffix="$3"
    local cgo_enabled="$4"
    local build_type="$5"  # "static", "dynamic", "android", etc.

    local cgo_suffix
    if [[ "${cgo_enabled}" == "1" ]]; then
        cgo_suffix="cgo"
    else
        cgo_suffix="nocgo"
    fi

    local bin_filename="${OUTPUT}-${goos}-${goarch}${goarm_suffix}-${cgo_suffix}"

    if [[ -n "${build_type}" ]]; then
        bin_filename="${bin_filename}-${build_type}"
    fi

    [[ "${goos}" == "windows" ]] && bin_filename="${bin_filename}.exe"

    local target_ldflags="${LDFLAGS}"
    local target_build_flags="${BUILD_FLAGS}"

    # Configure linking for CGO builds
    if [[ "${cgo_enabled}" == "1" ]]; then
        if [[ "${goos}" == "linux" ]]; then
            if [[ "${build_type}" == "static" ]]; then
                target_ldflags="${target_ldflags} -linkmode=external -extldflags=-static"
                if command -v musl-gcc >/dev/null 2>&1 && [[ "${goarch}" == "amd64" ]]; then
                    export CC="musl-gcc"
                    log_info "Using musl-gcc for static linking"
                fi

                if [[ "${ENABLE_STATIC_PIE}" == "true" ]]; then
                    target_build_flags="${target_build_flags} -buildmode=pie"
                    target_ldflags="${target_ldflags} -extldflags=-static-pie"
                fi
            elif [[ "${build_type}" == "dynamic" ]]; then
                target_ldflags="${target_ldflags} -linkmode=external"
            else
                target_ldflags="${target_ldflags} -linkmode=external"
            fi
        else
            target_ldflags="${target_ldflags} -linkmode=external"
        fi
    else
        if [[ "${build_type}" == "dynamic" ]]; then
            target_ldflags="${target_ldflags} -linkmode=external"

            if [[ "${goos}" == "linux" ]]; then
                target_build_flags="${target_build_flags} -buildmode=pie"
            else
                log_warn "Dynamic build without CGO not supported for ${goos}/${goarch}"
                return 1
            fi
        fi
    fi

    # Setup environment
    local env_vars="CGO_ENABLED=${cgo_enabled} GOOS=${goos} GOARCH=${goarch} ${GO_ARM} ${GO_MIPS}"

    # Build command
    local cmd="${env_vars} ${GOBIN} build -ldflags='${target_ldflags}' ${target_build_flags} -o ${bin_filename} ./cmd"

    log_info "Building ${build_type} binary: ${goos}/${goarch}${goarm_suffix}"
    echo "Command: ${cmd}"

    if eval "${cmd}"; then
        # Verify the binary
        if [[ -f "${bin_filename}" ]]; then
            local file_info
            file_info=$(file "${bin_filename}" 2>/dev/null || echo "file command not available")
            echo "Built: ${bin_filename} (${file_info})"

            # For Linux binaries, show linking information
            if [[ "${goos}" == "linux" && "${cgo_enabled}" == "1" ]]; then
                local ldd_info
                ldd_info=$(ldd "${bin_filename}" 2>&1 || echo "not a dynamic executable or ldd not available")
                echo "Linking: ${ldd_info}"
            fi
        else
            log_error "Binary not created: ${bin_filename}"
            return 1
        fi
        return 0
    else
        log_error "Build failed for ${goos}/${goarch}${goarm_suffix} (${build_type})"
        return 1
    fi
}

# Main build function
build_platform() {
    local platform="$1"
    local goos goarch goarm_suffix

    goos=${platform%%/*}
    goarch=${platform#*/}

    # Handle ARM variants
    set_goarm "${goarch}"
    if [[ -n "${GOARM}" ]]; then
        goarch="arm"
        goarm_suffix="${GOARM}"
    else
        goarm_suffix=""
    fi
    set_gomips "${goarch}"

    log_info "Processing platform: ${platform}"

    # Determine what to build based on BUILD_MODE
    local build_static=false
    local build_cgo=false

    case "${BUILD_MODE}" in
        "static")
            build_static=true
            ;;
        "cgo")
            build_cgo=true
            ;;
        "both")
            build_static=true
            if platform_supports_cgo "${platform}"; then
                build_cgo=true
            fi
            ;;
        *)
            log_error "Invalid BUILD_MODE: ${BUILD_MODE}"
            return 1
            ;;
    esac

    local platform_failed=false

    # Build static binary (CGO_ENABLED=0)
    if [[ "${build_static}" == "true" ]]; then
        if ! build_binary "${goos}" "${goarch}" "${goarm_suffix}" "0" "static"; then
            platform_failed=true
            FAILURES="${FAILURES} ${platform}(nocgo-static)"
        else
            BUILT_ANY=1
        fi

        if supports_dynamic_nocgo "${goos}" "${goarch}"; then
            if ! build_binary "${goos}" "${goarch}" "${goarm_suffix}" "0" "dynamic"; then
                platform_failed=true
                FAILURES="${FAILURES} ${platform}(nocgo-dynamic)"
            else
                BUILT_ANY=1
            fi
        else
            log_info "Skipping nocgo dynamic build for ${platform} (unsupported; set ENABLE_NOCGO_DYNAMIC=true to attempt)"
        fi
    fi

    # Build CGO binary (CGO_ENABLED=1)
    if [[ "${build_cgo}" == "true" ]]; then
        local cross_compiler_ok=false

        if setup_cross_compiler "${goos}" "${goarch}" "1"; then
            cross_compiler_ok=true
            if ! build_binary "${goos}" "${goarch}" "${goarm_suffix}" "1" "static"; then
                platform_failed=true
                FAILURES="${FAILURES} ${platform}(cgo-static)"
            else
                BUILT_ANY=1
            fi
        else
            log_warn "CGO cross-compilation not supported for ${platform}"
            FAILURES="${FAILURES} ${platform}(cgo-unsupported)"
            platform_failed=true
        fi

        if [[ "${cross_compiler_ok}" == "true" ]]; then
            if setup_cross_compiler "${goos}" "${goarch}" "1"; then
                if ! build_binary "${goos}" "${goarch}" "${goarm_suffix}" "1" "dynamic"; then
                    platform_failed=true
                    FAILURES="${FAILURES} ${platform}(cgo-dynamic)"
                else
                    BUILT_ANY=1
                fi
            else
                log_warn "CGO cross-compilation not supported for ${platform} (dynamic)"
                FAILURES="${FAILURES} ${platform}(cgo-dynamic-unsupported)"
                platform_failed=true
            fi
        fi
    fi

    [[ "${platform_failed}" == "false" ]]
}

# Android build section
build_android() {
    log_info "Building Android binaries..."

    local ndk_version="25.2.9519653"
    local ndk_toolchain="${ROOT}/android-ndk-r25c/toolchains/llvm/prebuilt/linux-x86_64"

    if [[ ! -d "${ndk_toolchain}" ]]; then
        log_error "Android NDK toolchain not found at ${ndk_toolchain}"
        return 1
    fi

    local android_compilers=(
        "arm/7:armv7a-linux-androideabi21-clang"
        "arm64:aarch64-linux-android21-clang"
        "386:i686-linux-android21-clang"
        "amd64:x86_64-linux-android21-clang"
    )

    for entry in "${android_compilers[@]}"; do
        local goarch_entry="${entry%:*}"
        local compiler="${entry#*:}"
        local platform="android/${goarch_entry}"

        if ! should_build_target "${platform}"; then
            continue
        fi

        local goos="android"
        local goarch="${goarch_entry}"
        local goarm_suffix=""

        set_goarm "${goarch_entry}"
        GO_MIPS=""

        if [[ -n "${GOARM}" ]]; then
            goarch="arm"
            goarm_suffix="${GOARM}"
        fi

        export CC="${ndk_toolchain}/bin/${compiler}"
        export CXX="${ndk_toolchain}/bin/${compiler}++"

        log_info "Building Android binary: ${platform}"

        if ! build_binary "${goos}" "${goarch}" "${goarm_suffix}" "1" "android"; then
            FAILURES="${FAILURES} ${platform}"
        else
            BUILT_ANY=1
        fi
    done
}

# Preparation steps
prepare_build() {
    log_info "Preparing build environment..."

    # Clean and setup
    cd "${ROOT}/server" || exit 1
    $GOBIN clean -cache -modcache -i -r
    $GOBIN mod tidy

    # Create dist directory
    mkdir -p "${ROOT}/dist"

    cd "${ROOT}/server" || exit 1
}

# Web build
build_web() {
    log_info "Building web assets..."
    export NODE_OPTIONS=--openssl-legacy-provider
    $GOBIN run gen_web.go
}

# API documentation
build_docs() {
    log_info "Building API documentation..."
    $GOBIN install github.com/swaggo/swag/cmd/swag@latest
    cd "${ROOT}/server" || exit 1
    swag init -g web/server.go
    cd "${ROOT}" || exit 1
}

# Main execution
main() {
    if [[ -n "${BUILD_TARGET}" ]]; then
        log_info "Building only target: ${BUILD_TARGET}"
    fi

    # Preparation steps
    build_web
    build_docs
    prepare_build

    # Build regular platforms
    for platform in "${PLATFORMS[@]}"; do
        if should_build_target "${platform}"; then
            if build_platform "${platform}"; then
                BUILT_ANY=1
            fi
        fi
    done

    # Build Android if requested
    if should_build_android_section; then
        build_android
    fi

    # Results
    echo
    if [[ ${BUILT_ANY} -eq 0 ]]; then
        log_error "No build targets matched BUILD_TARGET=${BUILD_TARGET}"
        exit 1
    fi

    if [[ -n "${FAILURES}" ]]; then
        log_error "Build failures:${FAILURES}"
        exit 1
    fi

    log_info "Build completed successfully!"

    # Show built binaries
    if [[ -d "${ROOT}/dist" ]]; then
        echo
        log_info "Built binaries:"
        ls -la "${ROOT}/dist/"
    fi
}

# Execute main function
main "$@"
