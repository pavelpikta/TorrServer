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
  if [[ "$1" =~ arm([5,7]) ]]; then
    GOARCH="arm"
    GOARM="${BASH_REMATCH[1]}"
    GO_ARM="GOARM=${GOARM}"
  else
    GOARM=""
    GO_ARM=""
  fi
}
# use softfloat for mips builds
set_gomips() {
  if [[ "$1" =~ mips ]]; then
    if [[ "$1" =~ mips(64) ]]; then MIPS64="${BASH_REMATCH[1]}"; fi
    GO_MIPS="GOMIPS${MIPS64}=softfloat"
  else
    GO_MIPS=""
  fi
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
$GOBIN clean -i -r -cache # --modcache
$GOBIN mod tidy

BUILD_FLAGS="-ldflags=${LDFLAGS} -tags=nosqlite -trimpath"

#####################################
### X86 build section
#####

for PLATFORM in "${PLATFORMS[@]}"; do
  if ! should_build_target "${PLATFORM}"; then
    continue
  fi
  GOOS=${PLATFORM%/*}
  GOARCH=${PLATFORM#*/}
  set_goarm "$GOARCH"
  set_gomips "$GOARCH"
  BIN_FILENAME="${OUTPUT}-${GOOS}-${GOARCH}${GOARM}"
  if [[ "${GOOS}" == "windows" ]]; then BIN_FILENAME="${BIN_FILENAME}.exe"; fi
  CMD="GOOS=${GOOS} GOARCH=${GOARCH} ${GO_ARM} ${GO_MIPS} ${GOBIN} build ${BUILD_FLAGS} -o ${BIN_FILENAME} ./cmd"
  echo "${CMD}"
  BUILT_ANY=1
  eval "$CMD" || FAILURES="${FAILURES} ${GOOS}/${GOARCH}${GOARM}"
#  CMD="../upx -q ${BIN_FILENAME}"; # upx --brute produce much smaller binaries
#  echo "compress with ${CMD}"
#  eval "$CMD"
done

#####################################
### Android build section
#####

declare -a COMPILERS=(
  "arm7:armv7a-linux-androideabi21-clang"
  "arm64:aarch64-linux-android21-clang"
  "386:i686-linux-android21-clang"
  "amd64:x86_64-linux-android21-clang"
)

if should_build_android_section; then
  export NDK_VERSION="25.2.9519653" # 25.1.8937393
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
#    CMD="../upx -q ${BIN_FILENAME}"; # upx --brute produce much smaller binaries
#    echo "compress with ${CMD}"
#    eval "$CMD"
  done
fi

# eval errors
if [[ ${BUILT_ANY} -eq 0 ]]; then
  echo "No build targets matched BUILD_TARGET=${BUILD_TARGET}"
  exit 1
fi
if [[ "${FAILURES}" != "" ]]; then
  echo ""
  echo "failed on: ${FAILURES}"
  exit 1
fi
