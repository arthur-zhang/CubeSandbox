#!/usr/bin/env bash
set -euo pipefail

# 从 /data_jfs/cube/ 拷贝 cubelet 二进制，替换并重启服务
# 用法: ./restart-cubelet.sh [cubelet二进制路径]

# 可配置路径
NEW_CUBELET="${1:-/data_jfs/cube/cubelet}"
INSTALLED_CUBELET="${INSTALLED_CUBELET:-/usr/local/services/cubetoolbox/Cubelet/bin/cubelet}"
SCRIPTS_DIR="${SCRIPTS_DIR:-/usr/local/services/cubetoolbox/scripts/one-click}"

# 检查新二进制文件是否存在
if [[ ! -f "${NEW_CUBELET}" ]]; then
    echo "错误: cubelet 二进制不存在: ${NEW_CUBELET}" >&2
    echo "用法: $0 [cubelet二进制路径]" >&2
    exit 1
fi

# 检查脚本目录是否存在
if [[ ! -d "${SCRIPTS_DIR}" ]]; then
    echo "错误: one-click 脚本目录不存在: ${SCRIPTS_DIR}" >&2
    exit 1
fi

echo "=== 重启 cubelet ==="
echo "新二进制: ${NEW_CUBELET}"
echo "目标路径: ${INSTALLED_CUBELET}"
echo ""

# 1. 停止本地核心服务
echo "[1/3] 停止本地核心服务..."
"${SCRIPTS_DIR}/down-local.sh"

# 2. 替换二进制文件
echo ""
echo "[2/3] 替换 cubelet 二进制..."
cp -f "${NEW_CUBELET}" "${INSTALLED_CUBELET}"
chmod +x "${INSTALLED_CUBELET}"
ls -la "${INSTALLED_CUBELET}"

# 3. 重新启动核心服务
echo ""
echo "[3/3] 启动核心服务..."
"${SCRIPTS_DIR}/up.sh"

echo ""
echo "=== cubelet 重启完成 ==="
echo "当前进程:"
ps aux | grep "${INSTALLED_CUBELET}" | grep -v grep || true
