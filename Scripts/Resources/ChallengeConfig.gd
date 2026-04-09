extends Resource
class_name ChallengeConfig

## 挑战配置资源
## 用于在 Inspector 中可视化配置挑战参数
## 每个挑战应该创建独立的 ChallengeConfig 资源

@export_group("挑战基础设置")

## 挑战名称（用于调试显示）
@export var challenge_name: String = "挑战 XXX"
## 挑战阶段 ID（推荐显式配置：1/2/3...；0=按 challenge_name 回退推断）
@export var stage_id: int = 0

## 需要触发的 JumpBox 总数量
@export var target_count: int = 12

@export_group("JumpBox 配置")

## ChallengeJumpBox 场景资源（预加载的弹跳箱场景）
@export var jumpbox_scene: PackedScene

@export_group("生成位置配置")

## 生成点数组（在编辑器中手动添加 Marker2D 节点）
## 数组大小决定循环模式（例如 3 个点会按 1→2→3→1→2→3 顺序生成）
@export var spawn_points: Array = []

@export_group("成功条件")

## 是否要求玩家全程不能落地（is_on_floor() = false）
@export var require_no_floor: bool = true

## 是否要求玩家不能离开挑战区域
@export var require_in_bounds: bool = true

@export_group("奖励设置")

## 挑战成功后的对话文件路径（例如："res://Assets/Dialogues/Reward.dialogue"）
@export var reward_dialogue_path: String = ""

## 挑战成功后解锁的能力名称（例如："black_dash"）
@export var unlock_ability: String = ""
