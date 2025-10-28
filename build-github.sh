#!/bin/bash

PLATFORMS=(
  'linux/amd64'
  'linux/arm64'
  'linux/arm7'
  'linux/arm5'
  'linux/386'
  'windows/amd64'
  'windows/386'
  'darwin/amd64'
  'darwin/arm64'
  'freebsd/amd64'
  'freebsd/arm7'
  'linux/mips'
  'linux/mipsle'
  'linux/mips64'
  'linux/mips64le'
  'linux/riscv64'
)

type setopt >/dev/null 2>&1

BUILD_TARGET=${BUILD_TARGET:-}
CGO_ENABLED=0 # Default disable CGO

should_build_target() {
  local candidate="$1"
  if [[ -z "${BUILD_TARGET}" ]]; then
    return 0
  fi
  if [[ "${candidate}" == "${BUILD_TARGET}" ]]; then
    return 0
  fi
  return 1
}

should_build_android_section() {
  if [[ -z "${BUILD_TARGET}" ]]; then
    return 0
  fi
  [[ "${BUILD_TARGET}" == android/* ]]
}

set_goarm() {
  if [[ "$1" =~ arm([57]) ]]; then
    GOARCH="arm"
    GOARM="${BASH_REMATCH[1]}"
    GO_ARM="GOARM=${GOARM}"
  else
    GOARM=""
    GO_ARM=""
  fi
}

set_gomips() {
  if [[ "$1" =~ mips ]]; then
    local MIPS64=""
    if [[ "$1" =~ mips64 ]]; then MIPS64="64"; fi
    GO_MIPS="GOMIPS${MIPS64}=softfloat"
  else
    GO_MIPS=""
  fi
}

set_cc() {
  # Sets appropriate CC based on GOOS/GOARCH when CGO_ENABLED=1
  if [[ "${CGO_ENABLED}" != "1" ]]; then
    unset CC
    return
  fi

  case "${GOOS}/${GOARCH}" in
    linux/amd64)
      export CC="gcc"
      ;;
    linux/arm64)
      export CC="aarch64-linux-gnu-gcc"
      ;;
    linux/arm*)
      export CC="arm-linux-gnueabihf-gcc"
      ;;
    linux/386)
      export CC="gcc -m32"
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
    darwin/*)
      # On darwin cross-compilation with cgo: requires installed cross toolchain (complex)
      unset CC
      ;;
    windows/amd64)
      export CC="x86_64-w64-mingw32-gcc"
      ;;
    windows/386)
      export CC="i686-w64-mingw32-gcc"
      ;;
    *)
      unset CC
      ;;
  esac
}

GOBIN="go"

$GOBIN version

LDFLAGS="'-s -w -checklinkname=0'"
FAILURES=""
ROOT=${PWD}
OUTPUT="${ROOT}/dist/TorrServer"
BUILT_ANY=0

if [[ -n "${BUILD_TARGET}" ]]; then
  echo "Building only target: ${BUILD_TARGET}"
fi

#### Build web
echo "Build web"
export NODE_OPTIONS=--openssl-legacy-provider
$GOBIN run gen_web.go

#### Update api docs
echo "Build docs"
$GOBIN install github.com/swaggo/swag/cmd/swag@latest
cd "${ROOT}/server" || exit 1
swag init -g web/server.go

#### Build server
echo "Build server"
cd "${ROOT}/server" || exit 1
$GOBIN clean -cache -modcache -i -r
$GOBIN mod tidy

# BUILD_FLAGS="-ldflags=${LDFLAGS} -tags=nosqlite -trimpath"
BUILD_FLAGS=""

for PLATFORM in "${PLATFORMS[@]}"; do
  if ! should_build_target "${PLATFORM}"; then
    continue
  fi
  GOOS=${PLATFORM%/*}
  GOARCH=${PLATFORM#*/}
  set_goarm "$GOARCH"
  set_gomips "$GOARCH"
  set_cc
  BIN_FILENAME="${OUTPUT}-${GOOS}-${GOARCH}${GOARM}"
  if [[ "${GOOS}" == "windows" ]]; then BIN_FILENAME="${BIN_FILENAME}.exe"; fi
  CMD="CGO_ENABLED=${CGO_ENABLED} GOOS=${GOOS} GOARCH=${GOARCH} ${GO_ARM} ${GO_MIPS} CC=${CC:-} ${GOBIN} build ${BUILD_FLAGS} -o ${BIN_FILENAME} ./cmd"
  echo "${CMD}"
  BUILT_ANY=1
  eval "${CMD}" || FAILURES="${FAILURES} ${GOOS}/${GOARCH}${GOARM}"
done

#### Android build section

declare -a COMPILERS=(
  "arm7:armv7a-linux-androideabi21-clang"
  "arm64:aarch64-linux-android21-clang"
  "386:i686-linux-android21-clang"
  "amd64:x86_64-linux-android21-clang"
)

if should_build_android_section; then
  export NDK_VERSION="25.2.9519653"
  export NDK_TOOLCHAIN="${ROOT}/android-ndk-r25c/toolchains/llvm/prebuilt/linux-x86_64"
  if [[ ! -d "${NDK_TOOLCHAIN}" ]]; then
    echo "Android NDK toolchain not found at ${NDK_TOOLCHAIN}"
    exit 1
  fi
  GOOS=android

  for V in "${COMPILERS[@]}"; do
    GOARCH=${V%:*}
    PLATFORM="android/${GOARCH}"
    if ! should_build_target "${PLATFORM}"; then
      continue
    fi
    COMPILER=${V#*:}
    export CC="$NDK_TOOLCHAIN/bin/$COMPILER"
    export CXX="$NDK_TOOLCHAIN/bin/$COMPILER++"
    set_goarm "$GOARCH"
    BIN_FILENAME="${OUTPUT}-${GOOS}-${GOARCH}${GOARM}"
    CMD="GOOS=${GOOS} GOARCH=${GOARCH} ${GO_ARM} CGO_ENABLED=1 ${GOBIN} build ${BUILD_FLAGS} -o ${BIN_FILENAME} ./cmd"
    echo "${CMD}"
    BUILT_ANY=1
    eval "${CMD}" || FAILURES="${FAILURES} ${GOOS}/${GOARCH}${GOARM}"
  done
fi

if [[ ${BUILT_ANY} -eq 0 ]]; then
  echo "No build targets matched BUILD_TARGET=${BUILD_TARGET}"
  exit 1
fi
if [[ "${FAILURES}" != "" ]]; then
  echo ""
  echo "failed on: ${FAILURES}"
  exit 1
fi
