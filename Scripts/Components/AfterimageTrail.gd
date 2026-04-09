extends Node2D

class_name AfterimageTrail

class AfterimageConfig:
	## 残影类型标识符（用于区分不同效果的残影）
	var type: String = ""
	## 残影颜色（可设置RGBA，影响残影色调）
	var color: Color = Color.WHITE
	## 残影生命周期（秒），残影淡出前显示的时长
	var lifetime: float = 0.3
	## 残影生成间隔（秒），每多少时间生成一个残影
	var spawn_interval: float = 0.05
	## 是否启用缩放效果（控制残影是否随时间缩放）
	var scale_effect: bool = true
	## 是否使用纯色渲染（true=纯色块，false=带纹理）
	var solid_color: bool = true
	## 是否启用淡出时的缩放效果（残影消失时是否同时缩小）
	var fade_scale_effect: bool = true
	## 残影位移强度（Shader move_distance）
	var move_distance: float = 50.0

@export_group("Dash")
## 普通冲刺残影颜色
@export var dash_color: Color = Color(0.804, 0.804, 0.804, 1.0)
## 普通冲刺残影生命周期（秒）
@export var dash_lifetime: float = 0.2
## 普通冲刺残影生成间隔（秒）
@export var dash_interval: float = 0.03
## 普通冲刺残影对象池大小
@export var dash_pool_size: int = 20
## 普通冲刺是否使用纯色渲染
@export var dash_solid_color: bool = true
## 普通冲刺是否启用淡出缩放效果
@export var dash_fade_scale_effect: bool = true
## 普通冲刺残影位移强度
@export var dash_move_distance: float = 40.0

@export_group("Black Dash")
## 黑暗冲刺残影颜色
@export var black_dash_color: Color = Color(0.094, 0.094, 0.094, 1.0)
## 黑暗冲刺残影生命周期（秒）
@export var black_dash_lifetime: float = 0.25
## 黑暗冲刺残影生成间隔（秒）
@export var black_dash_interval: float = 0.025
## 黑暗冲刺残影对象池大小
@export var black_dash_pool_size: int = 25
## 黑暗冲刺是否使用纯色渲染
@export var black_dash_solid_color: bool = true
## 黑暗冲刺是否启用淡出缩放效果
@export var black_dash_fade_scale_effect: bool = true
## 黑暗冲刺残影位移强度
@export var black_dash_move_distance: float = 60.0

@export_group("Super Dash")
## 超级冲刺残影颜色
@export var super_dash_color: Color = Color(0.804, 0.804, 0.804, 1.0)
## 超级冲刺残影生命周期（秒）
@export var super_dash_lifetime: float = 0.6
## 超级冲刺残影生成间隔（秒）
@export var super_dash_interval: float = 0.1
## 超级冲刺残影对象池大小
@export var super_dash_pool_size: int = 40
## 超级冲刺是否使用纯色渲染
@export var super_dash_solid_color: bool = true
## 超级冲刺是否启用淡出缩放效果
@export var super_dash_fade_scale_effect: bool = true
## 超级冲刺残影位移强度
@export var super_dash_move_distance: float = 60.0

@export_group("JumpBox Perfect")
## JumpBox完美触发二段跳残影颜色
@export var jumpbox_perfect_color: Color = Color(0.902, 0.608, 1.0, 1.0)
## JumpBox完美触发二段跳残影生命周期（秒）
@export var jumpbox_perfect_lifetime: float = 0.35
## JumpBox完美触发二段跳残影生成间隔（秒）
@export var jumpbox_perfect_interval: float = 0.05
## JumpBox完美触发二段跳残影对象池大小
@export var jumpbox_perfect_pool_size: int = 40
## JumpBox完美触发二段跳是否使用纯色渲染
@export var jumpbox_perfect_solid_color: bool = true
## JumpBox完美触发二段跳是否启用淡出缩放效果
@export var jumpbox_perfect_fade_scale_effect: bool = true
## JumpBox完美触发二段跳残影位移强度
@export var jumpbox_perfect_move_distance: float = 50.0

@export_group("JumpBox Normal")
## JumpBox普通触发二段跳残影颜色（白色）
@export var jumpbox_normal_color: Color = Color(1.0, 1.0, 1.0, 1.0)
## JumpBox普通触发二段跳残影生命周期（秒）
@export var jumpbox_normal_lifetime: float = 0.25
## JumpBox普通触发二段跳残影生成间隔（秒）
@export var jumpbox_normal_interval: float = 0.05
## JumpBox普通触发二段跳残影对象池大小
@export var jumpbox_normal_pool_size: int = 30
## JumpBox普通触发二段跳是否使用纯色渲染
@export var jumpbox_normal_solid_color: bool = true
## JumpBox普通触发二段跳是否启用淡出缩放效果
@export var jumpbox_normal_fade_scale_effect: bool = true
## JumpBox普通触发二段跳残影位移强度
@export var jumpbox_normal_move_distance: float = 40.0

@export_group("Maniac Move")
## ManiacNPC 移动残影颜色（暗红色系）
@export var maniac_move_color: Color = Color(0.396, 0.173, 0.184, 1.0)
## ManiacNPC 移动残影生命周期（秒）
@export var maniac_move_lifetime: float = 0.6
## ManiacNPC 移动残影生成间隔（秒）
@export var maniac_move_interval: float = 0.3
## ManiacNPC 移动残影对象池大小
@export var maniac_move_pool_size: int = 15
## ManiacNPC 移动是否使用纯色渲染
@export var maniac_move_solid_color: bool = true
## ManiacNPC 移动是否启用淡出缩放效果
@export var maniac_move_fade_scale_effect: bool = false
## ManiacNPC 移动残影位移强度
@export var maniac_move_distance: float = 40.0

@export_group("Spawn Culling")
## 是否启用残影视野裁剪（超出当前相机视野则不生成）
@export var enable_spawn_culling: bool = true
## 视野裁剪额外边距（像素）
@export var spawn_culling_margin: float = 64.0

var canvas_group: CanvasGroup
var pools: Dictionary = {}

func _ready():
	_ensure_canvas_group()
	_register_default_pools()

func _ensure_canvas_group():
	if is_instance_valid(canvas_group):
		return
	canvas_group = CanvasGroup.new()
	canvas_group.name = "AfterimageTrailCanvasGroup"
	canvas_group.z_as_relative = false
	add_child(canvas_group)

func _register_default_pools():
	_register_pool("dash", dash_color, dash_lifetime, dash_interval, dash_pool_size, dash_solid_color, dash_fade_scale_effect, dash_move_distance)
	_register_pool("black_dash", black_dash_color, black_dash_lifetime, black_dash_interval, black_dash_pool_size, black_dash_solid_color, black_dash_fade_scale_effect, black_dash_move_distance)
	_register_pool("super_dash", super_dash_color, super_dash_lifetime, super_dash_interval, super_dash_pool_size, super_dash_solid_color, super_dash_fade_scale_effect, super_dash_move_distance)
	_register_pool("jumpbox_perfect", jumpbox_perfect_color, jumpbox_perfect_lifetime, jumpbox_perfect_interval, jumpbox_perfect_pool_size, jumpbox_perfect_solid_color, jumpbox_perfect_fade_scale_effect, jumpbox_perfect_move_distance)
	_register_pool("jumpbox_normal", jumpbox_normal_color, jumpbox_normal_lifetime, jumpbox_normal_interval, jumpbox_normal_pool_size, jumpbox_normal_solid_color, jumpbox_normal_fade_scale_effect, jumpbox_normal_move_distance)
	# 向后兼容旧类型名
	_register_pool("jumpbox", jumpbox_perfect_color, jumpbox_perfect_lifetime, jumpbox_perfect_interval, jumpbox_perfect_pool_size, jumpbox_perfect_solid_color, jumpbox_perfect_fade_scale_effect, jumpbox_perfect_move_distance)
	_register_pool("maniac_move", maniac_move_color, maniac_move_lifetime, maniac_move_interval, maniac_move_pool_size, maniac_move_solid_color, maniac_move_fade_scale_effect, maniac_move_distance)

func _register_pool(type: String, color: Color, life: float, interval: float, size: int, solid_color: bool, fade_scale: bool, move_distance: float):
	var cfg = AfterimageConfig.new()
	cfg.type = type
	cfg.color = color
	cfg.lifetime = life
	cfg.spawn_interval = interval
	cfg.scale_effect = true
	cfg.solid_color = solid_color
	cfg.fade_scale_effect = fade_scale
	cfg.move_distance = move_distance

	var pool_script = preload("res://Scripts/Resources/AfterimagePool.gd")
	var pool: Node = pool_script.new()
	pool.setup(cfg, canvas_group, size)
	pools[type] = pool

func get_interval(type: String) -> float:
	if not pools.has(type):
		return 0.05
	return pools[type].config.spawn_interval

func _is_position_in_view(pos: Vector2) -> bool:
	if not enable_spawn_culling:
		return true
	var viewport := get_viewport()
	if viewport == null:
		return true

	var screen_rect: Rect2 = viewport.get_visible_rect()
	var inv_canvas: Transform2D = viewport.get_canvas_transform().affine_inverse()
	var p1: Vector2 = inv_canvas * screen_rect.position
	var p2: Vector2 = inv_canvas * (screen_rect.position + Vector2(screen_rect.size.x, 0.0))
	var p3: Vector2 = inv_canvas * (screen_rect.position + Vector2(0.0, screen_rect.size.y))
	var p4: Vector2 = inv_canvas * (screen_rect.position + screen_rect.size)

	var min_x := minf(minf(p1.x, p2.x), minf(p3.x, p4.x))
	var min_y := minf(minf(p1.y, p2.y), minf(p3.y, p4.y))
	var max_x := maxf(maxf(p1.x, p2.x), maxf(p3.x, p4.x))
	var max_y := maxf(maxf(p1.y, p2.y), maxf(p3.y, p4.y))
	var world_view_rect := Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y)).grow(spawn_culling_margin)
	return world_view_rect.has_point(pos)

func spawn(type: String, spawn_position: Vector2, texture: Texture2D, flip_h: bool, custom_scale: Vector2, move_dir: Vector2, move_dist: float, target_z_index: int) -> Node2D:
	if not pools.has(type):
		return null
	if texture == null:
		return null
	if not _is_position_in_view(spawn_position):
		return null

	var pool: Node = pools[type]
	var afterimage = pool.get_available()
	if not afterimage:
		return null

	afterimage.top_level = true
	afterimage.initialize(
		texture,
		spawn_position,
		flip_h,
		custom_scale,
		pool.config.color,
		pool.config.lifetime,
		pool.config.scale_effect,
		pool.config.solid_color,
		pool.config
	)
	afterimage.afterimage_type = type
	afterimage.pool_ref = pool
	afterimage.z_as_relative = false
	afterimage.z_index = target_z_index

	var effective_move_distance = move_dist
	if effective_move_distance < 0.0:
		effective_move_distance = pool.config.move_distance

	if afterimage.shader_material != null:
		afterimage.shader_material.set_shader_parameter("move_direction", move_dir)
		afterimage.shader_material.set_shader_parameter("move_distance", effective_move_distance)

	return afterimage
