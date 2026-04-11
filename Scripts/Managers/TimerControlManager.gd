extends Node
## 统一时间控制管理器
## 统一管理 Hit Stop（时间暂停）和 Slow Motion（慢动作）效果
## 
## Hit Stop 预设类型说明：
## - tier1: 极短暂停
## - tier2: 短暂停
## - tier3: 中等暂停
## - tier4: 长时间暂停
##
## Hit Stop 应用位置：
## - Player.gd: JumpBox Hit Stop（tier2）、受伤 Hit Stop（tier2）
##
## Slow Motion 预设类型说明：
## - light: 轻度慢动作
## - medium: 中度慢动作
## - heavy: 重度慢动作
## - extreme: 极限慢动作
##
## Slow Motion 应用位置：
## - Player.gd: 死亡动画（medium）
##
## ==================== 时间计算说明 ====================
## Hit Stop：
##   - 持续时间 = 现实世界的时间（不受 time_scale 影响）
##   - 例如：0.2s Hit Stop = 现实暂停 0.2 秒，游戏内也过了 0.2 秒
##
## Slow Motion：
##   - 持续时间 = 游戏内感受到的时间（已考虑放缓）
##   - 例如：1.0s @ 0.5x = 游戏内播放 1 秒内容，现实需要 2 秒
##   - 计算公式：现实时间 = 游戏内时间 / time_scale
##
## ==================== 帧率独立性 ====================
## - 使用 Time.get_unix_time_from_system() 确保不同帧率下体验一致
## - 60 FPS / 144 FPS / 240 FPS 下的持续时间完全相同

## ==================== Hit Stop 预设配置 ====================

@export_category("Hit Stop 预设")
## Tier 1 - 极短暂停（秒）
@export var hit_stop_tier1_duration: float = 0.1
## Tier 2 - 短暂停（秒）
@export var hit_stop_tier2_duration: float = 0.2
## Tier 3 - 中等暂停（秒）
@export var hit_stop_tier3_duration: float = 0.35
## Tier 4 - 长时间暂停（秒）
@export var hit_stop_tier4_duration: float = 1.0

## ==================== Slow Motion 预设配置 ====================

@export_category("Slow Motion 预设 （light）")
## 轻度慢动作 - 持续时间（秒）
@export var slow_light_duration: float = 0.4
## 轻度慢动作 - 时间缩放（0.0-1.0，越小越慢）
@export var slow_light_time_scale: float = 0.75
## 轻度慢动作 - 过渡时间（秒）
@export var slow_light_transition: float = 0.1

@export_category("Slow Motion 预设 （medium）")
## 中度慢动作 - 持续时间（秒）
@export var slow_medium_duration: float = 0.8
## 中度慢动作 - 时间缩放（0.0-1.0，越小越慢）
@export var slow_medium_time_scale: float = 0.5
## 中度慢动作 - 过渡时间（秒）
@export var slow_medium_transition: float = 0.25

@export_category("Slow Motion 预设 （heavy）")
## 重度慢动作 - 持续时间（秒）
@export var slow_heavy_duration: float = 0.8
## 重度慢动作 - 时间缩放（0.0-1.0，越小越慢）
@export var slow_heavy_time_scale: float = 0.3
## 重度慢动作 - 过渡时间（秒）
@export var slow_heavy_transition: float = 0.3

@export_category("Slow Motion 预设 （extreme）")
## 极限慢动作 - 持续时间（秒）
@export var slow_extreme_duration: float = 1.0
## 极限慢动作 - 时间缩放（0.0-1.0，越小越慢）
@export var slow_extreme_time_scale: float = 0.2
## 极限慢动作 - 过渡时间（秒）
@export var slow_extreme_transition: float = 0.5

## ==================== 内部数据结构 ====================

var _is_hit_stop_active: bool = false          # Hit Stop 是否激活
var _hit_stop_duration: float = 0.0            # Hit Stop 持续时间（现实时间）
var _hit_stop_end_time: float = 0.0            # Hit Stop 结束时间戳（Unix 时间）
var _saved_time_scale_for_hit_stop: float = 1.0  # 保存的原始时间缩放（Hit Stop 用）

var _is_slow_motion_active: bool = false       # Slow Motion 是否激活
var _slow_motion_duration: float = 0.0         # Slow Motion 持续时间（游戏内时间）
var _slow_motion_end_time: float = 0.0         # Slow Motion 结束时间戳（考虑缩放）
var _slow_motion_target_scale: float = 1.0     # 目标时间缩放
var _slow_motion_transition: float = 0.0       # 过渡时间（游戏内时间）
var _saved_time_scale_for_slow: float = 1.0    # 保存的原始时间缩放（Slow Motion 用）

# ==================== 生命周期 ====================

func _ready():
	pass

func _process(delta):
	_process_hit_stop(delta)
	_process_slow_motion(delta)

# ==================== Hit Stop 公共接口 ====================

## 使用预设档位触发 Hit Stop
## @param tier: 档位 (1-4)
func hit_stop(tier: int) -> void:
	match tier:
		1: start_hit_stop(hit_stop_tier1_duration)
		2: start_hit_stop(hit_stop_tier2_duration)
		3: start_hit_stop(hit_stop_tier3_duration)
		4: start_hit_stop(hit_stop_tier4_duration)
		_: push_error("TimerControlManager: 无效的 Hit Stop 档位 ", tier)

## 自定义参数 Hit Stop
## @param duration: 持续时间（秒，现实时间）
func start_hit_stop(duration: float) -> void:
	if _is_hit_stop_active or _is_slow_motion_active:
		return
	
	_is_hit_stop_active = true
	_hit_stop_duration = duration
	_saved_time_scale_for_hit_stop = Engine.time_scale
	_hit_stop_end_time = Time.get_unix_time_from_system() + duration  # 使用真实时间
	Engine.time_scale = 0.0  # 时间暂停

# ==================== Slow Motion 公共接口 ====================

## 使用预设档位触发 Slow Motion
## @param preset: 预设名称 ("light", "medium", "heavy", "extreme")
func slow_motion(preset: String) -> void:
	match preset:
		"light":
			start_slow_motion(slow_light_duration, slow_light_time_scale, slow_light_transition)
		"medium":
			start_slow_motion(slow_medium_duration, slow_medium_time_scale, slow_medium_transition)
		"heavy":
			start_slow_motion(slow_heavy_duration, slow_heavy_time_scale, slow_heavy_transition)
		"extreme":
			start_slow_motion(slow_extreme_duration, slow_extreme_time_scale, slow_extreme_transition)
		_: push_error("TimerControlManager: 无效的慢动作预设 ", preset)

## 自定义参数 Slow Motion
## @param duration: 持续时间（秒，游戏内时间）
## @param time_scale: 时间缩放（0.0-1.0，越小越慢）
## @param transition: 过渡时间（秒，游戏内时间）
func start_slow_motion(duration: float, time_scale: float, transition: float) -> void:
	if _is_slow_motion_active or _is_hit_stop_active:
		return
	
	_is_slow_motion_active = true
	_slow_motion_duration = duration
	_slow_motion_target_scale = time_scale
	_slow_motion_transition = transition
	_saved_time_scale_for_slow = Engine.time_scale
	
	# 计算结束时间（现实时间 = 游戏内时间 / time_scale）
	var real_time_duration = (duration + transition) / time_scale
	_slow_motion_end_time = Time.get_unix_time_from_system() + real_time_duration
	
	# 开始平滑过渡
	var tween = create_tween()
	tween.tween_method(
		func(value): Engine.time_scale = value,
		Engine.time_scale,
		time_scale,
		transition
	).set_trans(Tween.TRANS_SINE)

## 立即停止 Slow Motion，恢复到正常时间流速
func stop_slow_motion() -> void:
	if not _is_slow_motion_active:
		return
	
	_is_slow_motion_active = false
	
	# 平滑恢复到正常时间流速
	var tween = create_tween()
	tween.tween_method(
		func(value): Engine.time_scale = value,
		Engine.time_scale,
		1.0,
		0.2
	).set_trans(Tween.TRANS_SINE)

# ==================== 内部实现 ====================

func _process_hit_stop(_delta):
	if not _is_hit_stop_active:
		return
	
	# 使用真实时间检查（不受 time_scale 影响）
	var current_time = Time.get_unix_time_from_system()
	if current_time >= _hit_stop_end_time:
		# Hit Stop 结束，恢复原始时间流速
		Engine.time_scale = _saved_time_scale_for_hit_stop
		_is_hit_stop_active = false

func _process_slow_motion(_delta):
	if not _is_slow_motion_active:
		return
	
	# 使用真实时间检查
	var current_time = Time.get_unix_time_from_system()
	if current_time >= _slow_motion_end_time:
		stop_slow_motion()
