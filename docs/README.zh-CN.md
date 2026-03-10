# OpenClaw Gateway 外部自动恢复参考实现

这是一个从真实生产落地中提炼出来的、**脱敏后的参考项目**。

它展示的是：如何给本地 OpenClaw Gateway 增加一层**外部自动恢复机制**，而不是把恢复逻辑硬塞进主服务入口里。

## 这个项目解决什么问题
目标不是让 Gateway 永远不出错。
目标是让它在**可恢复故障**下具备这些能力：
- 自动检测
- 自动恢复
- 冷却与尝试次数治理
- 结果落盘与日志审计
- 与主 Gateway LaunchAgent 解耦

## 核心思路
- 主 Gateway 继续由自己的 LaunchAgent 管理
- 单独增加一个 watcher LaunchAgent
- watcher 周期性做健康检查
- 如果发现异常，就调用 one-shot recovery
- recovery core 决定：
  - no-op
  - restart
  - escalate
  - governed skip

## 为什么强调“外部”
因为把恢复逻辑直接塞进主服务入口，通常会让问题更难定位，回滚更难做，服务链也更容易互相污染。

这个项目选择：
- **主服务继续是主服务**
- **恢复层只是恢复层**

这样故障边界更清楚，运维也更稳。

## 关键经验
### 1. 健康判定不要盲信 noisy probe
这里采用的是更保守的主判定：
- `openclaw gateway status --no-probe --json`
- `service.loaded == true`
- `service.runtime.status == "running"`
- `service.configAudit.ok == true`
- `extraServices == []`
- listener PID 与 runtime PID 一致

### 2. 真正的坑常在 launchd 边界
在真实生产 drill 中暴露出的关键 bug 是：
- 当主 Gateway service 已经从 launchd 被 bootout 后
- 单纯执行 `openclaw gateway start` 不够
- restart wrapper 必须能 bootstrap 已存在的 plist

这类问题如果不做真实演练，纸面上很容易看不出来。

## 仓库内容
- `recovery/gateway-v04/`：参考实现脚本
- `docs/RUNBOOK.md`：总览
- `docs/OPERATIONS.md`：运维 SOP
- `docs/POST_UPGRADE_CHECKLIST.md`：升级后兼容检查
- `docs/PRODUCTION_CASE_STUDY.md`：脱敏后的生产案例
- `docs/ARCHITECTURE.md`：架构说明

## 适合谁看
- 想给 OpenClaw Gateway 增加外部恢复层的人
- 想做 launchd + shell + watcher 风格自治恢复的人
- 想看一个“真实修过坑”的参考实现的人

## 不包含什么
这个仓库**不包含**：
- 私有配置
- token / auth 信息
- 原始生产日志
- 宿主机特定的内部环境细节

## 一句话
这不是“永不故障”的项目。
这是一个让系统在摔倒后，**更有机会自己爬起来，而且留下案发记录**的项目。
