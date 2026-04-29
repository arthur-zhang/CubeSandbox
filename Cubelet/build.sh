#!/usr/bin/env bash
set -euo pipefail

# 拆分构建脚本：可单独构建 cubelet / cubecli，支持指定输出目录
# 用法:
#   ./build.sh              # 构建全部（cubelet + cubecli），输出到 build/
#   ./build.sh cubelet      # 只构建 cubelet
#   ./build.sh cubecli      # 只构建 cubecli
#   ./build.sh all /data_jfs/cube  # 构建全部并复制到指定目录

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

# 目标应用
ALL_APPS="cubelet cubecli"
BUILD_TARGETS="${1:-all}"
OUTPUT_DIR="${2:-${SCRIPT_DIR}/build}"

# 版本信息
APP_VERSION="0.4.24"
GIT_COMMIT="$(git rev-parse --short HEAD 2>/dev/null || echo 'unknown')"
BUILD_DATE="$(date +'%Y%m%d-%H:%M:%S')"
GO_VERSION="$(go version | awk '{print $3}')"
VERSION="${APP_VERSION}-${GIT_COMMIT}-${BUILD_DATE}-${GO_VERSION}"
VERSION_PKG="github.com/tencentcloud/CubeSandbox/Cubelet/pkg/version"
BUILD_FLAGS=(-ldflags "-X ${VERSION_PKG}.Version=${VERSION}")

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}
warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}
error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

# 确定要构建的目标
if [[ "${BUILD_TARGETS}" == "all" ]]; then
    BUILD_TARGETS="${ALL_APPS}"
fi

info "=== Cubelet 拆分构建 ==="
info "构建目标: ${BUILD_TARGETS}"
info "版本: ${VERSION}"
info "输出目录: ${OUTPUT_DIR}"
echo ""

# 步骤1: 下载依赖
step_deps() {
    info "[步骤 1/3] 下载 Go 依赖..."
    go mod download
    echo ""
}

# 步骤2: 构建指定应用
step_build() {
    local app="$1"
    info "[步骤 2/3] 构建 ${app} ..."

    if [[ ! -d "cmd/${app}" ]]; then
        error "构建目标不存在: cmd/${app}"
        exit 1
    fi

    mkdir -p "${OUTPUT_DIR}"

    local start_time end_time duration
    start_time=$(date +%s)

    GO111MODULE=on GOARCH=amd64 GOOS=linux \
        go build -o "${OUTPUT_DIR}/${app}" \
        "${BUILD_FLAGS[@]}" \
        "cmd/${app}"/*.go

    end_time=$(date +%s)
    duration=$((end_time - start_time))

    info "${app} 构建完成 (${duration}s)"
    ls -lh "${OUTPUT_DIR}/${app}"
    echo ""
}

# 步骤3: 复制到外部目录（可选）
step_copy() {
    local dest_dir="$1"
    if [[ "${OUTPUT_DIR}" == "${dest_dir}" ]]; then
        return
    fi
    info "[步骤 3/3] 复制编译产物到 ${dest_dir} ..."
    mkdir -p "${dest_dir}"
    for app in ${BUILD_TARGETS}; do
        cp -f "${OUTPUT_DIR}/${app}" "${dest_dir}/${app}"
        info "已复制: ${dest_dir}/${app}"
    done
    echo ""
}

# 执行构建
main() {
    step_deps

    for app in ${BUILD_TARGETS}; do
        step_build "${app}"
    done

    # 如果 OUTPUT_DIR 不是默认的 build/，则额外复制
    if [[ "${OUTPUT_DIR}" != "${SCRIPT_DIR}/build" ]]; then
        step_copy "${OUTPUT_DIR}"
    fi

    info "=== 构建完成 ==="
    echo "产物列表:"
    for app in ${BUILD_TARGETS}; do
        if [[ -f "${OUTPUT_DIR}/${app}" ]]; then
            echo "  ${OUTPUT_DIR}/${app}"
        fi
    done
}

main "$@"
