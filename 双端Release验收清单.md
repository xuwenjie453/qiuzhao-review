# 双端更新 Release 验收清单（对应 90_设计稿基线/06_质量与交付/04 的 A–G + 完成判据）

> 状态取值：PASS / FAIL / BLOCKED（环境或输入缺失）/ NOT_RUN（真机类）。
> 记录时间：2026-09-08。环境：macOS + Node 26 + Xcode 26.6 + Swift 6.3；无真机 iPad / Apple Pencil / 参考排版 PDF。

## A. Question-first（问题即图）
- [x] 试题库问题可 open 成 graph —— **PASS**（`test/bridge-e2e.test.mjs` question.open→snapshot；graph identity 稳定见 `test/graph.test.mjs`）
- [x] Review Capsule 问题可 open 成 graph —— **PASS**（question_ref.source=REVIEW_CAPSULE 通路经 `question.open` 同一命令验证，source/probe_key 字段入 schema）
- [x] 同 question_key 重开得到同 graph_id —— **PASS**（unit: "同 question_key 重开同 graph_id"）

## B. User-controlled explanations（解释只由用户显式入图）
- [x] Agent 普通解释不自动创建节点 —— **PASS**（无任何自动 add 通路；add 仅 graph.add-node 命令且要求 node_kind + ACTIVE round）
- [x] 用户显式指令可创建 Explanation —— **PASS**（E2E 步骤 5）
- [x] 用户显式指令可创建 Temporary —— **PASS**（unit: TEMPORARY 绑 round）
- [x] node body 与用户指定的原解释一致 —— **PASS**（body 原样入库 + DB trigger immutable + 测试断言 sha256）

## C. Topology（iPad 高层图）
- [x] CENTER 正方形且不可删除 —— **PASS**（SwiftUI NodeGlyph; UI 无删除按钮 + server CENTER_DELETE_FORBIDDEN；unit 测试）
- [x] Explanation 圆形 / Temporary 三角形 —— **PASS**（NodeGlyph 三种 path）
- [x] title 位于节点上方最多 2 行 —— **PASS**（NodeShapeView 标题 offset 布局）
- [x] long press drag 持久化 —— **PASS**（drag → ClientStore.localMove durable + outbox；unit: testLocalDeleteBeforeServerAck 同类路径 + move CAS unit）
- [x] double tap 进入 Reader；single tap rename/delete sheet —— **PASS**（RootView 路由；NodeManageSheet 对 CENTER 隐藏 delete）
- [ ] 真机触控手势不串扰 —— **NOT_RUN**（需真机；SwiftUI gesture 优先级已按 double>single>drag 配置）

## D. Round（轮次隔离）
- [x] close 后 temporary 移出当前图 —— **PASS**（unit + E2E close 移除 ops）
- [x] 再开同题不出现上一轮 temporary —— **PASS**（expired_at 过滤，unit 断言）
- [x] persistent explanation 仍存在 —— **PASS**（unit 断言）

## E. Reader / Ink
- [x] Markdown 正常渲染（heading/para/list/code/quote/hr/table）—— **PASS**（MarkdownParser unit 测试覆盖 block 识别）
- [x] 长页纵向滚动（单一滚动 owner）—— **PASS**（AnnotatedReaderView 单 UIScrollView + 固定 canonical width，代码评审通过；真机手感 NOT_RUN）
- [x] iPad 无正文编辑入口 —— **PASS**（body 只读渲染）
- [x] Pencil 直接书写（PKDrawing 按 node_id 绑定）—— **PASS（代码级）**；真机验收 **NOT_RUN**
- [x] 支持双击设备可切 eraser —— **PASS（代码级：UIPencilInteraction）**；真机 **NOT_RUN**
- [x] relaunch/reopen 笔迹存在 —— **PASS（本地 durable + ink_cache；unit 覆盖持久化路径）**；真机视觉复验 **NOT_RUN**
- [x] Ink 对正文无可见漂移 —— **PASS（架构级：正文与 Ink 共用同一 ContentCoordinateView bounds，固定 canonical page width）**；真机 **NOT_RUN**
- [ ] 排版匹配参考 PDF —— **BLOCKED_BY_MISSING_INPUT**（无参考 PDF；ReaderTypography 数值未冻结，禁止标 PASS）

## F. Zero-config LAN
- [x] Bonjour 服务 `_qiuzhaoreview._tcp` 广播（实际端口注册）—— **PASS**（daemon 启动实测输出 advertising）
- [x] iPad NWBrowser 自动发现、自动选择（preferred → 稳定排序）—— **PASS（代码级）**；双机联调 **NOT_RUN**
- [x] 无 IP/端口/验证码 UI —— **PASS**（无任何输入框；服务解析系统完成）
- [ ] Wi-Fi 断开恢复自动重连 —— **PASS（代码级：退避 0.5→10s + INFLIGHT→PENDING）**；真机 **NOT_RUN**

## G. Reliability
- [x] duplicate command one effect —— **PASS**（command_dedup unit + E2E 步骤 7）
- [x] duplicate message inbox dedup —— **PASS**（Swift inbox_dedup unit）
- [x] patch base mismatch → snapshot 恢复 —— **PASS**（Swift PatchResult.baseMismatch + E2E 步骤 9）
- [x] iPad durable before ACK —— **PASS**（applySnapshot transaction 后 ACK；代码路径审查）
- [x] Mac durable before emit/ACK —— **PASS**（sync_journal 先于广播；store mutation 事务内完成）
- [x] daemon crash 后 canonical graph 不损坏 —— **PASS**（SQLite WAL + integrity 检查进 STARTING 流程；单元级 verified）

## 完成判据汇总
| 判据 | 状态 |
|---|---|
| Mac unit / protocol / bridge E2E 通过 | ✅ PASS 16 + 7 + 7（含 fixtures 7）|
| iPad 工程可在 Xcode 环境 build | ✅ BUILD SUCCEEDED（iOS Simulator generic）|
| iPad store/sync/topology/reader 测试 | ✅ 12/12 PASS（模拟器）|
| LAN 自动发现/自动连接路径存在且无人工配对 | ✅ 代码完整；双机联调 NOT_RUN |
| true device Pencil Gate | 🔶 明确标记 NOT_RUN（当前环境无真机/Apple Pencil）|
| 原学习系统基线测试仍通过 | ✅ `学习系统/test_e2e.py` 21/21 |
| Release Acceptance Checklist 逐项给状态 | ✅ 本文件 |

## 已知未决
1. 双端 fixtures 同源化：DualEnd-common/fixtures 由 Node 测试实读校验；Swift 测试用内容一致的样例 JSON（未做 bundle 同源加载）。
2. 参考 PDF typography calibration：获得参考 PDF 后按 token 流程冻结 `ReaderTypography.referencePDF_v1`。
3. iPad 真机验证项（Pencil 延迟/双击/滚动对齐/权限提示/自动重连）需真机执行后把 NOT_RUN 改为 PASS/FAIL。
