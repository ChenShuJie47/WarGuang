extends Node2D

# ==================== 节点引用 ====================
@onready var sprite: Sprite2D = $Sprite2D  # 残影精灵
@onready var timer: Timer = $Timer  # 淡出计时器

# ==================== 外部变量 ====================
## 淡出持续时间（秒）
@export var fade_duration: float = 0.3
## 淡入持续时间（秒）
@export var fade_in_duration: float = 0.1

# ==================== Shader 相关变量 ====================
var shader_material: ShaderMaterial  # Shader 材质实例
var current_time: float = 0.0  # Shader 当前时间
var lifetime: float = 0.5  # 生命周期（由 AfterimageTrail 传递）

# ==================== 淡出配置变量 ====================
var fade_timer: float = 0.0  # 淡出已用时间
var is_fading_out: bool = false  # 是否正在淡出
var pool_config = null  # 池配置引用

# ==================== 对象池相关变量 ====================
var player_ref: Node = null  # 玩家引用
var pool_ref: Node = null  # 池引用
var npc_ref: Node = null  # NPC 引用
var instance_id: int = 0  # 实例 ID
var afterimage_type: String = "dash"  # 残影类型
var is_returning_to_pool: bool = false  # 是否正在回收到池子

func _ready():
	instance_id = get_instance_id()
	
	# ⭐ 加载 Shader 资源
	var shader_path = "res://Assets/Shaders/AfterimageShader.gdshader"
	if ResourceLoader.exists(shader_path):
		var shader = load(shader_path)
		if shader:
			shader_material = ShaderMaterial.new()
			shader_material.shader = shader
			sprite.material = shader_material
		else:
			push_error("[Afterimage] Shader 资源加载失败：", shader_path)
	else:
		push_error("[Afterimage] Shader 文件不存在：", shader_path)

func _ensure_shader_material():
	# 某些情况下（例如对象池刚创建但节点尚未 ready），shader_material 可能仍为 null。
	# 用懒加载兜底，确保 initialize 时 Shader 参数能正常写入。
	if shader_material != null:
		return
	if not is_instance_valid(sprite):
		return
	var shader_path = "res://Assets/Shaders/AfterimageShader.gdshader"
	if not ResourceLoader.exists(shader_path):
		return
	var shader = load(shader_path)
	if not shader:
		return
	shader_material = ShaderMaterial.new()
	shader_material.shader = shader
	sprite.material = shader_material

func initialize(texture: Texture2D, pos: Vector2, flip: bool, original_scale: Vector2, 
				modulate_color: Color, life_time: float,
				scale_effect: bool, solid_color: bool, cfg = null):

	reset_afterimage_force()
	
	# ⭐ 设置可见性
	visible = true
	sprite.visible = true
	
	# ⭐ 设置纹理和位置
	sprite.texture = texture
	global_position = pos
	sprite.flip_h = flip
	sprite.scale = original_scale
	
	# ⭐ 保存池配置引用
	pool_config = cfg
	lifetime = life_time  # 使用传入的生命周期
	current_time = 0.0
	
	# ⭐ 应用 Shader 参数
	_ensure_shader_material()
	if shader_material != null:
		sprite.material.set_shader_parameter("color", modulate_color)
		sprite.material.set_shader_parameter("lifetime", life_time)
		sprite.material.set_shader_parameter("scale_effect", scale_effect)
		sprite.material.set_shader_parameter("solid_color", solid_color)
		sprite.material.set_shader_parameter("elapsed_time", 0.0)
		sprite.material.set_shader_parameter("fade_duration", fade_duration)
		sprite.material.set_shader_parameter("fade_in_duration", fade_in_duration)
		# AfterimageConfig 是普通 GDScript 类实例，不能用 `"x" in obj` 这种方式判断字段是否存在。
		# 直接读取字段，确保淡出缩放开关按配置生效。
		if pool_config != null:
			sprite.material.set_shader_parameter("fade_scale_effect", pool_config.fade_scale_effect)
		else:
			sprite.material.set_shader_parameter("fade_scale_effect", true)
	else:
		push_error("[Afterimage] shader_material 为空")
		sprite.modulate = modulate_color
	
	# ⭐ 启动 Timer（使用配置的淡入淡出时间）
	if timer:
		# 生命周期 + 淡出时长，避免残影还没开始淡出就被回收
		timer.wait_time = life_time + fade_duration  # 使用外部配置的淡出时间
		timer.one_shot = true
		timer.start()
		if not timer.timeout.is_connected(_on_timer_timeout):
			timer.timeout.connect(_on_timer_timeout)
	else:
		push_error("[Afterimage] timer 节点为空")
	
	set_process(true)
	set_physics_process(false)

func _process(delta):
	if not visible:
		return
	if shader_material == null:
		return
	current_time += delta
	shader_material.set_shader_parameter("elapsed_time", current_time)

func reset_afterimage():
	if timer:
		timer.stop()
		if timer.timeout.is_connected(_on_timer_timeout):
			timer.timeout.disconnect(_on_timer_timeout)
	
	current_time = 0.0
	
	if not is_instance_valid(sprite):
		return
	
	visible = false
	sprite.texture = null
	# ⭐ 关键修复：不要清空 material，保留 ShaderMaterial 引用供下次复用
	# sprite.material = null  ← 删除这行
	global_position = Vector2.ZERO
	rotation_degrees = 0
	rotation = 0

func reset_afterimage_force():
	reset_afterimage()
	transform = Transform2D()
	z_index = 0
	z_as_relative = false
	set_process(false)
	set_physics_process(false)
	is_returning_to_pool = false

# ⭐ Shader 时间更新（已删除：完全移除 _process，由 Shader 自动计算）
# 性能优化：不再每帧调用 set_shader_parameter

# ⭐ Timer 回调（替代 Tween 完成信号）
func _on_timer_timeout():
	_on_animation_complete()

func _on_animation_complete():
	# ⭐ 动画完成（lifetime 结束），开始回收
	# 此时 Shader 已经播放完淡出效果（如果 fade_duration > 0）
	return_to_pool()

func hide_afterimage():
	visible = false
	if not is_returning_to_pool:
		return_to_pool()

func return_to_pool():
	# 优先回收到本地池，保证与具体使用者低耦合
	if pool_ref != null and pool_ref.has_method("return_to_pool"):
		pool_ref.return_to_pool(self)
		return
	# 无池引用时兜底隐藏，避免卡死在场景里
	reset_afterimage_force()
	visible = false
