extends Area2D

## 弹跳设置
@export_category("弹跳设置")
## 垂直向上的力大小
@export var vertical_force: float = 600.0

## 重生设置
@export_category("重生设置")
## 从隐藏到重新出现的时间（秒）
@export var respawn_time: float = 2.0

# 节点引用
@onready var animated_sprite = $AnimatedSprite2D
@onready var collision_shape = $CollisionShape2D

# 状态变量
var is_active: bool = true
var original_position: Vector2
var animation_finished_emitted: bool = false  # 标记动画是否已完成

func _ready():
	# 保存原始位置
	original_position = global_position
	
	# 连接信号
	body_entered.connect(_on_body_entered)
	
	# 开始播放 START 动画
	play_start_animation()

func play_start_animation():
	# 播放 START 动画，不循环
	animated_sprite.play("START")
	# 等待动画播放完成
	await animated_sprite.animation_finished
	# 切换到 FLY 动画，循环
	animated_sprite.play("FLY")

## 播放 END 动画（供 ChallengeController 调用）
func play_end_animation():
	if animated_sprite and animated_sprite.sprite_frames:
		if animated_sprite.sprite_frames.has_animation("END"):
			animated_sprite.play("END")
			# 等待动画完成
			await animated_sprite.animation_finished
			animation_finished_emitted = true

func _on_body_entered(body):
	if not is_active or animated_sprite.animation != "FLY":
		return
	
	if body.is_in_group("player"):
		# 排除冲刺状态
		if body.current_state == body.PlayerState.DASH:
			return
		
		# 简单条件：只要在 JUMP2 动画状态就可以触发
		if body.current_animation == "JUMP2":
			trigger_bounce(body)

func trigger_bounce(player):
	# 额外的安全检查
	if not is_active or not player:
		return

	# 防止边界帧重复触发导致受力叠加
	if player.has_method("can_accept_jumpbox_bounce") and not player.can_accept_jumpbox_bounce():
		return
		
	# 确保玩家仍然在正确状态
	if not player.has_double_jumped or player.current_animation != "JUMP2":
		print("DEBUG JumpBox: 触发时状态已改变，取消触发")
		return
	
		
	# 直接调用玩家的函数
	if player.has_method("start_jumpbox_bounce"):
		player.start_jumpbox_bounce(vertical_force)
	
	# Hit Stop 和相机抖动
	player.start_jumpbox_hit_stop()
	get_tree().create_timer(0.06).timeout.connect(func():
		CameraShakeManager.shake("y_weak", player.phantom_camera)
	)
	
	# 禁用弹跳方块
	is_active = false
	collision_shape.set_deferred("disabled", true)
	
	# 播放 END 动画
	animated_sprite.play("END")
	await animated_sprite.animation_finished
	animated_sprite.visible = false
	
	# 设置计时器重新激活
	await get_tree().create_timer(respawn_time).timeout
	
	# 重新激活弹跳方块
	is_active = true
	collision_shape.set_deferred("disabled", false)
	animated_sprite.visible = true
	# 重新播放 START 动画进入循环
	play_start_animation()
