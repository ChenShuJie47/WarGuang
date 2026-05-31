# 场景层级基线（2026-04-19）

## 目标
统一记录当前项目中已显式设置的 `CanvasLayer.layer` 与 `Node2D/TileMapLayer.z_index`，避免后续继续出现 10 / 95 / 1000 / 1105 等“只知其值不知其意”的维护风险。

## 当前可见关键层级（运行链路）
- Room 地图层（TileMapLayer）: z_index = 10
  - Room1 / Room2 / Room3 / RoomDream10
- Player（主场景实例）: 默认 z_index = 0（未显式设置）
- DarkOverlay: layer = 95
- 对话气泡（MyBalloon）: 场景配置 layer = 100（脚本在运行中会在 0 与 90 间切换）
- FadeManager: layer = 1000
- VignetteEffect: layer = 1000
- BootCinematicDirector: layer = 1105

## 当前可见关键层级（UI）
- DeleteConfirmDialog: layer = 50
- ChallengeCounter: layer = 50
- SettingsScene / GameSettingScene 脚本: layer = 100

## 风险评估
- 风险1: 同一视觉用途出现多层级来源（场景写死 + 脚本运行时覆盖）
- 风险2: 无统一层级字典，新增功能易“临时挑数值”
- 风险3: 游戏内演出层（1000+）与功能 UI（50~100）缺乏标准分段定义

## 建议落地顺序（推荐）
1. 先文档治理：在本文件固化层级字典与命名规范（最低风险、可立刻执行）。
2. 再代码治理：新增 `LayerProfile` 常量脚本，所有 layer/z_index 从常量读取，不再散落 magic number。
3. 最后改造暗化：基于字典分层实现“仅暗背景，不暗 player”。

## 建议层级分段（草案）
- 0~49: 世界实体（Player / NPC / 可交互）
- 50~149: 常规 UI 与对话
- 900~999: 场景特效遮罩（如 DarkOverlay）
- 1000~1099: 全局转场黑幕（FadeManager / Vignette）
- 1100+: 开场/事件强制接管层（BootCinematicDirector）

## 执行说明
- 本文件为“基线记录”，不等于自动修复。
- 任何改动前先更新本文件，再改脚本与场景，避免层级漂移。
