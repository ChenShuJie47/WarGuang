# 项目状态总览（2026-04-12）

## 1. 本轮已完成的关键优化

### 1.1 PlayerUI 迁移后的路径引用修正
已修正玩家 UI 相关场景路径常量，避免旧路径残留：
- `ScenePaths.PLAYER_UI`
- `ScenePaths.PLAYER_HEALTH_UNIT`

当前统一由目录常量拼接生成：
- `PLAYER_UI_DIR = "res://Scenes/Player/PlayerUI"`
- `PLAYER_UI = PLAYER_UI_DIR + "/PlayerUI.tscn"`
- `PLAYER_HEALTH_UNIT = PLAYER_UI_DIR + "/HealthUnit.tscn"`

这样后续如果 PlayerUI 目录再次调整，只需改一处目录常量。

### 1.2 UI 场景切换黑屏参数集中化（统一到 FadeManager）
已在 `FadeManager.gd` 增加统一可配置参数（@export）：
- `ui_fast_fade_duration = 0.1`
- `ui_fade_duration = 0.15`
- `ui_scene_switch_duration = 0.15`
- `ui_return_title_fade_duration = 0.25`
- `ui_to_game_fade_duration = 1.5`

并将以下脚本中的分散硬编码替换为上述常量：
- `TitleScene.gd`
- `SettingsScene.gd`
- `SaveSelectScene.gd`
- `GameSettingScene.gd`
- `SceneManager.gd`（部分调用）

### 1.3 相关顺手修正（安全项）
- `SaveSelectScene.gd` 中主场景路径由硬编码改为 `ScenePaths.GAME_MAIN`。
- `SaveSelectScene.gd` 返回标题路径由硬编码改为 `ScenePaths.UI_TITLE`。
- `SceneManager.gd` 中存档进游戏切场路径改为 `ScenePaths.GAME_MAIN`。
- `GameSettingScene.gd` 主菜单返回时移除了重复的二次切场调用（避免双切换/双过渡风险）。

---

## 2. 黑屏过渡参数目前都在哪里？

### 2.1 已统一到 FadeManager 的 UI 过渡参数
集中位置：`Scripts/Managers/FadeManager.gd`

### 2.2 仍保持业务侧独立的参数（正常且合理）
以下并非“UI 场景切换参数”，属于玩法/流程参数，建议保留在业务脚本：
- `Door.gd`
  - `fade_in_duration`
  - `black_screen_duration`
  - `fade_out_duration`
- `Player.gd`
  - `fade_transition_time`（死亡/重生流程使用）

说明：
- FadeManager 负责“怎么黑/怎么亮”（统一执行器）。
- Door/Player 等业务脚本负责“何时黑、黑多久”（流程策略）。

---

## 3. UI 场景黑屏过渡与死亡黑屏过渡：同一个还是分开？

结论：
- **执行器是同一个**：都调用 `FadeManager.fade_out()/fade_in()`。
- **流程控制是分开的**：触发时机和配套逻辑由不同系统控制。

### 3.1 UI 场景切换流程
- 主控：`SceneManager.switch_scene()` + 各 UI 场景脚本。
- 常见入口：`TitleScene.gd`、`SaveSelectScene.gd`、`SettingsScene.gd`、`GameSettingScene.gd`。
- 特点：围绕菜单跳转、UI 层级、BGM 切换。

### 3.2 角色死亡/重生黑屏流程
- 主控：`PlayerDeathFlowService.gd`。
- 特点：黑屏期间还要做玩家复位、房间与相机限制同步、重生状态恢复。
- 关联：`PlayerRoomTransitionService.gd`（黑屏窗口内相机/房间同步）。

所以是“同 Fade 执行层，分业务流程层”的架构。

---

## 4. 快速结构体检：可做且安全的优化建议

以下建议按“低风险高收益”排序：

1. 统一场景路径来源
- 原则：所有 `change_scene_to_file`/`switch_scene` 参数都走 `ScenePaths`。
- 收益：后续目录重构成本低，避免漏改。

2. 统一 Fade 调用语义
- 约定 UI、Door、Death 三类过渡使用不同常量命名分组（继续放在 FadeManager）。
- 收益：调参不再全局搜索 magic number。

3. 将“流程时长参数”与“效果执行器”分层
- 保持当前方向：FadeManager 不承载业务流程状态，仅承载黑屏能力和公共时长常量。
- 收益：避免单例过重。

4. 补一份“场景切换矩阵”文档
- 列出 `from -> to -> 负责人 -> fade 常量 -> BGM 策略`。
- 收益：联调和回归测试效率明显提升。

5. 建立轻量回归清单（手测 10 条）
- UI 首页 -> 读档 -> 游戏
- 游戏内菜单 -> 标题
- 死亡重生
- Door 传送
- 返回标题后二次进游戏
- 收益：每次改相机/切场可以快速兜底。

---

## 5. 下一阶段任务建议清单

1. 对全仓执行一次“场景路径硬编码扫尾”
- 目标：将剩余 `res://...tscn` 直写尽量收敛到 `ScenePaths`。

2. 建立 `TransitionProfile`（可选）
- 把 UI、Door、Death 常量分组成配置对象/资源，统一管理。

3. 补自动化验证（可选）
- 为关键流程加最小化日志断言：
  - 切场只触发一次
  - Fade out/in 成对出现
  - 相机限制在黑屏结束前已生效

4. 文档持续化
- 每完成一个大迭代（相机、UI、存档）更新本文件与对应专题文档。

---

## 6. 当前状态结论

- 相机模块问题：已稳定收敛。
- Player 脚本拆分工程：已达到可维护、可扩展状态。
- 本轮“收尾优化”已完成：
  - PlayerUI 新路径引用修正
  - UI 黑屏参数统一到 FadeManager
  - 关键硬编码路径替换
  - 文档更新完成
