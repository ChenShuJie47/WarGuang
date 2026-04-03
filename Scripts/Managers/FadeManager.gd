extends CanvasLayer

@onready var fade_rect = $ColorRect

signal fade_out_completed
signal fade_in_completed

func _ready():
	# 设置整个CanvasLayer的暂停模式
	# 在Godot 4.5.1中，正确的常量名是PROCESS_MODE_ALWAYS
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	fade_rect.size = get_viewport().size
	fade_rect.color = Color(0, 0, 0, 0)
	fade_rect.visible = false
	layer = 100
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

func fade_out(duration: float):
	var safe_duration = min(duration, 2.0)
	fade_rect.visible = true
	
	var tween = create_tween()
	tween.tween_property(fade_rect, "color", Color(0, 0, 0, 1), safe_duration)
	
	await tween.finished
	fade_out_completed.emit()

func fade_in(duration: float):
	var safe_duration = min(duration, 2.0)
	
	var tween = create_tween()
	tween.tween_property(fade_rect, "color", Color(0, 0, 0, 0), safe_duration)
	
	await tween.finished
	fade_rect.visible = false
	fade_in_completed.emit()

func force_fade_in():
	fade_rect.color = Color(0, 0, 0, 0)
	fade_rect.visible = false
