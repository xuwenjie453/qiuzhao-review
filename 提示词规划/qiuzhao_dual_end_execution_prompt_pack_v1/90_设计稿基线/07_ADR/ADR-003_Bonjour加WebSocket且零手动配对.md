# ADR-003：Bonjour + WebSocket，零手动配对

Status: Accepted

## Context

reading-system 已证明 Bonjour + WebSocket 适合 Mac/iPad LAN 同步，但其 6 位码配对与本项目需求冲突。

## Decision

保留 discovery/transport，删除用户配对步骤；首次连接自动 TOFU。

## Consequence

满足零配置体验；v1 安全边界限定为个人可信 LAN，不能宣称 hostile-LAN 强认证。
