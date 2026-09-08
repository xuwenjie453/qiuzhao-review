// 7 态 UX 连接状态 (M-7.2)。UI 在所有状态都可读 cache(首次从未同步除外)。
enum ConnectionPhase: Equatable {
    case cachedOffline       // 离线 · 显示本地内容
    case discovering
    case connecting
    case syncing
    case ready
    case localNetworkDenied  // 需要本地网络权限(明示, 不伪装"Mac 不在线")
    case protocolUnsupported // 协议版本不兼容
}
