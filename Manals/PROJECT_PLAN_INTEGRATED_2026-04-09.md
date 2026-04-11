# WarGuang 整合开发规划（持续更新）

## 0. 当前状态快照
- JumpBox 已进入分层结构：`BaseJumpBox` + `JumpBox` + `ChallengeJumpBox` + `MovingJumpBox` + `ChallengeMoveJumpBox` + `OneShotJumpBox`。
- Player 已进入后期拆分：核心状态机仍在 `Player.gd`，运行流/计时/滑翔/相机桥接/门传送/伤害链路已下沉到服务层。
- 完美/普通触发与残影分流已建立，后续可按类型覆盖触发效果。

## 1. 已确认的 JumpBox 规则（最新）
### 1.1 基类职责（BaseJumpBox）
- 提供共用触发骨架：玩家重叠检测、普通/完美分级、通用反馈入口。
- 通用反馈只保留：
  - 残影类型已在 Player 端区分（normal/perfect）
  - 通用触发音效预留（normal/perfect）
  - 白闪窗口（可开关）
- 不在基类内做速度增益和相机抖动分层。

### 1.2 类型效果定义
- `OneShotJumpBox` / `JumpBox` / `ChallengeJumpBox`
  - 普通触发：无额外效果
  - 完美触发：`vertical_force` 翻倍
- `MovingJumpBox` / `ChallengeMoveJumpBox`
  - 普通触发：`jump2_horizontal_boost` +50%
  - 完美触发：在 +50% 基础上，`jump2_boost_duration` 额外翻倍

### 1.3 覆盖能力（可扩展）
- 通过重写 `_apply_trigger_effect(player, trigger_grade)` 即可实现各类型独立触发效果。
- 通过 Player 的 `effect_overrides` 通道可按触发传入临时参数，不污染全局导出值。

## 2. Player 拆分进度与收口目标
### 2.1 已落地服务域
- 运行流与计时：`PlayerRuntimeFlowService`、`PlayerRuntimeTickService`
- 空中/滑翔：`PlayerAirStateService`、`PlayerAirAbilityService`、`PlayerAirMotionService`、`PlayerGlideStateService`
- 伤害与传送：`PlayerDamageService`、`PlayerDamageStateService`、`PlayerDamageFlowService`、`PlayerWarpFlowService`、`PlayerWarpFlightService`、`PlayerWarpResetService`
- 交互与控制：`PlayerControlLockService`、`PlayerDialogueStateService`、`PlayerDoorTraversalService`
- 相机与调试：`PlayerCameraBridgeService`、`PlayerRoomTransitionService`、`PlayerCameraDebugService`

### 2.2 仍需收敛的部分
- Door 传送入口参数构建与调用组织（继续下沉到 DoorTraversalService）。
- `_physics_process` 余下输入/后置阶段进一步收敛到 RuntimeFlowService。

### 2.3 拆分完成判据
- `Player.gd` 仅保留：节点引用、导出参数、状态分发、服务编排入口。
- 业务逻辑（状态细节、流程步骤、计时更新）不再直接驻留 `Player.gd`。
- 服务文件按“职责域”组织，避免过碎小文件泛滥。

## 3. 特效系统实施方案（先设计，不改代码）
## 3.1 触发模式（常规预设）
- 多数动作采用“一次触发即播放一次”模式：
  - 奔跑尘土（步频触发）
  - 一段跳起跳
  - 二段跳爆发
  - 普通冲刺 / 暗影冲刺起始帧
  - 落地冲击
  - 普通受击 / 重击
  - 攀墙附着
  - 墙跳离墙

## 3.2 位置预设
- 起跳/二段跳：玩家脚底或髋部偏下
- 冲刺：角色中心略后方（按朝向偏移）
- 落地：脚底中心
- 受击：受击点（没有受击点时使用角色中心）
- 攀墙/墙跳：贴墙侧边

## 3.3 方向预设
- 优先取角色朝向（`is_facing_right`）
- 次级取速度方向（冲刺/位移特效）
- 墙相关取墙法线方向

## 3.4 你需要准备的资源信息
- 每个特效提供：
  - 贴图/序列帧
  - 锚点（Pivot）
  - 默认缩放
  - 是否循环
  - 默认生命周期
  - 是否受朝向翻转影响

## 4. 中长期功能路线（按你给的顺序）
1. 继续 JumpBox 类型开发
2. 容器宠物 + NPC + 一次性 JumpBox 投放机制
3. 开场动画
4. 事件动画
5. 敌怪/Boss 接入
6. 角色事件扩展
7. 地图系统
8. 结局系统

## 5. 风险与建议
- 触发视觉白闪目前是 `modulate` 快闪，后续可升级为统一 Shader 命中闪。
- ChallengeConfig 历史资源若仍含旧字段（cooldown/jump_force），需要逐步清理资源文件以减少混淆。
- `ChallengeMoveJumpBox` 当前有自定义 `_process`，后续建议改成 `_update_custom` 风格，与基类流程统一。

## 6. 文档维护约定
- 本文档保持“通用方向 + 当前阶段状态”，避免记录过细实现细节。
- 具体拆分步骤、每轮变更与短期待办写入 `PLAYER_SPLIT_PLAN.md`。
- 每完成一个职责域拆分，至少同步一次“已落地服务域”和“剩余收敛项”。
