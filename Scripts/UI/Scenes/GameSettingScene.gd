extends CanvasLayer

## 设置界面场景（在 Inspector 中拖拽 SettingsScene.tscn）
@export var settings_scene_resource: PackedScene

@onready var continue_button = $ContinueButton
@onready var settings_button = $SettingsButton
@onready var main_menu_button = $MainMenuButton

signal menu_closed

@export var darken_multiplier: float = 0.3
@export var transition_duration: float = 0.1

@export_category("GameSetting 开关动画")
## 入场峰值缩放倍率
@export var open_peak_scale_multiplier: float = 1.2
## 入场放大阶段时长（秒）
@export var open_peak_duration: float = 0.2
## 入场峰值停顿时长（秒）
@export var open_peak_hold_duration: float = 0.15
## 入场回落阶段时长（秒）
@export var open_settle_duration: float = 0.18
## 关闭峰值缩放倍率
@export var close_peak_scale_multiplier: float = 1.2
## 关闭放大阶段时长（秒）
@export var close_peak_duration: float = 0.14
## 关闭峰值停顿时长（秒）
@export var close_peak_hold_duration: float = 0.1
## 关闭消失阶段时长（秒）
@export var close_vanish_duration: float = 0.22
## 关闭最小缩放倍率
@export var close_min_scale_multiplier: float = 0.02
## 入场位移距离（像素）
@export var open_drift_distance: float = 16.0
## 退场位移距离（像素）
@export var close_drift_distance: float = 16.0

var original_modulate_color: Color
var game_canvas_modulate: CanvasModulate
var is_open: bool = false
var settings_instance: Node = null
var _base_visual_scales: Dictionary = {}
var _base_visual_positions: Dictionary = {}
var _base_visual_modulates: Dictionary = {}
var _is_closing: bool = false


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	continue_button.pressed.connect(_on_continue_button_pressed)
	settings_button.pressed.connect(_on_settings_button_pressed)
	main_menu_button.pressed.connect(_on_main_menu_button_pressed)
	
	layer = 100  # 直接使用内置的 layer 属性
	
	get_tree().paused = true
	is_open = true
	
	# 关键修复：显示黑色遮罩层
	DarkOverlay.show_overlay()
	# 关键修复：如果对话框存在，暂时隐藏它
	var balloon = get_node_or_null("/root/MyBalloon")
	if balloon:
		balloon.visible = false
	
	if continue_button is Control:
		continue_button.grab_focus()

	_cache_visual_base_scales()
	_set_menu_buttons_enabled(false)
	await _play_open_animation()
	_set_menu_buttons_enabled(true)

func _close_menu():
	get_tree().paused = false
	is_open = false
	
	if continue_button is Control:
		continue_button.grab_focus()
	
	FadeManager.fade_in(FadeManager.ui_overlay_fade_duration)
	
	if game_canvas_modulate and is_instance_valid(game_canvas_modulate):
		var target_color = Color(
			original_modulate_color.r,
			original_modulate_color.g,
			original_modulate_color.b,
			1.0
		)
		
		game_canvas_modulate.color = target_color

func _adjust_game_lighting():
	if RoomManager and RoomManager.global_canvas_modulate:
		game_canvas_modulate = RoomManager.global_canvas_modulate
		
		original_modulate_color = game_canvas_modulate.color
		
		var target_color = Color(
			original_modulate_color.r * darken_multiplier,
			original_modulate_color.g * darken_multiplier,
			original_modulate_color.b * darken_multiplier,
			1.0
		)
		
		game_canvas_modulate.color = target_color
	else:
		print("GameSettingScene: 错误: 无法获取CanvasModulate")

func _restore_game_lighting():
	if game_canvas_modulate and is_instance_valid(game_canvas_modulate):
		var tween = create_tween()
		tween.tween_property(game_canvas_modulate, "color", original_modulate_color, transition_duration)
		
		await tween.finished
	else:
		print("GameSettingScene: 无法恢复光照")

func _close_game_setting():
	if not is_open or _is_closing:
		return

	_is_closing = true
	is_open = false
	_set_menu_buttons_enabled(false)
	await _play_close_animation()
	DarkOverlay.hide_overlay()
	get_tree().paused = false
	menu_closed.emit()
	queue_free()

func _on_continue_button_pressed():
	if not continue_button or continue_button.disabled:
		return
	await _close_game_setting()

func _on_settings_button_pressed():
	if not is_open or settings_instance:
		return
	
	continue_button.disabled = true
	settings_button.disabled = true
	main_menu_button.disabled = true
	
	# 修复：使用@export 的资源而不是 preload
	if not settings_scene_resource:
		push_error("GameSettingScene: settings_scene_resource 未配置！")
		return
	
	settings_instance = settings_scene_resource.instantiate()
	settings_instance.setup("GameSettingScene", self)
	
	settings_instance.layer = layer + 1
	
	get_tree().root.add_child(settings_instance)
	if settings_instance.has_method("_on_scene_transition_enter_begin"):
		settings_instance._on_scene_transition_enter_begin()

func _on_settings_closed(settings_scene: Node = null):
	if settings_scene and is_instance_valid(settings_scene):
		settings_scene.queue_free()
	settings_instance = null
	
	continue_button.disabled = false
	settings_button.disabled = false
	main_menu_button.disabled = false
	
	if continue_button is Control:
		continue_button.grab_focus()
	
	FadeManager.fade_in(FadeManager.ui_overlay_fade_duration)
	
	if game_canvas_modulate and is_instance_valid(game_canvas_modulate):
		var target_color = Color(
			original_modulate_color.r * darken_multiplier,
			original_modulate_color.g * darken_multiplier,
			original_modulate_color.b * darken_multiplier,
			1.0
		)
		game_canvas_modulate.color = target_color

func _on_main_menu_button_pressed():
	AudioManager.play_sfx("button_click")
	
	if not is_open or _is_closing:
		return

	_is_closing = true
	is_open = false
	
	# 确保关闭任何打开的对话框
	var balloon = get_node_or_null("/root/MyBalloon")
	if balloon:
		balloon.visible = false
		if balloon.has_method("end_dialogue"):
			balloon.end_dialogue()
	
	# 确保 DialogueManager 插件的弹窗被关闭
	if DialogueManager and DialogueManager.has_method("hide_balloon"):
		DialogueManager.hide_balloon()
	
	if Global.current_save_slot >= 0:
		SaveManager.save_game(Global.current_save_slot, Global.get_save_data())

	get_tree().paused = false
	_set_menu_buttons_enabled(false)
	await _play_close_animation()
	await FadeManager.fade_out(FadeManager.ui_switch_fade_out_duration)
	DarkOverlay.hide_overlay()
	queue_free()
	await SceneManager.return_to_title_from_game_setting(true)

func _input(event):
	if event.is_action_pressed("ui_cancel") and is_open:
		if settings_instance:
			return
		else:
			await _close_game_setting()
			get_viewport().set_input_as_handled()

func _exit_tree():
	if is_open:
		is_open = false
		get_tree().paused = false
		_restore_game_lighting()

func _open_settings_menu():
	if not settings_scene_resource:
		push_error("GameSettingScene: settings_scene_resource 未配置！请在 Inspector 中拖拽 SettingsScene.tscn")
		return
	
	settings_button.disabled = true
	main_menu_button.disabled = true
	
	settings_instance = settings_scene_resource.instantiate()
	settings_instance.setup("GameSettingScene", self)
	
	settings_instance.layer = layer + 1
	
	get_tree().root.add_child(settings_instance)

func _cache_visual_base_scales() -> void:
	_base_visual_scales.clear()
	_base_visual_positions.clear()
	_base_visual_modulates.clear()
	_base_visual_scales["Background"] = $Background.scale
	_base_visual_scales["ContinueButton"] = $ContinueButton.scale
	_base_visual_scales["SettingsButton"] = $SettingsButton.scale
	_base_visual_scales["MainMenuButton"] = $MainMenuButton.scale
	_base_visual_positions["Background"] = $Background.position
	_base_visual_positions["ContinueButton"] = $ContinueButton.position
	_base_visual_positions["SettingsButton"] = $SettingsButton.position
	_base_visual_positions["MainMenuButton"] = $MainMenuButton.position
	_base_visual_modulates["Background"] = $Background.modulate
	_base_visual_modulates["ContinueButton"] = $ContinueButton.modulate
	_base_visual_modulates["SettingsButton"] = $SettingsButton.modulate
	_base_visual_modulates["MainMenuButton"] = $MainMenuButton.modulate

func _set_menu_buttons_enabled(enabled: bool) -> void:
	continue_button.disabled = not enabled
	settings_button.disabled = not enabled
	main_menu_button.disabled = not enabled

func _for_each_visual_node(callback: Callable) -> void:
	for node_name in ["Background", "ContinueButton", "SettingsButton", "MainMenuButton"]:
		var node = get_node_or_null(node_name)
		if node and node is CanvasItem:
			callback.call(node_name, node)

func _play_open_animation():
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	_for_each_visual_node(func(node_name: String, node: CanvasItem):
		var base_scale: Vector2 = _base_visual_scales.get(node_name, node.scale)
		var base_position: Vector2 = _base_visual_positions.get(node_name, node.position)
		var base_modulate: Color = _base_visual_modulates.get(node_name, node.modulate)
		node.scale = base_scale * close_min_scale_multiplier
		node.position = Vector2(base_position.x, base_position.y + open_drift_distance)
		node.modulate = Color(base_modulate.r, base_modulate.g, base_modulate.b, 0.0)
	)

	_for_each_visual_node(func(node_name: String, node: CanvasItem):
		var base_scale: Vector2 = _base_visual_scales.get(node_name, node.scale)
		var base_modulate: Color = _base_visual_modulates.get(node_name, node.modulate)
		tween.parallel().tween_property(node, "scale", base_scale * open_peak_scale_multiplier, open_peak_duration)
		tween.parallel().tween_property(node, "modulate:a", base_modulate.a, open_peak_duration)
	)

	if open_peak_hold_duration > 0.0:
		tween.chain().tween_interval(open_peak_hold_duration)

	tween.chain()
	_for_each_visual_node(func(node_name: String, node: CanvasItem):
		var base_scale: Vector2 = _base_visual_scales.get(node_name, node.scale)
		var base_position: Vector2 = _base_visual_positions.get(node_name, node.position)
		var base_modulate: Color = _base_visual_modulates.get(node_name, node.modulate)
		tween.parallel().tween_property(node, "scale", base_scale, open_settle_duration)
		tween.parallel().tween_property(node, "position:y", base_position.y, open_settle_duration)
		tween.parallel().tween_property(node, "modulate:a", base_modulate.a, open_settle_duration)
	)

	await tween.finished

func _play_close_animation():
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN)

	_for_each_visual_node(func(node_name: String, node: CanvasItem):
		var base_scale: Vector2 = _base_visual_scales.get(node_name, node.scale)
		tween.parallel().tween_property(node, "scale", base_scale * close_peak_scale_multiplier, close_peak_duration)
	)

	if close_peak_hold_duration > 0.0:
		tween.chain().tween_interval(close_peak_hold_duration)

	tween.chain()
	_for_each_visual_node(func(node_name: String, node: CanvasItem):
		var base_scale: Vector2 = _base_visual_scales.get(node_name, node.scale)
		var base_position: Vector2 = _base_visual_positions.get(node_name, node.position)
		tween.parallel().tween_property(node, "scale", base_scale * close_min_scale_multiplier, close_vanish_duration)
		tween.parallel().tween_property(node, "position:y", base_position.y + close_drift_distance, close_vanish_duration)
		tween.parallel().tween_property(node, "modulate:a", 0.0, close_vanish_duration)
	)

	await tween.finished
