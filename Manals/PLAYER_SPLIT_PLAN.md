# Player 脚本拆分计划（持续更新）

## 目标
- 在不改变玩法表现的前提下，持续缩减 Player.gd 的单文件职责。
- 先稳定相机与伤害链路，再进行行为拆分，避免边拆边回归。

## 当前状态（2026-04-11）
- 已拆分：
  - PlayerDamageFlowService
  - PlayerDamageStateService
  - PlayerDamageService
  - PlayerDoorTraversalService
  - PlayerControlLockService（本轮新增）
  - PlayerPixelStabilityService（本轮新增，测试开关默认关闭）
  - PlayerWarpFlowService
  - PlayerWarpFlightService（本轮新增）
  - PlayerCameraDebugService（本轮新增）
  - PlayerWarpResetService（本轮新增）
  - PlayerRoomTransitionService（本轮新增）
- 已完成稳定性修复：
  - PhantomCamera2D 的 smooth_damp/interpolate 对 delta=0 与非有限值保护。
  - Warp 预追镜保留锚点 + 超时兜底（默认 6.0 秒，可调）。
  - 传送伤害流程已改为“受伤僵直后 JUMP2 飞行到检查点”，移除固定飞行时长与旧 warp 计时参数。

## 下一步拆分顺序
1. 对话/交互状态处理与控制锁统一到单一入口，继续减少 _physics_process 分支复杂度。
2. Camera 相关桥接函数继续收敛，Player.gd 仅保留必要门面。
3. Player.gd 仅保留状态机分发和关键节点引用。

## 每轮执行规则
- 每次只拆一块，拆完先跑脚本错误检查。
- 若出现相机/状态异常，优先修稳定性再继续拆分。
- 不做未被明确要求的额外模块改动。
