# receiveLoop 正确性规范

## 必须理解 TCP 是 byte stream

HTTP 101 响应可能被拆成：

- 1 段
- 2 段
- 多段
- 与第一帧 WebSocket 数据粘在同一段

Transport 必须都正确。

## 循环条件

不是 `opened == true`。

而是：

`connection exists && !finished`

每次 completion：
1. append data
2. processBuffer
3. 若 EOF/error -> finish
4. 否则再次 receive

## 测试输入

将完整 101 header 按每个字节位置切分，至少随机测试几十种分割方式。
