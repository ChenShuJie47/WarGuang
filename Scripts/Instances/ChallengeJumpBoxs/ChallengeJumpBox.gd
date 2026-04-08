extends Area2D
class_name ChallengeJumpBox

## ============================================
## 基础挑战 JumpBox - 所有变体的基类
## ============================================

## 弹跳设置
@export_category("弹跳设置")
## 垂直向上的力大小
@export var vertical_force: float = 500.0

# 节点引用
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

# 状态变量
var is_active: bool = false  # 修改：初始为 false，等 START 动画播完才激活
var challenge_id: String = ""  # 所属挑战 ID
var challenge_stage: int = 1  # 挑战阶段（1=第一阶段，2=第二阶段...）

# 动画状态
enum AnimState { START, FLY, END, NONE }
var current_anim_state: AnimState = AnimState.NONE

## 信号
signal bounce_triggered(player)  # 被玩家触发时发出

func _ready():
	# 连接信号
	if body_entered.is_connected(_on_body_entered) == false:
		body_entered.connect(_on_body_entered)
	
	# 开始播放 START 动画
	play_start_animation()

## 播放 START 动画（生成时）
func play_start_animation():
	if not animated_sprite or not animated_sprite.sprite_frames:
		return
	
	if animated_sprite.sprite_frames.has_animation("START"):
		animated_sprite.play("START")
		await animated_sprite.animation_finished
		
		current_anim_state = AnimState.FLY
		_switch_to_fly_animation()
		
		# 修复：START 动画播完后才激活
		is_active = true

## 切换到 FLY 动画（循环）
func _switch_to_fly_animation():
	if animated_sprite.sprite_frames.has_animation("FLY"):
		animated_sprite.play("FLY")

## 身体进入处理
func _on_body_entered(body):
	if not is_active or current_anim_state != AnimState.FLY:
		return
	
	if body.is_in_group("player"):
		# 排除冲刺状态
		if body.current_state == body.PlayerState.DASH:
			return
		
		# 简单条件：只要在 JUMP2 动画状态就可以触发
		if body.current_animation == "JUMP2":
			trigger_bounce(body)

## 触发弹跳（子类可以覆盖此方法添加额外逻辑）
func trigger_bounce(player):
	# 额外的安全检查
	if not is_active or not player:
		return

	# 防止边界帧重复触发导致受力叠加
	if player.has_method("can_accept_jumpbox_bounce") and not player.can_accept_jumpbox_bounce():
		return
		
	# 确保玩家仍然在正确状态
	if not player.has_double_jumped or player.current_animation != "JUMP2":
		return
	
	# 发出信号
	bounce_triggered.emit(player)
	
	# 调用玩家的函数
	if player.has_method("start_jumpbox_bounce"):
		player.start_jumpbox_bounce(vertical_force)
	
	# Hit Stop 和相机抖动
	player.start_jumpbox_hit_stop()
	get_tree().create_timer(0.06).timeout.connect(func():
		CameraShakeManager.shake("y_weak", player.phantom_camera)
	)
	
	# 修复：立即禁用弹跳方块（由挑战控制器管理重生）
	set_inactive()
	

## 设置为失活状态
func set_inactive():
	is_active = false
	if collision_shape:
		collision_shape.set_deferred("disabled", true)

## 设置为激活状态
func set_active():
	is_active = true
	if collision_shape:
		collision_shape.set_deferred("disabled", false)

## 重新激活（用于冷却后重生）
func reactivate():
	set_active()
	animated_sprite.visible = true
	play_start_animation()

## 强制隐藏（不播放 END 动画）
func force_hide():
	set_inactive()
	animated_sprite.visible = false

## 获取当前状态（供子类访问）
func get_current_state() -> Dictionary:
	return {
		"is_active": is_active,
		"challenge_id": challenge_id,
		"challenge_stage": challenge_stage,
		"current_anim_state": current_anim_state
	}

## 播放 END 动画（挑战结束时调用）
func play_end_animation():
	if not animated_sprite or not animated_sprite.sprite_frames:
		return
	
	if animated_sprite.sprite_frames.has_animation("END"):
		animated_sprite.play("END")
		current_anim_state = AnimState.END
