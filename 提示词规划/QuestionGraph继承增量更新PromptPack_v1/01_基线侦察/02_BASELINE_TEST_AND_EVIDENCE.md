# Baseline Test & Evidence Prompt

在改代码前运行真实基线。不要把“代码看起来正确”当证据。

## 建议命令

根据仓库实际脚本调整，但至少覆盖：

```bash
cd DualEnd-Mac && node --test test/
python3 学习系统/test_e2e.py
xcodebuild -project DualEnd-iPad/QiuZhaoReader/QiuZhaoReader.xcodeproj -scheme QiuZhaoReader -destination 'generic/platform=iOS Simulator' build
```

若有明确 simulator test destination，再跑 iPad unit。

## 证据表

记录：

| subsystem | command | pass/fail | count | notes |
|---|---|---|---:|---|

已有失败必须标注 `PREEXISTING`。本次修改后新增失败标注 `REGRESSION`。

若某测试因缺少 Xcode/真机/网络环境不能运行，标记 `BLOCKED` 或 `NOT_RUN`，禁止写 PASS。
