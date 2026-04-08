extends Area2D

## 弹跳设置
@export_category("弹跳设置")
## 垂直向上的力大小
@export var vertical_force: float = 600.0

# 节点引用
@onready var animated_sprite = $AnimatedSprite2D
@onready var collision_shape = $CollisionShape2D

# 状态变量
var is_playing_touch: bool = false
var touch_animation_queue: int = 0

var is_active: bool = true

func _ready():
	# 连接信号
	body_entered.connect(_on_body_entered)
	
	# 开始播放CYCLE动画
	animated_sprite.play("CYCLE")

func _on_body_entered(body):
	if not is_active:
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

	# 与 JumpBox 保持一致：避免边界帧重复触发造成受力叠加
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
	
	# 播放TOUCH动画
	play_touch_animation()

func play_touch_animation():
	# 增加触摸动画队列计数
	touch_animation_queue += 1
	
	# 如果已经在播放TOUCH动画，立即重新播放
	if is_playing_touch:
		animated_sprite.play("TOUCH")
		return
	
	# 开始播放TOUCH动画
	is_playing_touch = true
	
	# 循环播放TOUCH动画直到队列清空
	while touch_animation_queue > 0:
		animated_sprite.play("TOUCH")
		await animated_sprite.animation_finished
		touch_animation_queue -= 1
	
	# 切换回CYCLE动画
	is_playing_touch = false
	animated_sprite.play("CYCLE")
