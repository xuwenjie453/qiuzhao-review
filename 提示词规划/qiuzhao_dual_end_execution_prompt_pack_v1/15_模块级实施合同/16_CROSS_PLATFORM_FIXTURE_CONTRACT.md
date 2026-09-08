# 跨端 Fixture 合同

建议仓库单一 source：
`DualEnd-Mac/fixtures/protocol-v1/`

Swift test target 可以通过：
- build phase copy；
- symlink（若 Xcode/Git 可靠）；
- generated resource copy script；
使用同一 JSON 内容。

fixture 类别：
- valid hello/welcome；
- graph snapshot；
- add/update/remove patch；
- rename/move/delete client command；
- ink metadata；
- ack/reject；
- unsupported version；
- malformed revision；
- oversize metadata test descriptor。

任何协议 PR 未更新 fixture 就不允许合并。
