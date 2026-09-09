# Phase 2A：纯逻辑单元测试

保留既有全部测试（Store/Topology/GraphCodec/Reader viewport，含暂存版带来的 2 个 hover 数学模型测试），新增以下纯函数覆盖。不依赖实体 Pencil，模拟器可跑。

## 必须覆盖

1. **contentSize 单位约定**：`displayContentSize(documentSize:scale:)` == canonical × z（对 z=1.0 / 2.0 / 0.75 三档断言）——钉死 06 号缺陷 #1 不复发。
2. **镜像几何推导**：给定 (z, offset)，对多个 canonical 点 P 断言
   `documentLayerPosition(offset) + P 应用 documentLayerTransform(z) == P·z − offset`
   （即 `02` 不变量在镜像层上的实现）；z 变化、offset 变化各来一组。
3. **canonical ↔ display 往返**（已有，保留）：往返误差 < 1e-4。
4. **比例失配符号反转模型**（已有，保留）：作为根因的数学守卫——若有人把视口数学改坏使实时/提交基准再度分裂，此测试形态即文档。
5. **hitTest 换算基准**：bounds 系 point ÷ z 落在预期 canonical 页矩形内/外的判定（页内可写、页外 gutter 不可写、跨页间隙不可写）。
6. **fitWidthScale 钳位**：viewport 极小/极大时 clamp 到 [0.5, 3.0]。
7. **layoutSignature 稳定**：不含 zoomScale / 屏幕尺寸 / 方向因子；视口变化不改签名。
8. **数据不被动**：视口/镜像相关的纯函数输入输出均不含 PKDrawing（编译层保证视口操作不可能改写笔迹数据——如有任何函数同时触及两者即测试失败）。

## 命令与通过标准

```bash
xcodebuild -project DualEnd-iPad/QiuZhaoReader.xcodeproj -scheme QiuZhaoReader \
  -destination 'platform=iOS Simulator,name=iPad Air 11-inch (M4)' \
  -derivedDataPath DualEnd-iPad/build/DERIVED CODE_SIGNING_ALLOWED=NO test
```

- 既有 21 项 + 新增全部 PASS，0 failures。
- `git diff --check` 干净（无空白错误）。
- 模拟器不能验证真实 hover——不得用本阶段替代 Phase 3 真机 Gate。
