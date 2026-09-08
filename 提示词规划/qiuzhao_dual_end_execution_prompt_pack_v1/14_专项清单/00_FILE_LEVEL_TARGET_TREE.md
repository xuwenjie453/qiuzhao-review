# 建议目标树（实施时按当前仓库校正）

```text
qiuzhao-review/
├── AGENTS.md
├── README.md
├── 学习系统/
│   └── lsys/dual_end_adapter.py          # 可选薄层
├── 提示词规划/...RuntimePrompt_V1/
│   └── 21_双端问题图与iPad协作协议.md
├── DualEnd-Mac/
│   ├── package.json
│   ├── bin/
│   ├── src/{control,graph,store,bridge,protocol,diagnostics}/
│   ├── fixtures/protocol-v1/
│   └── test/
├── DualEnd-iPad/
│   ├── QiuZhaoReader.xcodeproj
│   ├── QiuZhaoReader/
│   │   ├── App/
│   │   ├── Domain/
│   │   ├── Protocol/
│   │   ├── Connectivity/
│   │   ├── Sync/
│   │   ├── Store/
│   │   ├── Topology/
│   │   ├── Reader/
│   │   ├── Pencil/
│   │   └── Diagnostics/
│   ├── QiuZhaoReaderTests/
│   └── QiuZhaoReaderUITests/
└── 系统数据/dual-end/                    # runtime only, ignored
```

文件名可以按现有 repo 惯例调整；职责边界不能混。
