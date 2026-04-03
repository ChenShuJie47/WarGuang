extends Node2D

const MAX_FRAME_TIME: float = 1.0 / 30.0  # 最大帧时间（30FPS 下限）

## 移动设置
@export_category("移动设置")
## 移动速度（像素/秒）
@export var move_speed: float = 100.0
## 起始位置偏移（相对于初始位置）
@export var start_offset: Vector2 = Vector2(-100, 0)
## 结束位置偏移（相对于初始位置）
@export var end_offset: Vector2 = Vector2(100, 0)
## 在端点停留时间（秒）
@export var wait_time: float = 1.0
## 加速时间（从静止到正常速度）
@export var acceleration_time: float = 0.5
## 减速时间（从正常速度到静止）
@export var deceleration_time: float = 0.5

# 内部变量
var initial_position: Vector2
var current_target: Vector2
var wait_timer: float = 0.0
var is_waiting: bool = true  # 开始时等待，然后立即移动
var is_moving_to_end: bool = true
var current_speed: float = 0.0
var acceleration: float = 0.0
var deceleration: float = 0.0
var total_distance: float = 0.0
var traveled_distance: float = 0.0

# 节点引用
@onready var animated_sprite = $AnimatedSprite2D
@onready var collision_shape = $CollisionShape2D

func _ready():
	# 记录初始位置
	initial_position = global_position
	# 设置第一个目标
	current_target = initial_position + end_offset
	
	# 计算总距离和加速度
	total_distance = initial_position.distance_to(current_target)
	acceleration = move_speed / acceleration_time
	deceleration = move_speed / deceleration_time
	
	# 初始动画
	animated_sprite.play("IDLE")
	
	# 开始时等待一段时间后开始移动
	wait_timer = wait_time

func _physics_process(delta):
	# 限制最大 delta 值，确保不同帧率下移动速度一致
	var fixed_delta = min(delta, MAX_FRAME_TIME)
	
	if is_waiting:
		wait_timer -= fixed_delta  # 改为 fixed_delta
		animated_sprite.play("IDLE")
		
		if wait_timer <= 0:
			is_waiting = false
			# 切换目标方向
			is_moving_to_end = !is_moving_to_end
			if is_moving_to_end:
				current_target = initial_position + end_offset
			else:
				current_target = initial_position + start_offset
			# 重置移动参数
			total_distance = initial_position.distance_to(current_target)
			traveled_distance = 0.0
			current_speed = 0.0
			# 切换动画
			animated_sprite.play("MOVE")
	else:
		# 计算距离目标的剩余距离
		var remaining_distance = global_position.distance_to(current_target)
		
		# 计算加速/减速阶段
		var is_accelerating = traveled_distance < acceleration_time * move_speed / 2
		var is_decelerating = remaining_distance < deceleration_time * move_speed / 2
		
		# 根据阶段调整速度
		if is_accelerating:
			current_speed = min(current_speed + acceleration * fixed_delta, move_speed)  # 改为 fixed_delta
		elif is_decelerating:
			current_speed = max(current_speed - deceleration * fixed_delta, 0.0)  # 改为 fixed_delta
		else:
			current_speed = move_speed
		
		var direction = (current_target - global_position).normalized()
		
		var move_distance = current_speed * fixed_delta  # 改为 fixed_delta
		global_position += direction * move_distance
		
		traveled_distance += move_distance
		
		# 检查是否到达目标
		if remaining_distance <= 2.0:  # 使用小阈值防止抖动
			global_position = current_target
			is_waiting = true
			wait_timer = wait_time
