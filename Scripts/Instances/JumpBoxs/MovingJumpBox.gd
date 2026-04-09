extends JumpBox

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

# 移动相关变量
var start_position: Vector2
var end_position: Vector2
var current_target: Vector2
var is_moving: bool = true
var pause_timer: float = 0.0
var is_at_start: bool = true

func _setup_instance() -> void:
	start_position = original_position + start_offset
	end_position = original_position + end_offset
	global_position = start_position
	current_target = end_position

func _update_custom(delta: float) -> void:
	# 只有在激活状态、YES动画状态且没有暂停时才移动
	if is_active and animated_sprite.animation == "YES" and is_moving:
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

func _apply_trigger_effect(player, trigger_grade: String) -> void:
	var effect_overrides := {
		"horizontal_boost_multiplier": 1.5,
		"boost_duration_multiplier": 2.0 if trigger_grade == "perfect" else 1.0
	}
	if player.has_method("start_jumpbox_bounce"):
		player.start_jumpbox_bounce(vertical_force, trigger_grade, effect_overrides)
	if player.has_method("start_jumpbox_hit_stop"):
		player.start_jumpbox_hit_stop(trigger_grade)
	_debug_jumpbox_camera(player, "before_jumpbox_shake", trigger_grade)
	get_tree().create_timer(0.06).timeout.connect(func():
		CameraShakeManager.shake("y_weak", player.phantom_camera)
		_debug_jumpbox_camera(player, "after_jumpbox_shake", trigger_grade)
	)
