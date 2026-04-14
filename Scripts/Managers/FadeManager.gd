extends CanvasLayer

@onready var fade_rect = $ColorRect

@export_category("UI 场景切换参数（普通）")
## 普通 UI 切场：淡出时长（秒）
@export var ui_switch_fade_out_duration: float = 0.2
## 普通 UI 切场：全黑保持时长（秒）
@export var ui_switch_black_hold_duration: float = 0.3
## 普通 UI 切场：淡入时长（秒）
@export var ui_switch_fade_in_duration: float = 0.2

@export_category("UI 场景切换参数（SaveSelect 进入游戏）")
## SaveSelect -> Game：淡出时长（秒）
@export var ui_save_to_game_fade_out_duration: float = 0.6
## SaveSelect -> Game：全黑保持时长（秒）
@export var ui_save_to_game_black_hold_duration: float = 0.6
## SaveSelect -> Game：淡入时长（秒）
@export var ui_save_to_game_fade_in_duration: float = 0.6

@export_category("UI 页面内过渡（非切场）")
## UI 页面内部的常规淡入淡出时长（秒）
@export var ui_overlay_fade_duration: float = 0.4
## UI 页面内部的快速淡入淡出时长（秒）
@export var ui_overlay_fast_fade_duration: float = 0.2

signal fade_out_completed
signal fade_in_completed

var _fade_tween: Tween = null

func _ready():
	# 设置整个CanvasLayer的暂停模式
	# 在Godot 4.5.1中，正确的常量名是PROCESS_MODE_ALWAYS
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	fade_rect.size = get_viewport().size
	fade_rect.color = Color(0, 0, 0, 0)
	fade_rect.visible = false
	layer = 1000
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

func fade_out(duration: float):
	var safe_duration: float = clampf(duration, 0.0, 2.0)
	_stop_active_fade_tween()
	fade_rect.visible = true
	
	_fade_tween = create_tween()
	_fade_tween.tween_property(fade_rect, "color", Color(0.0, 0.0, 0.0, 1.0), safe_duration)
	
	await _fade_tween.finished
	fade_out_completed.emit()

func fade_in(duration: float):
	var safe_duration: float = clampf(duration, 0.0, 2.0)
	_stop_active_fade_tween()
	
	_fade_tween = create_tween()
	_fade_tween.tween_property(fade_rect, "color", Color(0, 0, 0, 0), safe_duration)
	
	await _fade_tween.finished
	fade_rect.visible = false
	fade_in_completed.emit()

func force_fade_in():
	_stop_active_fade_tween()
	fade_rect.color = Color(0, 0, 0, 0)
	fade_rect.visible = false

func _stop_active_fade_tween() -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = null

func get_black_alpha() -> float:
	if not is_instance_valid(fade_rect):
		return 0.0
	return clampf(fade_rect.color.a, 0.0, 1.0)

func is_fully_black(threshold: float = 0.995) -> bool:
	if not is_instance_valid(fade_rect):
		return false
	return fade_rect.visible and get_black_alpha() >= clampf(threshold, 0.0, 1.0)
