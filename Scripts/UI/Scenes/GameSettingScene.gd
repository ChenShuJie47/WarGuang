extends CanvasLayer

## 设置界面场景（在 Inspector 中拖拽 SettingsScene.tscn）
@export var settings_scene_resource: PackedScene

@onready var continue_button = $ContinueButton
@onready var settings_button = $SettingsButton
@onready var main_menu_button = $MainMenuButton

signal menu_closed

@export var darken_multiplier: float = 0.3
@export var transition_duration: float = 0.1

var original_modulate_color: Color
var game_canvas_modulate: CanvasModulate
var is_open: bool = false
var settings_instance: Node = null


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
	
	# 不再需要单独调整游戏场景亮度
	# _adjust_game_lighting()

func _close_menu():
	get_tree().paused = false
	is_open = false
	
	## 关键修改：隐藏黑色遮罩层
	#if DarkOverlay:
		#DarkOverlay.hide_overlay()
		#print("DEBUG GameSettingScene: 已隐藏遮罩层")
	
	if continue_button is Control:
		continue_button.grab_focus()
	
	FadeManager.fade_in(0.15)
	
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
	if not is_open:
		return
	
	is_open = false
	
	# 关键修复：隐藏黑色遮罩层
	DarkOverlay.hide_overlay()
	print("DEBUG GameSettingScene: 已隐藏遮罩层")
	
	get_tree().paused = false
	menu_closed.emit()
	queue_free()

func _on_continue_button_pressed():
	_close_game_setting()

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

func _on_settings_closed():
	settings_instance = null
	
	continue_button.disabled = false
	settings_button.disabled = false
	main_menu_button.disabled = false
	
	if continue_button is Control:
		continue_button.grab_focus()
	
	FadeManager.fade_in(0.15)
	
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
	
	if not is_open:
		return
	
	is_open = false
	
	# 隐藏黑色遮罩层
	DarkOverlay.hide_overlay()
	
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
	
	queue_free()
	
	await SceneManager.return_to_title_from_game_setting()
	await SceneManager.switch_scene(ScenePaths.UI_TITLE, 0.25)

func _input(event):
	if event.is_action_pressed("ui_cancel") and is_open:
		if settings_instance:
			return
		else:
			_close_game_setting()
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
