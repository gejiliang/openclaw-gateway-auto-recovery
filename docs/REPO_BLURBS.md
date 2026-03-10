# Repo blurbs

## English — short
External auto-recovery reference for local OpenClaw Gateway: conservative health checks, separate watcher loop, restart governance, and day-2 operations docs.

## English — medium
A sanitized reference implementation of an external auto-recovery layer for a local OpenClaw Gateway. It keeps recovery logic separate from the main Gateway LaunchAgent and focuses on practical reliability: conservative health truth, watcher-driven one-shot recovery, restart governance, production-tested launchd edge handling, and clear operations documentation.

## English — long
OpenClaw Gateway External Auto-Recovery is a sanitized public reference extracted from a real production rollout. The project demonstrates how to build an external recovery layer around a local OpenClaw Gateway without patching OpenClaw itself or merging recovery logic into the main service chain. It includes a periodic watcher, a one-shot recovery core, conservative health checks based on `status --no-probe --json`, cooldown and rolling attempt governance, production-tested launchd wrapper behavior, and supporting runbook / operations / post-upgrade documentation.

## 中文 — 短版
一个面向本地 OpenClaw Gateway 的外部自动恢复参考实现：保守健康检查、独立 watcher、重启治理，以及可落地的运维文档。

## 中文 — 中版
这是一个从真实生产落地中提炼出来的、脱敏后的 OpenClaw Gateway 外部自动恢复参考实现。它把恢复逻辑保持在主 Gateway LaunchAgent 之外，重点解决实际可靠性问题：保守健康判定、watcher 驱动的 one-shot recovery、冷却与尝试次数治理、真实 launchd 边界处理，以及面向 day-2 的运维文档。

## 中文 — 长版
OpenClaw Gateway External Auto-Recovery 是一个从真实生产 rollout 中提炼出来的公开参考项目。它展示了如何在不修改 OpenClaw 本体、也不把恢复逻辑塞进主服务链的前提下，为本地 OpenClaw Gateway 增加一层外部自动恢复能力。仓库包含周期性 watcher、one-shot recovery core、基于 `status --no-probe --json` 的保守健康判定、冷却与滚动尝试治理、经过真实生产 drill 验证的 launchd wrapper 处理，以及配套的 runbook / operations / 升级检查文档。

## Suggested GitHub About text
External auto-recovery reference for local OpenClaw Gateway: health checks, watcher loop, restart governance, and operations docs.

## Suggested social post one-liner
Built and open-sourced a production-tested external auto-recovery layer for local OpenClaw Gateway — separate watcher, conservative health truth, launchd-safe restart path, and ops docs included.
