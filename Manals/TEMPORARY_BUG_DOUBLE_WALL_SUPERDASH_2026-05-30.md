# 临时搁置问题记录：双墙误挂与超级冲刺异常

更新时间：2026-05-30

本文件用于记录当前暂时不继续修复、但后续仍可能回头处理的问题。目标不是给出“现成解法”，而是把现象、涉及逻辑、已尝试方案和失败原因完整保留下来，方便之后快速恢复上下文。

## 1. 双墙误挂问题（已修复）

### 现象
- 在两面相对很近的墙之间，玩家从墙 A 墙跳后，有时会误挂到墙 B。
- 误挂后，攀墙动作方向可能反过来，表现为面朝和滑墙方向与预期相反。
- 该问题在近期修改后感知上有所减少，但仍然会在部分窄缝场景触发。

### 当前理解
- 这个问题的根因是：`wall_direction` 曾在墙跳过程中被混用成“锁定墙方向”，而不是“当前真实接触墙方向”。
- 当玩家从墙 A 墙跳后，若仍按住向墙 A 的方向键并进入墙跳后的重新附着阶段，系统可能会把旧锁定方向当成当前墙面方向，导致误挂到另一侧墙时方向也跟着错位。
- 当前修复后，`wall_direction` 只表示射线当前命中的真实墙面；`wall_grip_direction` 只保留“这次墙跳/攀墙的锁定墙面”用途。

### 相关逻辑位置
- [Scripts/Player/PlayerMovementService.gd](../Scripts/Player/PlayerMovementService.gd)
- [Scripts/Player/PlayerAirAbilityService.gd](../Scripts/Player/PlayerAirAbilityService.gd)
- [Scripts/Player/PlayerStateFlowService.gd](../Scripts/Player/PlayerStateFlowService.gd)
- [Scripts/Player/PlayerRuntimeTickService.gd](../Scripts/Player/PlayerRuntimeTickService.gd)

### 已经尝试过的方法
- 引入墙跳逃逸缓冲，防止离墙后立刻再次挂墙。
- 为墙跳增加独立修正参数。
- 在空中挂墙入口里加入更强的条件限制。
- 把滑翔状态和普通空中状态统一接回空中挂墙入口。
- 最终修复：把 `wall_direction` 恢复为“真实射线检测结果”，让挂墙入口不再读取旧锁定值。

### 为什么这些方法仍不够
- 仅靠“限制更多”会误伤合法场景，比如两墙之间切换攀墙、滑翔状态下重新抓墙。
- 如果空中挂墙判定仍然优先读取旧锁定方向，而没有严格检查当前接触墙，就会继续出现“挂错墙”或“挂不上墙”的副作用。

### 后续如果要继续修，建议优先核对的方向
- 当前已不再建议继续扩大这部分逻辑；如果未来回归，优先核对墙跳离墙缓冲是否被其他新逻辑重写。

### 最新状态
- 该问题已修复并验证，不再保留为待处理缺陷。
- 当前链路中，`wall_direction` 只表示真实碰撞墙面，`wall_grip_direction` 只表示本次墙跳/攀墙锁定墙面，二者已分离。
- 进入空中重新附着时，系统只读取当前射线检测到的墙面，不再读取旧锁定方向作为当前墙面。

## 2. 超级冲刺异常（已修复）

### 现象
- 在超级冲刺加速时间和最大持续时间期间点击冲刺，结果有时会把冲刺方向固定成右边。
- 即使视觉动画仍然朝左，实际速度也可能朝右。
- 在超级冲刺减速期间，跳跃和冲刺都无法像一般空中状态那样正常处理。

### 当前理解
- 超级冲刺存在两个层面的问题：
  - 方向来源不一致，导致显示方向和实际速度方向脱节。
  - 减速阶段仍然被当作“特殊状态”，而不是当作普通空中状态。
- 当前更像是状态机里把“减速”理解成了一个封闭阶段，导致一般空中输入被吞掉。

### 相关逻辑位置
- [Scripts/Player/PlayerStateFlowService.gd](../Scripts/Player/PlayerStateFlowService.gd)
- [Scripts/Player/PlayerMovementService.gd](../Scripts/Player/PlayerMovementService.gd)
- [Scripts/Player/PlayerAnimationService.gd](../Scripts/Player/PlayerAnimationService.gd)
- [Scripts/Player/PlayerStateTransitionService.gd](../Scripts/Player/PlayerStateTransitionService.gd)

### 已经尝试过的方法
- 增加超级冲刺减速阶段。
- 用曲线方式让速度从快到慢衰减。
- 在减速期间允许 jump 进入普通空中逻辑。
- 增加 SUPERDASHEND 作为减速期间的独立结束动画。

### 目前可疑点
- DASH 方向的锁定可能仍然没有在 SUPERDASH -> DASH 的切换点上重新计算。
- 减速阶段的输入处理可能仍然和普通空中状态有分叉，而不是完全复用普通空中能力入口。
- 某些分支可能还在使用 `is_facing_right` 作为最终速度来源，但它并不一定等于当前冲刺期应该使用的方向。

### 未来如果重新修，建议顺序
1. 先把超级冲刺转普通冲刺的方向来源统一。
2. 再把减速阶段的 jump/dash 行为合并到普通空中判定。
3. 最后再加 SUPERDASHEND 的动画分层或更细的过渡。

### 最新状态
- 该问题已修复，当前不再作为待处理缺陷保留在修复计划中。
- 若后续回归再出现，优先复查 SUPERDASH -> DASH 的方向来源和减速阶段输入合并逻辑。

## 3. 备注

- 这个文档只记录“为什么现在暂时不继续追修”以及“后面回来时该从哪查起”。
- 不代表这些问题已经被彻底修好。
