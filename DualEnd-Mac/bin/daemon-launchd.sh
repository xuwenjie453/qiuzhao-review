#!/bin/bash
# launchd 的最小入口：保持前台、用 exec 交还进程所有权给 Node。
# 不要在这里使用 nohup 或 "&"；由 launchd 负责重启和生命周期管理。
set -o pipefail

# launchd 必须使用物理路径，不能经 Documents 兼容符号链接访问源码。
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd -P)"
export DUALEND_BRIDGE_PORT="${DUALEND_BRIDGE_PORT:-57689}"

exec node "${REPO_ROOT}/DualEnd-Mac/bin/qreview-dual.mjs" daemon start
