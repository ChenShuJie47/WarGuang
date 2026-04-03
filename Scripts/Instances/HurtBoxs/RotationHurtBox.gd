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

## 旋转设置
@export_category("旋转设置")
## 是否启用旋转
@export var enable_rotation: bool = true
## 旋转速度（度/秒）
@export var rotation_speed: float = 90.0

# 节点引用
@onready var sprite = $Sprite2D

# 内部变量
var bodies_in_area: Array = []  # 当前在区域内的玩家列表
var damage_timers: Dictionary = {}  # 玩家 -> 伤害计时器
var damage_cooldown: Dictionary = {}  # 玩家 -> 伤害冷却时间

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _process(delta):
	# 关键修复：使用真实 delta 但应用 time_scale 使效果受慢动作影响
	# delta 不受 Engine.time_scale 影响（真实帧间隔）
	# 乘以 Engine.time_scale 后，在慢动作时旋转速度会减慢
	var scaled_delta = delta * Engine.time_scale
	
	if enable_rotation:
		rotation_degrees += rotation_speed * scaled_delta
	
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
			
			damage_timers[body] += scaled_delta
			if damage_timers[body] >= continuous_damage_interval:
				damage_timers[body] = 0.0
				if not damage_cooldown.has(body) or damage_cooldown[body] <= 0:
					apply_damage(body)
					damage_cooldown[body] = 0.1
	
	for body in damage_cooldown.keys():
		if is_instance_valid(body):
			# 关键修复：冷却时间也受慢动作影响
			damage_cooldown[body] -= scaled_delta
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
