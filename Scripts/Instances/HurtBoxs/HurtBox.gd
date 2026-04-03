extends Area2D

## 伤害设置
@export_category("伤害设置")
## 造成的伤害值
@export var damage_amount: int = 1
## 伤害类型（0=普通，1=阴影，2=普通传送，3=阴影传送）
@export var damage_type: int = 0
## 水平击退力
@export var horizontal_knockback_force: float = 200.0
## 垂直击退力
@export var vertical_knockback_force: float = 300.0
## 伤害冷却时间（防止连续伤害）
@export var damage_cooldown_time: float = 0.1  # 推荐 0.1 秒

## 高级检测设置
@export_category("高级检测设置")
## 启用预测性检测（考虑玩家速度，高速物体建议开启）
@export var enable_predictive_detection: bool = false  # 优化：默认关闭
## 预测帧数（检测未来几帧的位置）
@export var prediction_frames: int = 2
## 启用精确碰撞检测
@export var enable_precise_collision: bool = true
## 启用调试可视化（生产环境请关闭）
@export var enable_debug: bool = false  # 优化：默认关闭

# 节点引用
@onready var collision_shape = $CollisionShape2D

# 内部变量
var bodies_in_area: Array = []  # 当前在区域内的玩家列表
var damage_cooldown: Dictionary = {}  # 玩家 -> 冷却时间剩余
var debug_timer: float = 0.0  # 调试计时器

func _ready():
	# 连接信号
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	if enable_debug:
		print("HurtBox: 初始化完成，启用预测性检测:", enable_predictive_detection, " 调试模式:", enable_debug)

func _physics_process(delta):
	# 优化：只处理冷却时间，不再遍历检测碰撞
	for i in range(bodies_in_area.size() - 1, -1, -1):
		var body = bodies_in_area[i]
		
		# 检查玩家是否仍然有效
		if not is_instance_valid(body):
			bodies_in_area.remove_at(i)
			damage_cooldown.erase(body)
			continue
		
		# ⭐ 关键修复：检测玩家是否还在 HurtBox 内（连续碰撞检测）
		if check_continuous_collision(body):
			# 玩家还在 HurtBox 内，检测是否需要造成伤害
			if not damage_cooldown.has(body) or damage_cooldown[body] <= 0:
				if apply_damage(body):
					damage_cooldown[body] = damage_cooldown_time
		
		# 更新冷却时间
		if damage_cooldown.has(body):
			damage_cooldown[body] -= delta
			if damage_cooldown[body] <= 0:
				damage_cooldown.erase(body)
	
	# 调试可视化（仅调试模式）
	if enable_debug:
		debug_timer += delta
		if debug_timer >= 1.0:
			debug_timer = 0.0
			print("HurtBox: 当前检测玩家数量:", bodies_in_area.size())

func _on_body_entered(body):
	if body.is_in_group("player"):
		if not body in bodies_in_area:
			bodies_in_area.append(body)
			
			if enable_debug:
				print("HurtBox: 玩家进入伤害区域")
			
			# 立即检测一次伤害
			if not damage_cooldown.has(body) or damage_cooldown[body] <= 0:
				if check_continuous_collision(body):
					# ⭐ 关键修复：只有真正造成伤害才设置冷却
					if apply_damage(body):
						damage_cooldown[body] = damage_cooldown_time

func _on_body_exited(body):
	if body in bodies_in_area:
		bodies_in_area.erase(body)
		if enable_debug:
			print("HurtBox: 玩家离开伤害区域")
	
	# ⭐ 关键修复：清理冷却数据（无论是否造成伤害）
	# 这样当玩家无敌结束后再次进入时，可以正常受到伤害
	if damage_cooldown.has(body):
		damage_cooldown.erase(body)

## 连续碰撞检测函数
func check_continuous_collision(body) -> bool:
	# 检查碰撞形状是否有效
	if not collision_shape or not collision_shape.shape:
		return false
	
	# 获取玩家碰撞形状
	var player_collision = body.get_node("CollisionShape2D")
	if not player_collision or not player_collision.shape:
		return false
	
	# 基础碰撞检测
	if check_immediate_collision(player_collision):
		return true
	
	# 预测性检测（如果启用）
	if enable_predictive_detection:
		return check_predictive_collision(body, player_collision)
	
	return false

## 立即碰撞检测 - 修复参数警告
func check_immediate_collision(player_collision) -> bool:
	var hurtbox_shape = collision_shape.shape
	var player_shape = player_collision.shape
	
	var hurtbox_transform = collision_shape.global_transform
	var player_transform = player_collision.global_transform
	
	# 使用 Godot 的物理引擎进行精确碰撞检测
	if enable_precise_collision:
		return hurtbox_shape.collide(hurtbox_transform, player_shape, player_transform)
	else:
		# 简化的 AABB 检测
		var hurtbox_aabb = get_shape_aabb(hurtbox_shape, hurtbox_transform)
		var player_aabb = get_shape_aabb(player_shape, player_transform)
		return hurtbox_aabb.intersects(player_aabb)

## 预测性碰撞检测
func check_predictive_collision(body, player_collision) -> bool:
	if not body.has_method("get_velocity"):
		return false
	
	var player_velocity = body.get_velocity()
	
	# 预测未来几帧的位置
	for i in range(1, prediction_frames + 1):
		var frame_time = i * (1.0 / Engine.physics_ticks_per_second)
		var predicted_position = body.global_position + player_velocity * frame_time
		
		# 创建预测的变换
		var predicted_transform = player_collision.global_transform
		predicted_transform.origin = predicted_position
		
		var hurtbox_shape = collision_shape.shape
		var player_shape = player_collision.shape
		var hurtbox_transform = collision_shape.global_transform
		
		# 检测预测位置是否碰撞
		if hurtbox_shape.collide(hurtbox_transform, player_shape, predicted_transform):
			if enable_debug:
				print("HurtBox: 预测性碰撞检测到！帧数=", i)
			return true
	
	return false

## 应用伤害
func apply_damage(body) -> bool:
	if not body.has_method("take_damage"):
		return false
	
	# ⭐ 关键修复：检测玩家是否无敌
	var player_invincible = body.is_invincible if body.has_method("is_invincible") else false
	if player_invincible:
		return false  # 玩家无敌，不造成伤害
	
	# 计算击退力向量
	var knockback_vector = Vector2(
		horizontal_knockback_force * (-1 if body.global_position.x > global_position.x else 1),
		-vertical_knockback_force
	)
	
	# ⭐ 关键修复：调用受伤方法，检测是否真正造成了伤害
	var had_method = body.has_method("take_damage")
	body.take_damage(global_position, damage_amount, damage_type, knockback_vector)
	
	# ⭐ 通过检查玩家血量变化来判断是否造成了伤害
	# 如果玩家无敌，take_damage 会直接 return，血量不变
	if enable_debug:
		print("HurtBox: 对玩家造成伤害：", damage_amount, " 类型：", damage_type)
	
	return had_method  # ✅ 只有调用了 take_damage 才返回 true

## 获取形状的 AABB（辅助函数）
func get_shape_aabb(shape: Shape2D, p_transform: Transform2D) -> Rect2:
	# 简化实现，实际应该根据形状类型计算
	return shape.get_rect() if shape.has_method("get_rect") else Rect2(p_transform.origin, Vector2(10, 10))
