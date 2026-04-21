# 背景暗化但 Player 不变暗：实施方案（待确认后执行）

## 目标
- 慢动作防反期间：只暗化世界背景与场景元素。
- Player 本体、Player 残影、关键战斗反馈层不被暗化。
- 不破坏已有开场/转场黑幕链路（FadeManager 与 BootCinematicDirector）。

## 计划新增文件（待你确认后再创建）
1. Scripts/Managers/GameplayDarkenManager.gd
- 统一控制游戏内“局部暗化”（非转场黑幕）。
- 提供接口：start_world_darken(profile)、stop_world_darken()。
- 挂载在 MainGameScene 或作为 Autoload（二选一，建议先挂场景，风险更低）。

2. Scenes/Managers/GameplayDarkenOverlay.tscn
- 一个 CanvasLayer + ColorRect 覆盖层。
- 默认透明，按 profile 做 Tween 到目标 alpha。
- 层级建议 900~999（低于 FadeManager 1000，高于大多数世界元素）。

3. Scripts/Events/CounterSlowVisualBridge.gd
- 防反慢动作触发桥接层，只负责“进入/退出慢动作时通知 GameplayDarkenManager”。
- 不改伤害判定，不改输入，不改状态机。

## 核心逻辑
- Player 不变暗的关键不是“提高 player 的 z_index”，而是“暗化层放在世界渲染上方但放在 player 专属渲染下方”。
- 若当前项目无法稳定做到 player 专属渲染分离，则采用二选一策略：
  - 方案A：世界对象分组暗化（改材质参数），排除 player 组。
  - 方案B：双 viewport 合成（世界 viewport + player viewport），暗化只作用于世界 viewport。

## 推荐先落地路径（低风险）
1. 先实现 Overlay 方案并验证：不碰 FadeManager 与 Boot。
2. 如果发现 player 仍被暗化，再切换到“分组材质暗化”。
3. 只有前两种都不稳定时，才上双 viewport。

## 与现有层级的关系
- 不占用 1000+（避免和 FadeManager/Vignette 冲突）。
- 预留 900~999 给战斗期暗化与局部演出。
- 保持 Room TileMap z_index=10 与 Player 默认绘制关系不变。

## 验收标准
- 防反慢动作开始后 1 帧内进入暗化，结束后平滑恢复。
- Player 亮度与颜色不被压暗。
- 开场黑幕、房间切换黑幕、RoomDream10 事件不受影响。
- 暗化多次触发不叠层、不闪烁、不残留。