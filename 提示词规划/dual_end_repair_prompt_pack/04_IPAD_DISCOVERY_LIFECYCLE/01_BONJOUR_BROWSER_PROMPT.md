# Prompt — BonjourBrowser 修复

## 保存原始 endpoint

不要只保存 service name 再重建 `.service(...)`。
保存 `NWBrowser.Result.endpoint`，candidate 结构至少含：
- name
- endpoint
- discoveredAt
- browserEpoch

## browser 状态

- ready：正常
- waiting：记录错误 + watchdog
- failed：fatal，销毁并重建
- cancelled：如果不是 owner 主动 stop，则按 stale/fatal 处理

## rebuild

必须：
1. 清 handlers
2. cancel old browser
3. browser=nil
4. clear candidates
5. increment browser generation
6. create new browser

旧 generation 的 results/callback 必须忽略。
