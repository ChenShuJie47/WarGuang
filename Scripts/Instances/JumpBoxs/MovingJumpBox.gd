extends Area2D

## 弹跳设置
@export_category("弹跳设置")
## 垂直向上的力大小
@export var vertical_force: float = 600.0

## 重生设置
@export_category("重生设置")
## 从隐藏到重新出现的时间（秒）
@export var respawn_time: float = 2.0

## 移动设置
@export_category("移动设置")
## 初始位置偏移（相对于编辑器中的位置）
@export var start_offset: Vector2 = Vector2(-100, 0)
## 末尾位置偏移（相对于编辑器中的位置）
@export var end_offset: Vector2 = Vector2(100, 0)
## 在两端停留的时间（秒）
@export var pause_time: float = 1.0
## 移动速度（像素/秒）
@export var move_speed: float = 50.0

# 节点引用
@onready var animated_sprite = $AnimatedSprite2D
@onready var collision_shape = $CollisionShape2D

# 状态变量
var is_active: bool = true
var original_position: Vector2

# 移动相关变量
var start_position: Vector2
var end_position: Vector2
var current_target: Vector2
var is_moving: bool = true
var pause_timer: float = 0.0
var is_at_start: bool = true

func _ready():
	# 保存原始位置
	original_position = global_position
	
	# 计算绝对位置
	start_position = original_position + start_offset
	end_position = original_position + end_offset
	
	# 设置初始位置和目标
	global_position = start_position
	current_target = end_position
	
	# 连接信号
	body_entered.connect(_on_body_entered)
	
	# 开始播放START动画
	play_start_animation()

func play_start_animation():
	# 播放START动画，不循环
	animated_sprite.play("START")
	# 等待动画播放完成
	await animated_sprite.animation_finished
	# 切换到FLY动画，循环
	animated_sprite.play("FLY")
	# 在Godot 4中设置循环的方式：
	var sprite_frames = animated_sprite.sprite_frames
	if sprite_frames:
		sprite_frames.set_animation_loop("FLY", true)

func _on_body_entered(body):
	if not is_active or animated_sprite.animation != "FLY":
		return
	
	if body.is_in_group("player"):
		# 排除冲刺状态
		if body.current_state == body.PlayerState.DASH:
			return
		
		# 简单条件：只要在JUMP2动画状态就可以触发
		if body.current_animation == "JUMP2":
			trigger_bounce(body)

func trigger_bounce(player):
	# 额外的安全检查
	if not is_active or not player:
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
	
	# 播放END动画
	animated_sprite.play("END")
	await animated_sprite.animation_finished
	animated_sprite.visible = false
	
	# 设置计时器重新激活
	await get_tree().create_timer(respawn_time).timeout
	
	# 重新激活弹跳方块
	is_active = true
	collision_shape.set_deferred("disabled", false)
	animated_sprite.visible = true
	# 重新播放START动画进入循环
	play_start_animation()

func _process(delta):
	# 只有在激活状态、FLY动画状态且没有暂停时才移动
	if is_active and animated_sprite.animation == "FLY" and is_moving:
		# 移动逻辑
		var direction = (current_target - global_position).normalized()
		var distance = global_position.distance_to(current_target)
		
		# 如果距离很小，则到达目标点
		if distance < move_speed * delta:
			global_position = current_target
			# 切换目标点并开始暂停
			if current_target == end_position:
				current_target = start_position
				is_at_start = false
			else:
				current_target = end_position
				is_at_start = true
			is_moving = false
			pause_timer = pause_time
		else:
			global_position += direction * move_speed * delta
	elif not is_moving:
		# 暂停计时
		pause_timer -= delta
		if pause_timer <= 0:
			is_moving = true
