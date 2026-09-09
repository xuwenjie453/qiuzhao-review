# 最终代码审查与交付提示词

请在所有实现完成后做一次独立审查，不要只看编译结果。

## 审查清单

### 问题图

- 是否只有一个 normalized/local 坐标转换来源；
- 图布 frame 是否明确；
- visual/hit/title frame 是否分离；
- drag 是否使用固定起点或绝对触点；
- drag 中是否关闭位置插值；
- background 手势是否吞节点事件；
- pending/canonical/dragging 是否分离；
- 旧 ACK 是否可能覆盖新拖动；
- CAS mismatch 是否可恢复；
- 连线是否跟随 effective position。

### Reader

- 页面是否真正是 A4 canonical page；
- 横屏是否按整页缩放并居中；
- 页面内留白是否属于 Canvas；
- 页面外 gutter 是否明确不可写；
- 文字和 Canvas 是否同一 PageView 坐标；
- 是否仍有第二个 scroll owner；
- PKCanvasView 的内部 offset/zoom 是否固定；
- typography 是否有 signature；
- 旧 ink 是否兼容；
- body 是否仍 immutable。

### 范围和安全

- 是否修改了学习核心或正式题库；
- 是否产生未授权数据库写入；
- 是否删除用户已有未提交修改；
- 是否存在强制 unwrap、主线程重 I/O、静默 catch；
- 是否把未执行的真机测试写成 PASS。

## 必跑命令

根据项目实际配置运行：

```bash
git diff --check
python3 学习系统/cli.py integrity
xcodebuild -project DualEnd-iPad/QiuZhaoReader.xcodeproj \
  -scheme QiuZhaoReader \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' test \
  CODE_SIGNING_ALLOWED=NO
```

再根据用户设备执行真机 build/install/launch，并记录完整证据。

## 交付报告

报告必须包含：

- 修改文件及原因；
- 问题一和问题二分别解决了什么；
- 自动测试结果；
- PDF 视觉对比结果；
- 真机 Pencil Gate 结果；
- 未完成项和阻塞原因；
- 回滚边界；
- 用户下一步测试步骤。

只有所有必需 Gate 真实通过，才能写“完成”；否则逐项标记 PASS、FAIL 或 BLOCKED。

