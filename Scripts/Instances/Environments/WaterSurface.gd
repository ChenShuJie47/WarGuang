extends Area2D
class_name WaterSurface

## 水面设置
@export_category("水面设置")
## 涟漪生成间隔（秒）- 进入水面时立即生成的涟漪间隔
@export var ripple_interval: float = 0.2
## 持续涟漪生成间隔（秒）- 在水中移动时持续产生的涟漪
@export var continuous_ripple_interval: float = 1
## 是否启用音效
@export var enable_sound: bool = true

## 高级设置
@export_category("高级设置")
## 不同组别的物体产生不同的涟漪强度
@export var player_ripple_strength: float = 1.5
@export var enemy_ripple_strength: float = 2.0
@export var item_ripple_strength: float = 1.0

## 伤害设置
@export_category("伤害设置")
## 是否启用溺水伤害
@export var enable_drowning_damage: bool = true
## 溺水时间（秒后开始造成伤害）
@export var drowning_time: float = 3.0
## 每秒伤害值
@export var damage_per_second: int = 1  
## 伤害类型（0=普通，1=阴影，2=传送...）
@export var damage_type: int = 0
## 连续溺水伤害间隔（秒）
@export var continuous_drown_interval: float = 1.5

## 物理效果设置
@export_category("物理效果设置")
## 水中水平速度乘数（0.5 = 速度减半）
@export var water_horizontal_multiplier: float = 0.5
## 水中垂直速度乘数（0.5 = 速度减半）
@export var water_vertical_multiplier: float = 0.3
## 水中重力乘数（0.3 = 重力减少 70%）
@export var water_gravity_multiplier: float = 0.6
## 水中最大下落速度乘数（0.75 = 最大速度减少 25%）
@export var water_max_fall_multiplier: float = 0.3
## 水中加速度乘数（1.0 = 不变）
@export var water_acceleration_multiplier: float = 0.5

## 浸入判定设置
@export_category("浸入判定")
## 浸入比例阈值（0.8 = 物体 80% 体积进入水中时触发溺水判定）
## - 取值范围：0.0 ~ 1.0
## - 值越小越容易触发溺水（50% 就触发）
## - 值越大越难触发溺水（需要几乎完全浸没）
## - 0.5 = 一半体积浸入就触发
## - 0.8 = 推荐，80% 体积浸入才触发
## - 1.0 = 必须完全浸没才触发
@export var submersion_threshold: float = 0.8

## 可视化区域（编辑器中显示水面范围）
@export_category("可视化")
## 水面可视化区域引用（在场景中手动指定）
@export var water_area: TextArea
## Shader 材质引用（拖拽指定 Shader 资源）
@export var water_wave_shader: Shader
## WaterSurface 渲染层级
@export var water_surface_layer: int = 10

## 缩放锁定（防止意外缩放）
@export_category("缩放设置")
## 是否允许缩放（运行时禁用）
@export var allow_scale: bool = false

## 水波动画设置
@export_category("水波动画")
## 是否启用水波动画（false = 关闭动画，水面静止）
@export var enable_wave_animation: bool = true
## 波浪振幅（波浪起伏的最大高度，单位：像素）
## - **作用**: 控制波浪上下起伏的高度
## - **与顶点的关系**: 顶点数量决定波浪细腻度，振幅决定波浪跳多高
## - 取值范围：0.0 ~ 50.0（推荐 3.0 ~ 15.0）
## - 值越大波浪起伏越明显，过大会导致失真
## - 0.0 = 无波浪，水面完全平坦
## - **控制权**: WaterSurface.gd → water_wave.gdshader（实际执行）
@export var wave_amplitude: float = 1.0
## 波浪频率（弧度/像素）
## - **作用**: 控制波浪的波长（两个波峰之间的距离）
## - **公式**: 波长 ≈ 2π / frequency
## - 取值范围：0.01 ~ 20.0（推荐 0.1 ~ 1.0）
## - 值越小波浪越稀疏（波长越长），值越大波浪越密集（波长越短）
## - ✅ **推荐测试值**: 0.2 ~ 0.5（可以看到明显的波浪形状）
## - **控制权**: WaterSurface.gd → water_wave.gdshader（实际执行）
@export var wave_frequency: float = 0.1
## 波浪速度（弧度/秒）
## - 取值范围：0.0 ~ 10.0（推荐 0.5 ~ 3.0）
## - 值越大波浪移动越快，0.0 = 静止不动
## - 1.0 = 每秒移动约 1 个波浪周期
## - **控制权**: WaterSurface.gd → water_wave.gdshader（实际执行）
@export var wave_speed: float = 2.0
## 顶点间隔（像素）- 控制顶点分布密度
## - **作用**: 决定多边形上顶点的分布密度，影响波浪效果的细腻程度
## - 取值范围：5.0 ~ 50.0（推荐 10.0 ~ 20.0）
## - 值越小顶点越密集，波浪越细腻；值越大顶点越稀疏，性能越好
## - 10.0 = 每 10 像素一个顶点（非常细腻，适合小水面）
## - 15.0 = 每 15 像素一个顶点（推荐，平衡效果和性能）
## - 20.0 = 每 20 像素一个顶点（足够显示波浪，适合大水面）
@export var wave_vertex_spacing: float = 10.0

## 渐变效果设置
@export_category("渐变效果")
## 是否启用颜色渐变（false = 使用单一颜色）
@export var enable_gradient: bool = true
## 顶部水域颜色（较浅，透明度较高）
## - 建议 Alpha 通道：0.3 ~ 0.6（半透明效果）
@export var top_color: Color = Color.from_rgba8(180, 255, 255, 100)
## 底部水域颜色（较深，透明度较低）
## - 建议 Alpha 通道：0.6 ~ 0.9（更深的颜色）
@export var bottom_color: Color = Color(0.196, 0.353, 0.706, 0.784)
## 渐变过渡平滑度（控制颜色渐变的曲线）
## - 取值范围：0.1 ~ 5.0（推荐 0.5 ~ 2.0）
## - 1.0 = 线性渐变（均匀过渡）
## - < 1.0 = 过渡更平缓（中间区域更大）
## - > 1.0 = 过渡更陡峭（顶部和底部颜色分界更明显）
## - 2.0 = 推荐使用，营造水深层次感
@export var gradient_smoothness: float = 1.5

## 节点引用
@onready var particles = $RippleParticles
@onready var sound_player = $SplashSound
@onready var collision_shape_node: CollisionShape2D = $CollisionShape2D
@onready var water_polygon = $WaterVisuals/WaterPolygon if has_node("WaterVisuals/WaterPolygon") else null
@onready var water_gradient = $WaterVisuals/WaterGradient if has_node("WaterVisuals/WaterGradient") else null

## 内部变量
var surface_width: float = 200.0 # 水域宽度（运行时根据 scale 动态计算）
var surface_height: float = 100.0 # 水域高度（运行时根据 scale 动态计算）
var objects_in_water: Dictionary = {}  # 对象 -> 上次涟漪时间
var ripple_timer: float = 0.0
var drown_timers: Dictionary = {}  # 对象 -> 溺水计时器
var ripple_cooldowns: Dictionary = {}  # 对象 -> 持续涟漪冷却时间
var refreshed_objects: Array = []  # 已经刷新过能力的物体（单次触碰只刷新一次）
var submerged_objects: Dictionary = {}  # 对象 -> 是否完全浸入标记
var last_damage_time: Dictionary = {}  # 对象 -> 上次受伤时间

func _update_collision_shape_size():
	if collision_shape_node and collision_shape_node.shape is RectangleShape2D:
		var rect_shape = collision_shape_node.shape as RectangleShape2D
		rect_shape.size = Vector2(surface_width, surface_height)
		
		# 关键新增：同步更新水面多边形
		_update_water_polygon()

func _update_water_polygon():
	if not water_polygon:
		return
	
	# 创建矩形多边形（增加顶点数量以支持波浪效果）
	var polygon = PackedVector2Array()
	var half_width = surface_width / 2.0
	var half_height = surface_height / 2.0
	
	# ✅ 关键修复：根据水面长度动态计算顶点数量
	# 使用外部参数 wave_vertex_spacing 控制顶点密度
	var top_bottom_vertex_count = max(2, int(surface_width / wave_vertex_spacing) + 1)
	
	# 顶部边缘的顶点（从左到右）
	for i in range(top_bottom_vertex_count):
		var t = float(i) / float(top_bottom_vertex_count - 1) if top_bottom_vertex_count > 1 else 0.0
		var x = -half_width + t * surface_width
		polygon.append(Vector2(x, -half_height))
	
	# 右侧边缘的顶点（从上到下，不重复右上角顶点）
	polygon.append(Vector2(half_width, half_height))  # 右下角顶点
	
	# 底部边缘的顶点（从右到左，不重复右下角顶点）
	for i in range(top_bottom_vertex_count - 2, -1, -1):
		var t = float(i) / float(top_bottom_vertex_count - 1) if top_bottom_vertex_count > 1 else 0.0
		var x = -half_width + t * surface_width
		polygon.append(Vector2(x, half_height))
	
	# 左侧边缘的顶点（从下到上，闭合多边形）
	polygon.append(Vector2(-half_width, -half_height))  # 左上角顶点（闭合）
	
	water_polygon.polygon = polygon
	
	# ✅ 关键新增：更新多边形后立即应用渐变
	_update_gradient_on_polygon()

## 同步 WaterArea 大小（与 CollisionShape2D 保持一致）
func _sync_water_area_size():
	var water_area_check = get_node_or_null("WaterArea") as TextArea
	if water_area_check:
		# ✅ 关键修复：防止双重缩放
		# WaterArea 作为子节点会继承父节点的 scale
		# 但我们希望 WaterArea 的实际大小 = surface_width × parent.scale
		# 所以需要将 WaterArea.size 设置为基础大小（不乘 scale）
		# 并且保持 WaterArea.scale = Vector2.ONE（不额外缩放）
		water_area_check.size = Vector2(200.0, 100.0)
		water_area_check.scale = Vector2.ONE

## 应用水波 Shader
func _apply_water_wave_shader():
	if not enable_wave_animation or not water_polygon:
		return
	
	var shader_material = ShaderMaterial.new()
	
	# 使用外部 Shader 引用（如果未指定则使用默认路径）
	if water_wave_shader:
		shader_material.shader = water_wave_shader
	else:
		shader_material.shader = preload("res://Assets/Shaders/water_wave.gdshader")
	
	# 设置参数（振幅、频率、速度）
	shader_material.set_shader_parameter("amplitude", wave_amplitude)
	shader_material.set_shader_parameter("frequency", wave_frequency)
	shader_material.set_shader_parameter("speed", wave_speed)
	
	# 设置水面位置（只影响顶部）
	# 水面在多边形的顶部（y = -surface_height/2）
	shader_material.set_shader_parameter("water_surface_y", -surface_height / 2.0)
	shader_material.set_shader_parameter("influence_range", surface_height * 0.3)  # 影响范围为高度的 30%
	
	# 应用到水面多边形
	water_polygon.material = shader_material

## 应用渐变效果
func _apply_gradient_effect():
	if not enable_gradient:
		return
	
	# 创建渐变纹理或使用 ColorRect
	# 这里使用简单的颜色调制方法
	if water_polygon and water_polygon is Polygon2D:
		# 设置顶点颜色实现渐变
		_update_gradient_on_polygon()

## 更新多边形顶点颜色（实现渐变）
func _update_gradient_on_polygon():
	if not water_polygon or not water_polygon.polygon:
		return
	
	var polygon = water_polygon.polygon
	var colors: PackedColorArray = []
	
	for vertex in polygon:
		# 根据 Y 坐标计算渐变（从顶部到底部）
		var normalized_y = (vertex.y + surface_height / 2.0) / surface_height
		normalized_y = clamp(normalized_y, 0.0, 1.0)
		
		# 插值颜色
		var color = top_color.lerp(bottom_color, pow(normalized_y, gradient_smoothness))
		colors.append(color)
	
	water_polygon.vertex_colors = colors

func _ready():
	# 初始化粒子
	if particles:
		particles.emitting = false
		particles.amount = 8
	
	# 设置图层顺序
	z_as_relative = true
	z_index = water_surface_layer
	
	# 延迟更新尺寸，确保实例的缩放已完全应用
	call_deferred("_update_surface_size_from_scale")
	
	# 应用水波 Shader
	_apply_water_wave_shader()
	
	# 应用渐变效果
	_apply_gradient_effect()

## 延迟更新表面尺寸（确保 scale 已应用）
func _update_surface_size_from_scale():
	# 不乘以 scale，因为子节点会继承父节点的缩放
	# 避免双重缩放问题
	surface_width = 200.0
	surface_height = 100.0
	_update_collision_shape_size()
	_sync_water_area_size()

## 处理物体进入水面
func _on_body_entered(body):
	if is_water_interactive(body):
		objects_in_water[body] = ripple_timer
		
		# 入水瞬间刷新二段跳和冲刺（只刷新一次）
		if not refreshed_objects.has(body):
			refresh_jump_and_dash_for(body)
			refreshed_objects.append(body)
		
		# 初始化溺水计时器和浸入标记
		if is_fully_submerged(body):
			drown_timers[body] = 0.0
			submerged_objects[body] = true
			last_damage_time[body] = -999.0
		else:
			submerged_objects[body] = false
			last_damage_time[body] = 0.0
		
		# 立即生成一个涟漪
		spawn_ripple_at_position(body.global_position, get_ripple_strength(body))
		
		# 应用水的环境效果
		apply_water_environment(body)

## 处理物体离开水面
func _on_body_exited(body):
	if body in objects_in_water:
		objects_in_water.erase(body)
		
		# ========== 【新增】清除水的环境效果 ==========
		clear_water_environment(body)
		
		# 清理相关数据
		if drown_timers.has(body):
			drown_timers.erase(body)
		if ripple_cooldowns.has(body):
			ripple_cooldowns.erase(body)
		if submerged_objects.has(body):
			submerged_objects.erase(body)
		if last_damage_time.has(body):
			last_damage_time.erase(body)
		
		# 从已刷新列表中移除
		if body in refreshed_objects:
			refreshed_objects.erase(body)
		
		# ✅ 修复涟漪不消失问题：离开时停止粒子发射
		if particles and objects_in_water.size() == 0:
			particles.emitting = false

func _physics_process(delta):
	# 更新水中的物体
	ripple_timer += delta
	
	var valid_objects = []
	for obj in objects_in_water:
		if is_instance_valid(obj):
			valid_objects.append(obj)
			
			# 检查是否可以生成新的涟漪（进入时的立即涟漪）
			if ripple_timer >= ripple_interval:
				var time_since_last = ripple_timer - objects_in_water[obj]
				if time_since_last >= ripple_interval:
					spawn_ripple_at_position(obj.global_position, get_ripple_strength(obj))
					objects_in_water[obj] = ripple_timer
			
			# 处理持续涟漪（在水中移动时）
			handle_continuous_ripples(obj, delta)
			
			# 每帧检查是否完全浸入并处理受伤
			if enable_drowning_damage:
				var is_submerged = is_fully_submerged(obj)
				
				# 检测浸入状态变化
				if is_submerged and not submerged_objects.get(obj, false):
					# 刚完全浸入，重置溺水计时器
					drown_timers[obj] = 0.0
					submerged_objects[obj] = true
					last_damage_time[obj] = -999.0
				elif not is_submerged and submerged_objects.get(obj, false):
					# 部分露出水面，清除所有计时
					submerged_objects[obj] = false
					drown_timers[obj] = 0.0
					last_damage_time[obj] = 0.0
				
				# 只有完全浸没时才调用 handle_drowning
				if is_submerged:
					handle_drowning(obj, delta)

	# 清理无效对象
	for obj in objects_in_water:
		if not is_instance_valid(obj):
			objects_in_water.erase(obj)
			break

	objects_in_water.clear()
	for obj in valid_objects:
		objects_in_water[obj] = ripple_timer

## 应用水的环境效果
func apply_water_environment(body):
	if body.is_in_group("player") and body.has_method("set_environment_multipliers"):
		body.set_environment_multipliers(
			water_horizontal_multiplier,
			water_vertical_multiplier,
			water_gravity_multiplier,
			water_max_fall_multiplier,
			water_acceleration_multiplier
		)

## 清除水的环境效果
func clear_water_environment(body):
	if body.is_in_group("player") and body.has_method("set_environment_multipliers"):
		body.set_environment_multipliers(1.0, 1.0, 1.0, 1.0, 1.0)

## 参考 handle_landing() 完全重置跳跃状态
func refresh_jump_and_dash_for(body):
	if body.has_method("refresh_jump"):
		body.refresh_jump()
	
	if body.has_method("refresh_dash"):
		body.refresh_dash()
	
	# 关键新增：直接设置内部变量（完全复制 handle_landing()）
	if body is CharacterBody2D or (body.get_script() and body.get_script().get_global_name() == "Player"):
		body.jump_count = 0
		body.has_double_jumped = false
		body.can_double_jump = true  # 允许在水中再次使用二段跳
		body.is_double_jump_holding = false
		body.can_glide = false

## 在指定位置生成涟漪（修复警告：position → p_position）
## 支持速度关联的涟漪强度
func spawn_ripple_at_position(p_position: Vector2, strength: float):
	if !particles:
		return
	
	# 设置粒子发射位置
	particles.position = p_position
	particles.global_position = p_position
	
	# 根据强度调整粒子参数
	particles.amount = int(8 * strength)
	
	# 关键修复：通过 process_material 设置参数
	if particles.process_material:
		var mat = particles.process_material as ParticleProcessMaterial
		if mat:
			mat.initial_velocity_min = 10.0 * strength
			mat.initial_velocity_max = 20.0 * strength
	
	# 触发放射
	particles.restart()
	particles.emitting = true
	
	# 播放音效（独立于粒子效果）
	if enable_sound and sound_player:
		sound_player.play()

## 处理持续涟漪生成
## 根据移动速度动态生成涟漪
func handle_continuous_ripples(body, delta):
	if not ripple_cooldowns.has(body):
		ripple_cooldowns[body] = 0.0
	
	ripple_cooldowns[body] += delta
	
	# 检查是否可以生成新的涟漪
	if ripple_cooldowns[body] >= continuous_ripple_interval:
		# ✅ 新增：根据速度动态调整强度
		var velocity: Vector2
		if body is CharacterBody2D:
			velocity = body.velocity
		else:
			velocity = Vector2.ZERO
		
		# 速度越大，涟漪越强（基准速度 200）
		var speed_factor = clamp(velocity.length() / 200.0, 0.5, 2.0)
		var dynamic_strength = get_ripple_strength(body) * speed_factor
		
		spawn_ripple_at_position(body.global_position, dynamic_strength)
		ripple_cooldowns[body] = 0.0

## 获取物体的涟漪强度
## ✅ 优化问题 4：根据碰撞体大小和速度动态计算强度
func get_ripple_strength(body) -> float:
	var base_strength: float
	
	# 基础强度根据物体类型
	if body.is_in_group("player"):
		base_strength = player_ripple_strength
	elif body.is_in_group("enemy"):
		base_strength = enemy_ripple_strength
	elif body.is_in_group("item"):
		base_strength = item_ripple_strength
	else:
		base_strength = 0.5
	
	# ✅ 新增：根据碰撞体大小调整强度
	var player_collision_shape = body.get_node("CollisionShape2D")  # ✅ 修复问题 5：使用不同的变量名
	if player_collision_shape and player_collision_shape.shape:
		var shape_size: float
		if player_collision_shape.shape is RectangleShape2D:
			shape_size = player_collision_shape.shape.size.x * player_collision_shape.shape.size.y
		elif player_collision_shape.shape is CircleShape2D:
			shape_size = PI * player_collision_shape.shape.radius * player_collision_shape.shape.radius
		else:
			shape_size = 100.0  # 默认值
		
		# 大小系数（基准 100x100=10000）
		var size_factor = clamp(shape_size / 10000.0, 0.5, 2.0)
		base_strength *= size_factor
	
	return base_strength

## 检查物体是否可以与水面互动
func is_water_interactive(body) -> bool:
	# 检查是否有碰撞形状
	if not body.get_node("CollisionShape2D"):
		return false
	
	# 可以根据需要添加更多检查
	# 例如：排除某些类型的物体
	return true

## 处理溺水伤害
## ✅ 修复问题 3：第一次 drowning_time 后触发一次，后续每 continuous_drown_interval 触发一次
func handle_drowning(body, delta):
	# 只有完全浸没时才开始计时
	if not is_fully_submerged(body):
		return
	
	# 初始化或更新计时器
	if not drown_timers.has(body):
		drown_timers[body] = 0.0
	
	drown_timers[body] += delta
	
	# 检查是否达到溺水时间
	if drown_timers[body] >= drowning_time:
		# 检查是否可以造成连续伤害
		var can_damage = false
		
		# 从未受过伤，触发第一次
		if not last_damage_time.has(body):
			can_damage = true
			last_damage_time[body] = drown_timers[body]
		elif drown_timers[body] - last_damage_time[body] >= continuous_drown_interval:
			# 后续连续伤害
			can_damage = true
			last_damage_time[body] = drown_timers[body]
		
		if can_damage:
			# 造成伤害
			apply_drowning_damage(body)

## 应用溺水伤害
func apply_drowning_damage(body):
	if not body.has_method("take_damage"):
		print("WaterSurface: 警告 - ", body.name, " 没有 take_damage 方法")
		return
	
	# ✅ 修复问题 3：溺水伤害无视无敌时间，但刷新无敌计时器
	var was_invincible = false
	
	# 检查是否有 is_invincible 变量
	if "is_invincible" in body:
		was_invincible = body.is_invincible
	
	# 临时关闭无敌（让伤害生效）
	if was_invincible:
		body.is_invincible = false
	
	# 计算击退力（轻微向上）
	var knockback_vector = Vector2(0, -100)
	
	# 调用玩家的受伤方法
	body.take_damage(global_position, damage_per_second, damage_type, knockback_vector)
	
	# ✅ 修复问题 3：刷新无敌时间（如果之前是无敌状态）
	if was_invincible and "is_invincible" in body:
		body.is_invincible = true  # 恢复无敌状态
		# 重置无敌计时器
		if "invincible_timer" in body:
			body.invincible_timer = body.hurt_invincible_time if "hurt_invincible_time" in body else 1.5

## 停止水面效果
func stop_water_effects(_body):
	# 通知玩家离开水面
	if _body.has_method("set_in_water"):
		_body.set_in_water(false)
	
	# 恢复正常的物理效果
	if _body.has_method("clear_water_physics"):
		_body.clear_water_physics()

## 外部调用：强制在指定位置生成涟漪（修复警告：position → p_position）
func create_ripple_at(p_position: Vector2, strength: float = 1.0):
	spawn_ripple_at_position(p_position, strength)

## 外部调用：设置水面大小（替代旧的 set_water_depth）
func set_water_surface_size(width: float, height: float):
	surface_width = width
	surface_height = height
	_sync_water_area_size()

## 刷新玩家的水中能力（跳跃和冲刺）
func refresh_water_abilities_for(body):
	# 重置跳跃次数
	if body.has_method("refresh_jump"):
		body.refresh_jump()

	# 重置冲刺状态
	if body.has_method("refresh_dash"):
		body.refresh_dash()

## 检查物体是否完全浸没在水中（使用 CollisionShape2D 的碰撞区域判断）
func is_fully_submerged(body) -> bool:
	# ✅ 关键修复：使用 CollisionShape2D 而不是 WaterArea
	# 原因：Area2D 的检测范围会自动跟随父节点缩放，但 WaterArea 被强制设置为固定大小
	# 这导致伤害判定区域与其他效果区域不一致
	if collision_shape_node and collision_shape_node.shape is RectangleShape2D:
		var rect_shape = collision_shape_node.shape as RectangleShape2D
		# 获取 CollisionShape2D 的全局矩形（包含缩放）
		var water_rect: Rect2
		if Engine.is_editor_hint():
			# 编辑器中使用 shape.size（因为还没有应用缩放）
			water_rect = Rect2(
				global_position.x - rect_shape.size.x / 2,
				global_position.y - rect_shape.size.y / 2,
				rect_shape.size.x,
				rect_shape.size.y
			)
		else:
			# 运行时使用 global_transform 获取实际大小（包含缩放）
			var collision_transform = collision_shape_node.global_transform
			var actual_size = rect_shape.size * Vector2(abs(collision_transform.x.x), abs(collision_transform.y.y))
			water_rect = Rect2(
				global_position.x - actual_size.x / 2,
				global_position.y - actual_size.y / 2,
				actual_size.x,
				actual_size.y
			)
		
		# 获取玩家的碰撞区域
		var player_collision = body.get_node("CollisionShape2D")
		if not player_collision or not player_collision.shape:
			return false
		
		var shape = player_collision.shape
		var player_rect: Rect2
		
		# 根据形状类型获取玩家矩形
		if shape is RectangleShape2D:
			# 矩形碰撞箱
			var half_size = shape.size / 2
			player_rect = Rect2(
				body.global_position.x - half_size.x,
				body.global_position.y - half_size.y,
				shape.size.x,
				shape.size.y
			)
		elif shape is CircleShape2D:
			# 圆形碰撞箱（使用外接矩形）
			var diameter = shape.radius * 2
			player_rect = Rect2(
				body.global_position.x - shape.radius,
				body.global_position.y - shape.radius,
				diameter,
				diameter
			)
		else:
			# 其他形状，无法判断
			return false
		
		# 计算重叠区域
		var overlap_rect = player_rect.intersection(water_rect)
		
		# 如果无重叠，返回 false
		if overlap_rect.size.x <= 0 or overlap_rect.size.y <= 0:
			return false
		
		# 计算浸入比例（重叠面积 / 物体总面积）
		var player_area = player_rect.size.x * player_rect.size.y
		var overlap_area = overlap_rect.size.x * overlap_rect.size.y
		var submersion_ratio = overlap_area / player_area
		
		# 判断是否达到阈值
		return submersion_ratio >= submersion_threshold
	else:
		# 如果没有 CollisionShape2D，回退到旧逻辑（应尽量避免）
		printerr("ERROR WaterSurface: 缺少 CollisionShape2D 节点，无法判断完全浸没")
		return false

## 缩放保护（防止意外缩放）
# ⚠️ 已禁用：此逻辑会导致实例的缩放被强制重置为 (1, 1)
# func _process(_delta):
# 	if not Engine.is_editor_hint():
# 		if not allow_scale and scale != Vector2.ONE:
# 			scale = Vector2.ONE

## 监听缩放变化通知
func _notification(what):
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		# scale 发生变化时更新尺寸（包括编辑器和运行时）
		call_deferred("_update_surface_size_from_scale")

## 缩放变化时更新 surface 尺寸
func _on_scale_changed():
	surface_width = 200.0 * scale.x
	surface_height = 100.0 * scale.y
	_update_collision_shape_size()
	_sync_water_area_size()
