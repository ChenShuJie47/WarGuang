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
  - PlayerControlLockService
  - PlayerDialogueStateService
  - PlayerCameraBridgeService
  - PlayerGlideStateService
  - PlayerRuntimeTickService
  - PlayerRuntimeFlowService
  - PlayerWarpFlowService
  - PlayerWarpFlightService
  - PlayerCameraDebugService
  - PlayerWarpResetService
  - PlayerRoomTransitionService
- 已完成稳定性修复：
  - PhantomCamera2D 的 smooth_damp/interpolate 对 delta=0 与非有限值保护。
  - Warp 预追镜保留锚点 + 超时兜底（默认 6.0 秒，可调）。
  - 传送伤害流程已改为“受伤僵直后 JUMP2 飞行到检查点”，移除固定飞行时长与旧 warp 计时参数。
  - 滑翔流程改为：起始滞空（默认 0.2s）+ 下落倍率线性过渡；移除水平加速度过渡时间。
  - 滑翔起始滞空期间已改为不施加重力，避免出现缓慢下落。

## 模块粒度策略（维护视角）
- 优先按“职责域”拆分：输入流、运行流、伤害流、相机桥接、门传送流，而不是每个小函数单独成文件。
- 新增服务前先判断是否可并入现有域服务（例如 RuntimeFlow/RuntimeTick），避免出现大量 20~40 行孤立脚本。
- 允许少量薄门面服务存在，但同一域内薄门面数量超过 2 个时，优先合并。
- 拆分完成标准：Player.gd 保留状态分发、输入管线入口、节点/导出变量与少量桥接，不再承载具体业务细节。

## 本轮收敛调整
- 观察偏移与 dead zone 完整联动：观察时临时收窄 dead zone，回零完成后恢复并做一次安全同步，避免分段位移与回零残留。
- 观察回零收尾同步改为“单次触发”防抖，避免在目标为零时每帧重复同步导致移动时相机抖动。
- 观察偏移轨迹改为“Player 参考系绝对位移曲线”：进入观察时以 offset=0 为统一起点，偏移程度不再受当前相机位置影响。
- 观察流程新增“基准相机中心记录/回零恢复”：观察结束回零时恢复到观察前镜头基准，防止多次观察后镜头漂移到 dead zone 边缘。
- 回零段添加最小初始速度，缓解“边界处松键后恢复滞后”的停顿感。
- 观察基线策略更新为 `follow_offset` 基线：LOOKUP/LOOKDOWN 目标 = 基线偏移 + 观察偏移，回零目标 = 基线偏移；移除基于相机中心的硬矫正，降低边界处突兀跳变。
- 边界释放响应优化：回零段直接进入匀速段，避免松键后前几帧响应迟滞。
- 观察 dead zone 稳定性调整：观察期仅收窄垂直 dead zone，保持水平 dead zone 不变，降低回零后水平镜头漂移。
- SLEEP/INTERACTIVE 状态处理已下沉到 `PlayerSleepStateService`。
- HURT 状态处理已下沉到 `PlayerHurtStateService`，Player 主脚本保留状态分发。
- DIE 状态处理已下沉到 `PlayerDieStateService`。
- 特殊状态计时（IDLE->SLEEP/LOOKUP/LOOKDOWN）已下沉到 `PlayerSpecialStateTimerService`。
- 死亡异步流程与重生重置流程已下沉到 `PlayerDeathFlowService`。
- 受伤入口编排与传送后重置已下沉到 `PlayerDamageOrchestratorService`。
- 状态迁移副作用（change_state 出入场逻辑）已下沉到 `PlayerStateTransitionService`，Player 主脚本保留状态切换门面与事件派发。
- `PlayerDamageOrchestratorService` 的 `new_health` 已改为显式 `int`，避免类型推断报错。
- 观察回零阶段改为显式 `reset_phase` 判定，死区恢复不再依赖“有效目标是否为零”，修复基线回零路径下 dead zone 可能不恢复的问题。
- 动画更新主逻辑已下沉到 `PlayerAnimationService`，Player 仅保留调用入口。
- 奔跑输入判定与奔跑跳速度窗口已下沉到 `PlayerMovementService`（`detect_run_input`、`handle_run_jump`）。
- 相机观察回零新增“基准中心等待收敛”阶段（带超时），用于抑制多次 LOOKUP/LOOKDOWN 后镜头逐次偏移到死区边界的问题，同时保留 dead zone 恢复。
- 超级冲刺入口 `start_super_dash` 已下沉到 `PlayerMovementService`。

## 下一步拆分顺序
1. Door 传送入口与自动走位参数构建继续下沉到 DoorTraversalService。
2. 继续下沉状态域内长函数（优先 SLEEP/INTERACTIVE/HURT 相关分支），减少 Player.gd 的状态业务实现。
3. Player.gd 仅保留状态机分发和关键节点引用。

## 每轮执行规则
- 每次只拆一块，拆完先跑脚本错误检查。
- 若出现相机/状态异常，优先修稳定性再继续拆分。
- 不做未被明确要求的额外模块改动。
