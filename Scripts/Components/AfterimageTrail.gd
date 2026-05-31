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

## 低级残影配置：慢动作期间引用。
@export_group("低级残影配置")
@export var low_color: Color = Color.from_rgba8(250, 250, 250, 255)
@export var low_lifetime: float = 0.4
@export var low_interval: float = 0.2
@export var low_pool_size: int = 20
@export var low_solid_color: bool = true
@export var low_fade_scale_effect: bool = true
@export var low_move_distance: float = 10.0

## 普通残影配置：普通冲刺、JumpBox普通触发二段跳引用。
@export_group("普通残影配置")
@export var normal_color: Color = Color.from_rgba8(250, 250, 250, 255)
@export var normal_lifetime: float = 0.2
@export var normal_interval: float = 0.05
@export var normal_pool_size: int = 20
@export var normal_solid_color: bool = true
@export var normal_fade_scale_effect: bool = true
@export var normal_move_distance: float = 40.0

## 高级残影配置：超级冲刺、后撤步引用。
@export_group("高级残影配置")
@export var advanced_color: Color = Color.from_rgba8(250, 250, 250, 255)
@export var advanced_lifetime: float = 0.4
@export var advanced_interval: float = 0.1
@export var advanced_pool_size: int = 30
@export var advanced_solid_color: bool = true
@export var advanced_fade_scale_effect: bool = true
@export var advanced_move_distance: float = 30.0

## 黑色残影配置：黑暗冲刺引用。
@export_group("黑色残影配置")
@export var black_color: Color = Color.from_rgba8(25, 25, 25, 255)
@export var black_lifetime: float = 0.25
@export var black_interval: float = 0.03
@export var black_pool_size: int = 30
@export var black_solid_color: bool = true
@export var black_fade_scale_effect: bool = true
@export var black_move_distance: float = 60.0

## 粉色残影配置：JumpBox完美触发二段跳引用。
@export_group("粉色残影配置")
@export var pink_color: Color = Color.from_rgba8(230, 155, 255, 255)
@export var pink_lifetime: float = 0.4
@export var pink_interval: float = 0.05
@export var pink_pool_size: int = 40
@export var pink_solid_color: bool = true
@export var pink_fade_scale_effect: bool = true
@export var pink_move_distance: float = 40.0

## 暗红色残影配置：ManiacNPC 移动引用。
@export_group("暗红色残影配置")
@export var dark_red_color: Color = Color.from_rgba8(80, 30, 40, 255)
@export var dark_red_lifetime: float = 0.6
@export var dark_red_interval: float = 0.9
@export var dark_red_pool_size: int = 20
@export var dark_red_solid_color: bool = true
@export var dark_red_fade_scale_effect: bool = false
@export var dark_red_move_distance: float = 20.0

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
	_register_pool("normal", normal_color, normal_lifetime, normal_interval, normal_pool_size, normal_solid_color, normal_fade_scale_effect, normal_move_distance)
	_register_pool("low", low_color, low_lifetime, low_interval, low_pool_size, low_solid_color, low_fade_scale_effect, low_move_distance)
	_register_pool("black", black_color, black_lifetime, black_interval, black_pool_size, black_solid_color, black_fade_scale_effect, black_move_distance)
	_register_pool("advanced", advanced_color, advanced_lifetime, advanced_interval, advanced_pool_size, advanced_solid_color, advanced_fade_scale_effect, advanced_move_distance)
	_register_pool("pink", pink_color, pink_lifetime, pink_interval, pink_pool_size, pink_solid_color, pink_fade_scale_effect, pink_move_distance)
	_register_pool("dark_red", dark_red_color, dark_red_lifetime, dark_red_interval, dark_red_pool_size, dark_red_solid_color, dark_red_fade_scale_effect, dark_red_move_distance)

	# 向后兼容旧类型名
	_register_pool("dash", normal_color, normal_lifetime, normal_interval, normal_pool_size, normal_solid_color, normal_fade_scale_effect, normal_move_distance)
	_register_pool("black_dash", black_color, black_lifetime, black_interval, black_pool_size, black_solid_color, black_fade_scale_effect, black_move_distance)
	_register_pool("super_dash", advanced_color, advanced_lifetime, advanced_interval, advanced_pool_size, advanced_solid_color, advanced_fade_scale_effect, advanced_move_distance)
	_register_pool("jumpbox_perfect", pink_color, pink_lifetime, pink_interval, pink_pool_size, pink_solid_color, pink_fade_scale_effect, pink_move_distance)
	_register_pool("jumpbox_normal", low_color, low_lifetime, low_interval, low_pool_size, low_solid_color, low_fade_scale_effect, low_move_distance)
	_register_pool("jumpbox", pink_color, pink_lifetime, pink_interval, pink_pool_size, pink_solid_color, pink_fade_scale_effect, pink_move_distance)
	_register_pool("maniac_move", dark_red_color, dark_red_lifetime, dark_red_interval, dark_red_pool_size, dark_red_solid_color, dark_red_fade_scale_effect, dark_red_move_distance)

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
