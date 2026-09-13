# Network Epoch 设计

## 目的

避免 suspend 前旧对象的迟到 callback 污染新恢复链。

## 建议字段

`networkEpoch: UInt64`

每次 full recovery：
- epoch += 1
- cancel reconnect timer
- stop old transport
- stop old browser
- clear candidate cache
- create browser(epoch)
- create transport(epoch)

所有 callback 捕获 `myEpoch`：

```swift
guard myEpoch == networkEpoch else { return }
```

## foreground 第一版策略

可靠性优先：
- scene background：结束当前 network epoch
- scene active：创建全新 epoch

后续稳定后再考虑短健康检查复用旧连接。
