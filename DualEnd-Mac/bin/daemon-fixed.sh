#!/bin/bash
# 双端 daemon 固定端口管理脚本（2026-09-13）
#
# 动机：iPad 端支持"静态端点直连"（StaticEndpoint，默认 192.168.1.197:57689），
# 绕开 mDNS/DNS 解析以免疫 VPN 干扰。为此 bridge 端口必须固定。
# 端口与 iPad 端 QiuZhaoReader/Connectivity/BonjourBrowser.swift 的
# StaticEndpoint.defaultPort 保持一致 —— 改这里必须同步改那里。
#
# 用法:
#   daemon-fixed.sh start    通过 launchd 启动（固定端口 + 系统托管）
#   daemon-fixed.sh stop     卸载 launchd 服务并优雅停止（含孤儿 dns-sd 清理）
#   daemon-fixed.sh restart  重启
#   daemon-fixed.sh status   状态
set -o pipefail

# 用物理路径写入 plist，避免旧 Documents 兼容符号链接再次触发 TCC 限制。
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd -P)"
CLI=(node "${REPO_ROOT}/DualEnd-Mac/bin/qreview-dual.mjs")
FIXED_PORT="${DUALEND_BRIDGE_PORT:-57689}"
LOCK="${REPO_ROOT}/系统数据/dual-end/runtime/daemon.lock"
LOG_DIR="${HOME}/Library/Logs/QiuZhaoReview"
LOG="${LOG_DIR}/daemon-stdout.log"
LABEL="local.qiuzhaoreview.daemon"
USER_UID="$(id -u)"
LAUNCH_DIR="${HOME}/Library/LaunchAgents"
PLIST="${LAUNCH_DIR}/${LABEL}.plist"
TEMPLATE="${REPO_ROOT}/DualEnd-Mac/launchd/${LABEL}.plist.in"

launch_domain() { echo "gui/${USER_UID}"; }

launch_loaded() {
  launchctl print "$(launch_domain)/${LABEL}" >/dev/null 2>&1
}

xml_escape_replacement() {
  # sed replacement 中的 & 和 | 必须转义；仓库路径与 node 路径都可能包含空格。
  printf '%s' "$1" | sed 's/[&|]/\\&/g'
}

install_launch_agent() {
  local escaped_root escaped_home temporary
  command -v node >/dev/null || { echo "未找到 node，无法安装 launchd 服务" >&2; return 1; }
  [ -f "${TEMPLATE}" ] || { echo "缺少 launchd 模板: ${TEMPLATE}" >&2; return 1; }
  mkdir -p "${LAUNCH_DIR}" "${LOG_DIR}"
  escaped_root="$(xml_escape_replacement "${REPO_ROOT}")"
  escaped_home="$(xml_escape_replacement "${HOME}")"
  temporary="${PLIST}.tmp.$$"
  sed -e "s|__REPO_ROOT__|${escaped_root}|g" -e "s|__HOME_DIR__|${escaped_home}|g" "${TEMPLATE}" > "${temporary}"
  if ! plutil -lint "${temporary}" >/dev/null; then
    rm -f "${temporary}"
    echo "生成的 launchd plist 无效" >&2
    return 1
  fi
  install -m 644 "${temporary}" "${PLIST}"
  rm -f "${temporary}"
  chmod 755 "${REPO_ROOT}/DualEnd-Mac/bin/daemon-launchd.sh"
}

stop_launch_agent() {
  if launch_loaded; then
    launchctl bootout "$(launch_domain)/${LABEL}" >/dev/null 2>&1 || return 1
  fi
}

running_pid() {
  [ -f "${LOCK}" ] || return 1
  local p
  p=$(python3 -c "import json;print(json.load(open('${LOCK}'))['pid'])" 2>/dev/null) || return 1
  if [ -n "${p}" ] && kill -0 "${p}" 2>/dev/null; then echo "${p}"; return 0; fi
  return 1
}

cleanup_orphans() {
  # daemon 非正常退出时其 dns-sd 子进程会变孤儿继续广播旧端口（导致服务名冲突/死端口），
  # 这里统一清理；仅在 start（daemon 未在运行）与 stop 之后调用，不会误杀在跑的广播。
  if pgrep -f "dns-sd -R qiuzao-review-" >/dev/null 2>&1; then
    pkill -f "dns-sd -R qiuzao-review-" 2>/dev/null && echo "已清理残留 Bonjour 广播进程"
  fi
  return 0
}

case "${1:-status}" in
  start)
    if P=$(running_pid); then
      echo "daemon 已在运行 pid=${P}"
      "${CLI[@]}" daemon status
      exit 0
    fi
    cleanup_orphans
    rm -f "${LOCK}"
    install_launch_agent
    # stale service 可能来自一次中断的 bootstrap；先卸载同 label 再加载最新 plist。
    stop_launch_agent || true
    launchctl bootstrap "$(launch_domain)" "${PLIST}"
    launchctl kickstart -k "$(launch_domain)/${LABEL}"
    echo "daemon 由 launchd 启动 固定端口=${FIXED_PORT} label=${LABEL} 日志=${LOG}"
    sleep 4
    "${CLI[@]}" daemon status
    ;;
  stop)
    stop_launch_agent || true
    if P=$(running_pid); then
      kill -TERM "${P}" 2>/dev/null && echo "已发送 SIGTERM 优雅停止 pid=${P}"
      sleep 2
    fi
    cleanup_orphans
    rm -f "${LOCK}"
    echo "daemon 已停止"
    ;;
  restart)
    "$0" stop; sleep 1; "$0" start
    ;;
  status)
    "${CLI[@]}" daemon status
    ;;
  *)
    echo "用法: $0 {start|stop|restart|status}"; exit 1
    ;;
esac
