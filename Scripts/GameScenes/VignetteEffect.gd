# VignetteEffect.gd
extends CanvasLayer

## 节点引用
@onready var vignette_rect = $VignetteRect

# VignetteEffect.gd - 添加时间变量
@export_category("视觉效果时间设置")
## 普通受伤效果持续时间（秒）
@export var hurt_darkness_duration: float = 0.5
## 阴影受伤效果持续时间（秒）
@export var hurt_shadow_darkness_duration: float = 1
## 受伤效果过渡到无效果的时间（秒）
@export var hurt_to_normal_transition: float = 0.5
## 受伤效果过渡到低血量效果的时间（秒）
@export var hurt_to_low_health_transition: float = 0.5
## 低血量效果过渡到正常的时间（秒）
@export var low_health_to_normal_transition: float = 0.5

## 受伤效果设置
@export_category("受伤效果设置")
## 普通受伤效果Vignette强度 - 范围：0.0到1.0（建议：0.0-2.0）
## 0.0：无效果，1.0：完全应用颜色，>1.0：过度效果
@export var hurt_intensity: float = 1  

## 阴影受伤效果Vignette强度 - 范围：0.0到1.0（建议：0.0-2.0）
@export var shadow_hurt_intensity: float = 1.4  

## 普通受伤效果Vignette颜色
@export var hurt_color: Color = Color(0.118, 0.0, 0.0, 1.0)

## 阴影受伤效果Vignette颜色
@export var shadow_hurt_color: Color = Color(0.078, 0.0, 0.0, 1.0)

## 受伤效果内圈半径 - 范围：0.0到1.0
## 0.0：从中心开始，0.5：从屏幕一半开始，1.0：从边缘开始
@export var hurt_inner_radius: float = 0  

## 受伤效果外圈半径 - 范围：0.0到1.0
## 必须大于inner_radius，控制效果结束位置
@export var hurt_outer_radius: float = 1  

## 受伤效果脉冲速度 - 范围：0.0到0.1（建议：0.001-0.05）
## 值越大脉冲越快
@export var hurt_pulse_speed: float = 0.01  

## 受伤效果脉冲幅度 - 范围：0.0到1.0（建议：0.0-0.5）
## 值越大脉冲变化幅度越大
@export var hurt_pulse_amount: float = 0.1  

## 低血量效果设置
@export_category("低血量效果设置")
## 低血量效果Vignette强度 - 范围：0.0到1.0（建议：0.0-2.0）
@export var low_health_intensity: float = 0.6  

## 低血量效果Vignette颜色
@export var low_health_color: Color = Color(0.157, 0.0, 0.0, 1.0)

## 低血量效果内圈半径 - 范围：0.0到1.0
## 0.0：从中心开始，0.5：从屏幕一半开始，1.0：从边缘开始
@export var low_health_inner_radius: float = 0

## 低血量效果外圈半径 - 范围：0.0到1.0
## 必须大于inner_radius，控制效果结束位置
@export var low_health_outer_radius: float = 1

# 内部变量
var current_effect: String = ""  ## 当前效果类型："hurt", "shadow_hurt", "low_health", ""
var effect_timer: float = 0.0    ## 效果计时器
var effect_duration: float = 0.0 ## 效果总持续时间
var is_transitioning: bool = false  ## 是否正在过渡
var transition_tween: Tween = null  ## 过渡Tween

func _ready():
	# 添加到组
	add_to_group("vignette_effect")
	
	# 确保在屏幕最上层
	layer = 1000
	
	# 关键：先隐藏，等Shader准备好再显示
	visible = false
	
	# 等待一帧确保ShaderMaterial加载完成
	await get_tree().process_frame
	
	# 初始化Shader参数
	set_shader_param("intensity", 0.0)
	set_shader_param("color", Color(0.0, 0.0, 0.0, 1.0))
	set_shader_param("inner_radius", 0.3)
	set_shader_param("outer_radius", 0.8)
	
	# 设置ColorRect为完全透明
	vignette_rect.color = Color(0, 0, 0, 0)
	vignette_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# 现在可以显示
	visible = true
	
	print("VignetteEffect: 已初始化，Shader参数已设置")

func _process(delta):
	if effect_timer > 0:
		effect_timer -= delta
		
		## 受伤效果：脉冲效果
		if current_effect == "hurt" or current_effect == "shadow_hurt":
			var pulse = sin(Time.get_ticks_msec() * hurt_pulse_speed) * hurt_pulse_amount
			var base_intensity = hurt_intensity if current_effect == "hurt" else shadow_hurt_intensity
			set_shader_param("intensity", base_intensity + pulse)
			
			if effect_timer <= 0 and not is_transitioning:
				## 受伤效果持续时间结束，根据玩家血量决定下一步
				_on_hurt_duration_end()
		
		## 低血量效果：持续保持
		elif current_effect == "low_health":
			set_shader_param("intensity", low_health_intensity)

func set_shader_param(param_name: String, value):
	if vignette_rect.material:
		vignette_rect.material.set_shader_parameter(param_name, value)

func get_shader_param(param_name: String):
	if vignette_rect.material:
		return vignette_rect.material.get_shader_parameter(param_name)
	return 0.0

## 开始普通受伤效果
func start_hurt_effect(duration: float):
	current_effect = "hurt"
	effect_duration = duration
	effect_timer = duration
	is_transitioning = false
	visible = true
	
	set_shader_param("color", hurt_color)
	set_shader_param("intensity", hurt_intensity)
	set_shader_param("inner_radius", hurt_inner_radius)
	set_shader_param("outer_radius", hurt_outer_radius)

## 开始阴影受伤效果
func start_shadow_hurt_effect(duration: float):
	current_effect = "shadow_hurt"
	effect_duration = duration
	effect_timer = duration
	is_transitioning = false
	visible = true
	
	set_shader_param("color", shadow_hurt_color)
	set_shader_param("intensity", shadow_hurt_intensity)
	set_shader_param("inner_radius", hurt_inner_radius)
	set_shader_param("outer_radius", hurt_outer_radius)

## 受伤效果结束后，如果需要进入低血量效果，先完成受伤效果再过渡
func transition_hurt_to_low_health(transition_time: float):
	if current_effect != "hurt":
		print("错误：当前不是受伤效果，无法过渡到低血量")
		return
	
	is_transitioning = true
	
	# 停止任何正在进行的Tween
	if transition_tween and transition_tween.is_valid():
		transition_tween.kill()
	
	# 从受伤效果参数过渡到低血量效果参数
	var start_intensity = get_shader_param("intensity")
	var start_color = get_shader_param("color")
	var start_inner_radius = get_shader_param("inner_radius")
	var start_outer_radius = get_shader_param("outer_radius")
	
	transition_tween = create_tween()
	
	# 并行过渡所有参数
	transition_tween.parallel().tween_method(_set_intensity_with_callback, 
		start_intensity, low_health_intensity, transition_time)
	transition_tween.parallel().tween_method(_set_color_with_callback, 
		start_color, low_health_color, transition_time)
	transition_tween.parallel().tween_method(_set_inner_radius_with_callback, 
		start_inner_radius, low_health_inner_radius, transition_time)
	transition_tween.parallel().tween_method(_set_outer_radius_with_callback, 
		start_outer_radius, low_health_outer_radius, transition_time)
	
	transition_tween.tween_callback(func():
		current_effect = "low_health"
		effect_timer = 999999.0  # 持续
		is_transitioning = false
	)

## 开始低血量效果
func start_low_health_effect():
	current_effect = "low_health"
	effect_timer = 999999.0  ## 非常大的值，表示持续
	is_transitioning = false
	visible = true
	
	set_shader_param("color", low_health_color)
	set_shader_param("intensity", low_health_intensity)
	set_shader_param("inner_radius", low_health_inner_radius)
	set_shader_param("outer_radius", low_health_outer_radius)

## 受伤效果持续时间结束后的处理
func _on_hurt_duration_end():
	## 由Player脚本控制下一步，这里不做自动处理
	pass

## 过渡到无效果（完全清除）
func transition_to_normal(duration: float):
	if is_transitioning:
		return
	
	is_transitioning = true
	current_effect = ""
	
	## 停止任何正在进行的Tween
	if transition_tween and transition_tween.is_valid():
		transition_tween.kill()
	
	transition_tween = create_tween()
	transition_tween.tween_method(_set_intensity_with_callback, get_shader_param("intensity"), 0.0, duration)
	transition_tween.tween_callback(func():
		visible = false
		is_transitioning = false
	)

## 过渡到低血量效果
func transition_to_low_health(duration: float):
	if is_transitioning:
		return
	
	is_transitioning = true
	
	## 保存当前参数作为过渡起始值
	var start_intensity = get_shader_param("intensity")
	var start_color = get_shader_param("color")
	var start_inner_radius = get_shader_param("inner_radius")
	var start_outer_radius = get_shader_param("outer_radius")
	
	## 停止任何正在进行的Tween
	if transition_tween and transition_tween.is_valid():
		transition_tween.kill()
	
	transition_tween = create_tween()
	
	## 并行过渡所有参数
	transition_tween.parallel().tween_method(_set_intensity_with_callback, start_intensity, low_health_intensity, duration)
	transition_tween.parallel().tween_method(_set_color_with_callback, start_color, low_health_color, duration)
	transition_tween.parallel().tween_method(_set_inner_radius_with_callback, start_inner_radius, low_health_inner_radius, duration)
	transition_tween.parallel().tween_method(_set_outer_radius_with_callback, start_outer_radius, low_health_outer_radius, duration)
	
	transition_tween.tween_callback(func():
		current_effect = "low_health"
		effect_timer = 999999.0  ## 持续
		is_transitioning = false
	)

## 从低血量效果过渡到正常
func transition_low_health_to_normal(duration: float):
	if is_transitioning or current_effect != "low_health":
		return
	
	is_transitioning = true
	
	var start_intensity = get_shader_param("intensity")
	
	## 停止任何正在进行的Tween
	if transition_tween and transition_tween.is_valid():
		transition_tween.kill()
	
	transition_tween = create_tween()
	transition_tween.tween_method(_set_intensity_with_callback, start_intensity, 0.0, duration)
	transition_tween.tween_callback(func():
		current_effect = ""
		visible = false
		is_transitioning = false
	)

## 立即清除所有效果
func clear_all_effects():
	current_effect = ""
	effect_timer = 0.0
	visible = false
	set_shader_param("intensity", 0.0)

## 只清除受伤效果（保留低血量效果）
func clear_hurt_effect_only():
	if current_effect == "hurt" or current_effect == "shadow_hurt":
		# 如果是受伤效果，清除它
		current_effect = ""
		effect_timer = 0
		
		# 淡出效果
		var tween = create_tween()
		tween.tween_method(_set_intensity_with_callback, get_shader_param("intensity"), 0.0, 0.3)
		tween.tween_callback(func():
			if current_effect == "":
				visible = false
		)

## 房间切换时的特殊处理
func on_room_changed():
	# 如果当前是低血量效果，保持它
	if current_effect == "low_health":
		# 确保低血量效果参数正确
		set_shader_param("color", low_health_color)
		set_shader_param("intensity", low_health_intensity)
		set_shader_param("inner_radius", low_health_inner_radius)
		set_shader_param("outer_radius", low_health_outer_radius)
		visible = true
	elif current_effect == "hurt" or current_effect == "shadow_hurt":
		# 房间切换时清除受伤效果
		clear_all_effects()

## 带回调的设置方法（供Tween使用）
func _set_intensity_with_callback(value: float):
	set_shader_param("intensity", value)

func _set_color_with_callback(value: Color):
	set_shader_param("color", value)

func _set_inner_radius_with_callback(value: float):
	set_shader_param("inner_radius", value)

func _set_outer_radius_with_callback(value: float):
	set_shader_param("outer_radius", value)
