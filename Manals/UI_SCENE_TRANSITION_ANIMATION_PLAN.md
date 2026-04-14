# UI 场景背景动画与切场动画方案（可执行版）

## 目标

- 统一 UI 场景切换体验，避免快切导致黑屏流程跳过。
- 所有 UI 场景支持低成本循环背景动画。
- 每次切场都支持：先播退出动画，再黑屏切场，再播进入动画。
- Door 与死亡流程保持现状，不纳入本方案改造。

---

## A. 已落地的切场底座（当前代码状态）

当前已在 `SceneManager` + `FadeManager` 完成：

1. 两套 UI 切场参数（仅这两类）
- 普通 UI 场景切换：
  - `ui_switch_fade_out_duration`
  - `ui_switch_black_hold_duration`
  - `ui_switch_fade_in_duration`
- SaveSelect -> Game：
  - `ui_save_to_game_fade_out_duration`
  - `ui_save_to_game_black_hold_duration`
  - `ui_save_to_game_fade_in_duration`

2. 全局切场锁
- `scene_switch_lock_duration`（默认 0.2 秒）
- 切场请求在“进行中”或“锁定窗口”内会被拒绝，避免重入导致流程错乱。

3. 非切场 UI 过渡参数
- `ui_overlay_fade_duration`
- `ui_overlay_fast_fade_duration`

---

## B. UI 背景循环动画实现方案（性能优先）

### 推荐方案：双层视差 + Shader UV 滚动（首选）

结构：
- 在每个 UI 场景根节点下加 `BackgroundRoot`。
- `BackgroundRoot` 内两层：
  - `BGFar`（低速）
  - `BGNear`（中速）
- 两层都用同一张可平铺纹理（或两张风格一致纹理），通过 Shader 做 UV 滚动。

为什么性能好：
- 不需要每帧改大量节点属性。
- 主要消耗在 GPU 纹理采样，CPU 开销很低。
- 只要纹理尺寸控制合理，移动端和低端机也稳定。

建议参数：
- `BGFar` 速度：`Vector2(0.004, 0.0)`
- `BGNear` 速度：`Vector2(0.012, 0.0)`
- 透明叠加强度：`0.15 ~ 0.35`

素材要求：
- 使用可无缝平铺纹理（Tileable）。
- 建议单层纹理不超过 `1024x1024`，优先压缩格式。

### 备选方案：AnimatedSprite2D / SpriteFrames 帧动画

适合：
- 你有现成逐帧美术序列。

注意：
- 帧动画显存占用更高。
- 建议控制帧数（例如 8~16 帧循环）。

### 不推荐方案：大量 Tween 同时驱动多节点

原因：
- 节点多时 CPU 调度成本明显上涨。
- 长时间运行容易出现不稳定抖动。

---

## C. 切场“退出动画 -> 黑屏转场 -> 进入动画”流程设计

目标流程：
1. 点击切场按钮。
2. 播放当前场景退出动画（UI 元素离场）。
3. 调用 SceneManager 切场（黑屏淡出 + 黑屏停留 + 新场景淡入）。
4. 新场景 `_ready` 后自动播放进入动画（UI 元素入场）。

### 架构建议（最稳）

新增一个轻量脚本：`UITransitionAnimator.gd`（可挂在每个 UI 场景）
- `play_enter_animation()`
- `play_exit_animation()`

约定：
- 每个 UI 场景如果存在该节点，切场前先 `await play_exit_animation()`。
- 场景加载后在 `_ready()` 里调用 `play_enter_animation()`。

这样 SceneManager 仍只负责“黑屏切场”，动画职责留在 UI 场景本地，耦合最低。

### 推荐时序（默认）

普通 UI 切场：
- 退出动画：`0.18s`
- 黑屏淡出：`FadeManager.ui_switch_fade_out_duration`
- 黑屏保持：`FadeManager.ui_switch_black_hold_duration`
- 黑屏淡入：`FadeManager.ui_switch_fade_in_duration`
- 进入动画：`0.2s`

SaveSelect -> Game：
- 退出动画：`0.15s`（可更短）
- 黑屏淡出：`FadeManager.ui_save_to_game_fade_out_duration`
- 黑屏保持：`FadeManager.ui_save_to_game_black_hold_duration`
- 黑屏淡入：`FadeManager.ui_save_to_game_fade_in_duration`
- 进入动画：由 MainGameScene 或 PlayerUI 自行决定

---

## D. 素材准备清单（你可直接按这个给美术）

1. 背景循环素材
- `bg_ui_far_tile.png`
- `bg_ui_near_tile.png`
- 要求：可平铺、风格统一、亮度不要抢 UI 主元素。

2. 进入/退出动画素材（可选）
- 方案 1：纯程序动画（推荐）
  - 不需要额外素材，靠位置/透明度/Tween 实现。
- 方案 2：遮罩序列动画
  - `ui_transition_mask_01..N`
  - 用于更强烈的仪式感转场。

3. 音频素材（可选）
- `ui_scene_out.wav`
- `ui_scene_in.wav`

---

## E. 性能与稳定性注意事项

1. 不要在每个 UI 场景都创建复杂粒子系统做背景。
2. 背景动画总节点数尽量控制（建议 < 10 个核心动画节点）。
3. 退出动画必须可中断（用户连按时不应卡死流程）。
4. SceneManager 切场锁不要改成 0，否则容易回到重入问题。
5. 保持“切场逻辑唯一入口”原则，继续只通过 SceneManager 切场。

---

## F. 下一步执行建议

1. 先做一套 UI 场景动画模板（TitleScene 先行）。
2. 确认素材风格后复制到 SaveSelect 和 Settings。
3. 再把 GameSettingScene 加入同一套动画规则。
4. 最后统一微调 FadeManager 参数，完成全局观感校准。
