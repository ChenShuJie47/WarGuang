extends Node
## 统一相机抖动管理器
## 支持多抖动源叠加，可被任何对象调用

## 预设类型说明：
## - y_strong: Y 轴强抖动
## - y_weak: Y 轴弱抖动
## - x_strong: X 轴强抖动
## - x_weak: X 轴弱抖动
## - general_strong: 全方位强抖动
## - general_moderate: 全方位中抖动
## - general_weak: 全方位弱抖动
## 应用位置：
## - Player.gd: 撞墙（x_strong）、落地（y_strong）、受伤（general_weak/general_moderate）
## - JumpBox.gd: JumpBox 触发（y_weak）
## - MovingJumpBox.gd: 移动 JumpBox 触发（y_weak）
## - JumpPlatform.gd: 弹跳平台触发（y_weak）
## - ChallengeJumpBox.gd: 挑战 JumpBox 触发（y_weak）

## ==================== 预设配置（在 Inspector 中修改）====================

@export_category("Y 轴强抖动（垂直方向）")
## Y 轴强抖动 - Y 轴抖动强度（像素）
@export var shake_y_strong_intensity: float = 60.0
## Y 轴强抖动 - X 轴抖动强度（像素）
@export var shake_y_strong_x_intensity: float = 10.0
## Y 轴强抖动 - 持续时间（秒）
@export var shake_y_strong_duration: float = 0.8
## Y 轴强抖动 - 抖动速度（Hz，越高越密集）
@export var shake_y_strong_speed: float = 6.0
## Y 轴强抖动 - 衰减类型：0=线性，1=快速，2=缓慢
@export var shake_y_strong_falloff: int = 2

@export_category("Y 轴弱抖动（垂直方向）")
## Y 轴弱抖动 - Y 轴抖动强度（像素）
@export var shake_y_weak_intensity: float = 20.0
## Y 轴弱抖动 - X 轴抖动强度（像素）
@export var shake_y_weak_x_intensity: float = 2.0
## Y 轴弱抖动 - 持续时间（秒）
@export var shake_y_weak_duration: float = 0.3
## Y 轴弱抖动 - 抖动速度（Hz，越高越密集）
@export var shake_y_weak_speed: float = 20.0
## Y 轴弱抖动 - 衰减类型：0=线性，1=快速，2=缓慢
@export var shake_y_weak_falloff: int = 1

@export_category("X 轴强抖动（水平方向）")
## X 轴强抖动 - X 轴抖动强度（像素）
@export var shake_x_strong_intensity: float = 40.0
## X 轴强抖动 - Y 轴抖动强度（像素）
@export var shake_x_strong_y_intensity: float = 10.0
## X 轴强抖动 - 持续时间（秒）
@export var shake_x_strong_duration: float = 0.6
## X 轴强抖动 - 抖动速度（Hz，越高越密集）
@export var shake_x_strong_speed: float = 8.0
## X 轴强抖动 - 衰减类型：0=线性，1=快速，2=缓慢
@export var shake_x_strong_falloff: int = 2

@export_category("X 轴弱抖动（垂直方向）")
## X 轴弱抖动 - X 轴抖动强度（像素）
@export var shake_x_weak_intensity: float = 10.0
## X 轴弱抖动 - Y 轴抖动强度（像素）
@export var shake_x_weak_y_intensity: float = 1.0
## X 轴弱抖动 - 持续时间（秒）
@export var shake_x_weak_duration: float = 0.3
## X 轴弱抖动 - 抖动速度（Hz，越高越密集）
@export var shake_x_weak_speed: float = 25.0
## X 轴弱抖动 - 衰减类型：0=线性，1=快速，2=缓慢
@export var shake_x_weak_falloff: int = 1

@export_category("全方位强抖动（通用）")
## 全方位强抖动 - X 轴抖动强度（像素）
@export var shake_general_strong_x_intensity: float = 60.0
## 全方位强抖动 - Y 轴抖动强度（像素）
@export var shake_general_strong_y_intensity: float = 60.0
## 全方位强抖动 - 持续时间（秒）
@export var shake_general_strong_duration: float = 1.5
## 全方位强抖动 - 抖动速度（Hz，越高越密集）
@export var shake_general_strong_speed: float = 5.0
## 全方位强抖动 - 衰减类型：0=线性，1=快速，2=缓慢
@export var shake_general_strong_falloff: int = 2

@export_category("全方位中抖动（通用）")
## 全方位中抖动 - X 轴抖动强度（像素）
@export var shake_general_moderate_x_intensity: float = 35.0
## 全方位中抖动 - Y 轴抖动强度（像素）
@export var shake_general_moderate_y_intensity: float = 35.0
## 全方位中抖动 - 持续时间（秒）
@export var shake_general_moderate_duration: float = 0.4
## 全方位中抖动 - 抖动速度（Hz，越高越密集）
@export var shake_general_moderate_speed: float = 10.0
## 全方位中抖动 - 衰减类型：0=线性，1=快速，2=缓慢
@export var shake_general_moderate_falloff: int = 2

@export_category("全方位弱抖动（通用）")
## 全方位弱抖动 - X 轴抖动强度（像素）
@export var shake_general_weak_x_intensity: float = 20.0
## 全方位弱抖动 - Y 轴抖动强度（像素）
@export var shake_general_weak_y_intensity: float = 20.0
## 全方位弱抖动 - 持续时间（秒）
@export var shake_general_weak_duration: float = 0.3
## 全方位弱抖动 - 抖动速度（Hz，越高越密集）
@export var shake_general_weak_speed: float = 20.0
## 全方位弱抖动 - 衰减类型：0=线性，1=快速，2=缓慢
@export var shake_general_weak_falloff: int = 0

## ==================== 内部数据结构 ====================

var _active_shakes: Dictionary = {}  # target_pcam -> Array[shake_data]
var _noise_time: float = 0.0  # 噪声时间累加器

class ShakePreset extends Resource:
	## 抖动效果预设类
	@export var intensity: float      ## 抖动强度
	@export var duration: float       ## 持续时间（秒）
	@export var frequency: float      ## 频率（Hz）
	@export var direction: Vector2    ## 抖动方向
	@export var falloff_type: int     ## 衰减类型：0=线性，1=快速，2=缓慢
	
	func _init(i: float = 10.0, d: float = 0.3, f: float = 60.0, dir: Vector2 = Vector2(1, 1), ft: int = 1):
		intensity = i
		duration = d
		frequency = f
		direction = dir
		falloff_type = ft

# ==================== 生命周期 ====================

func _ready():
	_initialize_default_presets()

func _process(delta):
	_process_active_shakes(delta)

# ==================== 公共接口 ====================

## 使用预设抖动（推荐）
## @param preset_name: 预设名称
##   - "y_strong": Y 轴强抖动
##   - "y_weak": Y 轴弱抖动
##   - "x_strong": X 轴强抖动
##   - "x_weak": X 轴弱抖动
##   - "general_strong": 全方位强抖动
##   - "general_moderate": 全方位中抖动
##   - "general_weak": 全方位弱抖动
## @param target_pcam: 目标 PhantomCamera2D 节点
func shake(preset_name: String, target_pcam: Node2D) -> void:
	var params = _get_preset_params(preset_name)
	if params.is_empty():
		push_error("CameraShakeManager: 未找到预设 '", preset_name, "'")
		return
	
	_start_shake(target_pcam, params)

## 自定义参数抖动
## @param params: 参数字典 {intensity, duration, frequency, direction, falloff_type}
## @param target_pcam: 目标 PhantomCamera2D 节点
func shake_custom(params: Dictionary, target_pcam: Node2D) -> void:
	_start_shake(target_pcam, params)

## 立即停止指定目标的抖动
func stop_shake(target_pcam: Node2D) -> void:
	if _active_shakes.has(target_pcam):
		_active_shakes.erase(target_pcam)
		if is_instance_valid(target_pcam) and target_pcam.has_node("PhantomCamera2D"):
			target_pcam.get_node("PhantomCamera2D").follow_offset = Vector2.ZERO

# ==================== 内部实现 ====================

func _initialize_default_presets():
	## 无需初始化，使用 Inspector 中的值
	## 如果 Inspector 未配置，使用 @export 的默认值
	pass

func _get_preset_params(preset_name: String) -> Dictionary:
	match preset_name:
		"y_strong":  # Y 轴强抖动
			return {
				"x_intensity": shake_y_strong_x_intensity,
				"y_intensity": shake_y_strong_intensity,
				"duration": shake_y_strong_duration,
				"speed": shake_y_strong_speed,
				"falloff_type": shake_y_strong_falloff
			}
		"y_weak":  # Y 轴弱抖动
			return {
				"x_intensity": shake_y_weak_x_intensity,
				"y_intensity": shake_y_weak_intensity,
				"duration": shake_y_weak_duration,
				"speed": shake_y_weak_speed,
				"falloff_type": shake_y_weak_falloff
			}
		"x_strong":  # X 轴强抖动
			return {
				"x_intensity": shake_x_strong_intensity,
				"y_intensity": shake_x_strong_y_intensity,
				"duration": shake_x_strong_duration,
				"speed": shake_x_strong_speed,
				"falloff_type": shake_x_strong_falloff
			}
		"x_weak":  # X 轴弱抖动
			return {
				"x_intensity": shake_x_weak_intensity,
				"y_intensity": shake_x_weak_y_intensity,
				"duration": shake_x_weak_duration,
				"speed": shake_x_weak_speed,
				"falloff_type": shake_x_weak_falloff
			}
		"general_strong":  # 全方位强抖动
			return {
				"x_intensity": shake_general_strong_x_intensity,
				"y_intensity": shake_general_strong_y_intensity,
				"duration": shake_general_strong_duration,
				"speed": shake_general_strong_speed,
				"falloff_type": shake_general_strong_falloff
			}
		"general_moderate":  # 全方位中抖动
			return {
				"x_intensity": shake_general_moderate_x_intensity,
				"y_intensity": shake_general_moderate_y_intensity,
				"duration": shake_general_moderate_duration,
				"speed": shake_general_moderate_speed,
				"falloff_type": shake_general_moderate_falloff
			}
		"general_weak":  # 全方位弱抖动
			return {
				"x_intensity": shake_general_weak_x_intensity,
				"y_intensity": shake_general_weak_y_intensity,
				"duration": shake_general_weak_duration,
				"speed": shake_general_weak_speed,
				"falloff_type": shake_general_weak_falloff
			}
		_: return {}

func _start_shake(target_pcam: Node2D, params: Dictionary) -> void:
	if not is_instance_valid(target_pcam):
		return
	
	var duration := float(params.get("duration", 0.3))
	if not is_finite(duration):
		duration = 0.3
	duration = maxf(duration, 0.001)
	
	var speed := float(params.get("speed", 10.0))
	if not is_finite(speed):
		speed = 10.0
	speed = maxf(absf(speed), 0.01)
	
	var x_intensity := float(params.get("x_intensity", 10.0))
	if not is_finite(x_intensity):
		x_intensity = 10.0
	
	var y_intensity := float(params.get("y_intensity", 10.0))
	if not is_finite(y_intensity):
		y_intensity = 10.0
	
	# 初始化数组（支持多抖动源叠加）
	if not _active_shakes.has(target_pcam):
		_active_shakes[target_pcam] = []
	
	# 添加新的抖动源 - 使用噪声实现平滑抖动
	_active_shakes[target_pcam].append({
		"x_intensity": x_intensity,
		"y_intensity": y_intensity,
		"duration": duration,
		"speed": speed,  # 噪声采样速度
		"falloff_type": params.get("falloff_type", 1),
		"timer": 0.0,
		"noise_offset_x": randf() * 1000,  # 随机噪声起始点
		"noise_offset_y": randf() * 1000
	})

func _process_active_shakes(delta):
	_noise_time += delta  # 累加噪声时间
	
	for target_pcam in _active_shakes.keys():  # 使用 .keys() 避免修改字典时出错
		if not is_instance_valid(target_pcam):
			_active_shakes.erase(target_pcam)
			continue
		
		var shakes = _active_shakes[target_pcam]
		var total_offset = Vector2.ZERO
		var has_active_shakes = false
		
		# 叠加所有活跃抖动的效果（使用噪声实现平滑）
		for shake_data in shakes:
			# 检查是否已结束
			shake_data.timer += delta
			var duration: float = maxf(float(shake_data.duration), 0.001)
			var progress: float = shake_data.timer / duration
			if not is_finite(progress):
				continue
			progress = clampf(progress, 0.0, 1.0)
			
			if progress >= 1.0:
				# 这个抖动结束了，跳过不处理
				continue
			
			has_active_shakes = true
			
			# 计算衰减因子
			var falloff_factor = _get_falloff_factor(shake_data.falloff_type, progress)
			if not is_finite(falloff_factor):
				falloff_factor = 0.0
			falloff_factor = maxf(falloff_factor, 0.0)
			
			# 使用噪声生成平滑的抖动值
			var noise_x = _noise_1d(_noise_time * shake_data.speed + shake_data.noise_offset_x)
			var noise_y = _noise_1d(_noise_time * shake_data.speed + shake_data.noise_offset_y)
			
			# 应用强度和衰减
			var current_x = noise_x * shake_data.x_intensity * falloff_factor
			var current_y = noise_y * shake_data.y_intensity * falloff_factor
			
			total_offset += Vector2(current_x, current_y)
		
		# 关键修复：直接修改 Camera2D.offset，绕过 PhantomCamera 的限制和平滑
		if has_active_shakes and is_instance_valid(target_pcam):
			var camera = _get_target_camera(target_pcam)
			if camera:
				if not total_offset.is_finite():
					total_offset = Vector2.ZERO
				camera.offset = total_offset
				if not camera.offset.is_finite():
					camera.offset = Vector2.ZERO
				# print("[CameraShake] 应用 viewport Camera2D offset:", total_offset)
		
		# 如果没有任何活跃抖动，清理这个 target
		if not has_active_shakes:
			_active_shakes.erase(target_pcam)
			# 重置 Camera2D offset
			var camera = _get_target_camera(target_pcam)
			if camera:
				camera.offset = Vector2.ZERO

func _get_falloff_factor(falloff_type: int, progress: float) -> float:
	## 衰减类型：0=线性，1=快速（二次方），2=缓慢（平方根）
	match falloff_type:
		0:  # LINEAR - 线性衰减
			return 1.0 - progress
		1:  # FAST - 快速衰减（二次方）
			return 1.0 - (progress * progress)
		2:  # SLOW - 缓慢衰减（平方根）
			return sqrt(1.0 - progress)
		_:
			return 1.0

# ==================== 工具函数 ====================

func _noise_1d(x: float) -> float:
	## 生成平滑的 1D 噪声值（范围：-1 到 1）
	## 使用 Godot 内置的 noise 函数实现平滑过渡
	var noise_value = sin(x * 2.5) * 0.5 + sin(x * 5.3) * 0.3 + sin(x * 8.7) * 0.2
	return clamp(noise_value, -1.0, 1.0)

func _get_target_camera(target_pcam: Node2D) -> Camera2D:
	if not is_instance_valid(target_pcam):
		return null
	var viewport = target_pcam.get_viewport()
	if viewport == null:
		return null
	return viewport.get_camera_2d()
