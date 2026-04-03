extends Area2D

const MAX_FRAME_TIME: float = 1.0 / 30.0

## 伤害设置
@export_category("伤害设置")
## 伤害类型（0=普通，1=阴影，2=普通传送，3=阴影传送）
@export var damage_type: int = 0
## 造成的伤害值
@export var damage_amount: int = 1
## 水平击退力
@export var horizontal_knockback_force: float = 300.0
## 垂直击退力
@export var vertical_knockback_force: float = 200.0
## 持续伤害间隔（秒，0 表示只伤害一次）
@export var continuous_damage_interval: float = 0.5

## 移动设置
@export_category("移动设置")
## 移动速度（像素/秒）
@export var move_speed: float = 50.0
## 起始位置偏移（相对于初始位置）
@export var start_offset: Vector2 = Vector2(-50, 0)
## 结束位置偏移（相对于初始位置）
@export var end_offset: Vector2 = Vector2(50, 0)
## 在端点停留时间（秒）
@export var wait_time: float = 0.5
## 加速时间（从静止到正常速度）
@export var acceleration_time: float = 0.5
## 减速时间（从正常速度到静止）
@export var deceleration_time: float = 0.5

## 动画设置
@export_category("动画设置")
## 是否启用旋转
@export var enable_rotation: bool = true
## 旋转速度（度/秒）
@export var rotation_speed: float = 90.0

# 内部变量
var initial_position: Vector2  # 初始位置
var current_target: Vector2  # 当前移动目标位置
var wait_timer: float = 0.0  # 端点等待计时器
var is_waiting: bool = false  # 是否在端点等待
var is_moving_to_end: bool = true  # 是否正在向终点移动
var current_speed: float = 0.0  # 当前移动速度
var acceleration: float = 0.0  # 加速度
var deceleration: float = 0.0  # 减速度
var total_distance: float = 0.0  # 总移动距离
var traveled_distance: float = 0.0  # 已移动距离

# 持续伤害相关变量
var bodies_in_area: Array = []  # 当前在区域内的玩家列表
var damage_timers: Dictionary = {}  # 玩家 -> 伤害计时器
var damage_cooldown: Dictionary = {}  # 玩家 -> 伤害冷却时间

@onready var animated_sprite = $AnimatedSprite2D

func _ready():
	initial_position = global_position
	current_target = initial_position + end_offset
	
	total_distance = initial_position.distance_to(current_target)
	acceleration = move_speed / acceleration_time
	deceleration = move_speed / deceleration_time
	
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	animated_sprite.play("MOVE")

func _process(delta):
	var fixed_delta = min(delta, MAX_FRAME_TIME)
	
	# 处理旋转动画
	if enable_rotation:
		animated_sprite.rotation_degrees += rotation_speed * fixed_delta  # 改为 fixed_delta
	
	if is_waiting:
		wait_timer -= fixed_delta  # 改为 fixed_delta
		if wait_timer <= 0:
			is_waiting = false
			is_moving_to_end = !is_moving_to_end
			if is_moving_to_end:
				current_target = initial_position + end_offset
			else:
				current_target = initial_position + start_offset
			total_distance = initial_position.distance_to(current_target)
			traveled_distance = 0.0
			current_speed = 0.0
	else:
		var remaining_distance = global_position.distance_to(current_target)
		
		var is_accelerating = traveled_distance < acceleration_time * move_speed / 2
		var is_decelerating = remaining_distance < deceleration_time * move_speed / 2
		
		if is_accelerating:
			current_speed = min(current_speed + acceleration * delta, move_speed)
		elif is_decelerating:
			current_speed = max(current_speed - deceleration * delta, 0.0)
		else:
			current_speed = move_speed
		
		var direction = (current_target - global_position).normalized()
		
		var move_distance = current_speed * delta
		global_position += direction * move_distance
		traveled_distance += move_distance
		
		if remaining_distance <= 1.0:
			global_position = current_target
			is_waiting = true
			wait_timer = wait_time
	
	for i in range(bodies_in_area.size() - 1, -1, -1):
		var body = bodies_in_area[i]
		if not is_instance_valid(body):
			bodies_in_area.remove_at(i)
			if damage_timers.has(body):
				damage_timers.erase(body)
			if damage_cooldown.has(body):
				damage_cooldown.erase(body)
			continue
			
		if body.is_in_group("player"):
			if not damage_timers.has(body):
				damage_timers[body] = 0.0
			
			damage_timers[body] += delta
			if damage_timers[body] >= continuous_damage_interval:
				damage_timers[body] = 0.0
				if not damage_cooldown.has(body) or damage_cooldown[body] <= 0:
					apply_damage(body)
					damage_cooldown[body] = 0.1
	
	for body in damage_cooldown.keys():
		if is_instance_valid(body):
			damage_cooldown[body] -= delta
			if damage_cooldown[body] <= 0:
				damage_cooldown.erase(body)

func _on_body_entered(body):
	if body.is_in_group("player"):
		if not body in bodies_in_area:
			bodies_in_area.append(body)
			
			if continuous_damage_interval <= 0:
				if not damage_cooldown.has(body) or damage_cooldown[body] <= 0:
					apply_damage(body)
					damage_cooldown[body] = 0.1
			else:
				damage_timers[body] = continuous_damage_interval

func _on_body_exited(body):
	if body in bodies_in_area:
		bodies_in_area.erase(body)
	if damage_timers.has(body):
		damage_timers.erase(body)
	if damage_cooldown.has(body):
		damage_cooldown.erase(body)

func apply_damage(body):
	if body.has_method("is_invincible") and body.is_invincible:
		return
		
	if body.has_method("get_player_state") and body.get_player_state() == body.PlayerState.DASH and body.has_method("is_black_dash_unlocked") and body.is_black_dash_unlocked():
		return
	
	var direction = (body.global_position - global_position).normalized()
	
	var angle = abs(atan2(direction.y, direction.x) - PI/2)
	
	var total_force = sqrt(horizontal_knockback_force * horizontal_knockback_force + vertical_knockback_force * vertical_knockback_force)
	
	var y_force_ratio = cos(angle)  # 正上方时为 1，侧边时减小
	var x_force_ratio = sin(angle)  # 正上方时为 0，侧边时增大
	
	var actual_y_force = total_force * y_force_ratio
	var actual_x_force = total_force * x_force_ratio
	
	var knockback_force = Vector2(
		-sign(direction.x) * abs(actual_x_force),  # x 轴力：水平击退方向
		-abs(actual_y_force)  # y 轴力：总是向上
	)
	
	if body.has_method("take_damage"):
		if not damage_cooldown.has(body) or damage_cooldown[body] <= 0:
			body.take_damage(global_position, damage_amount, damage_type, knockback_force)
			damage_cooldown[body] = 0.3
