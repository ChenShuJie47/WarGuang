extends CanvasLayer  # 修复：改为 CanvasLayer

## 设置界面场景（在 Inspector 中拖拽 SettingsScene.tscn）
@export var settings_scene_resource: PackedScene

@onready var start_button = $UI/StartButton
@onready var settings_button = $UI/SettingsButton
@onready var quit_button = $UI/QuitButton

func _ready():
	start_button.pressed.connect(_on_start_button_pressed)
	settings_button.pressed.connect(_on_settings_button_pressed)
	quit_button.pressed.connect(_on_quit_button_pressed)
	
	FadeManager.fade_in(0.15)
	
	## 播放 UI BGM
	AudioManager.play_bgm("BGM0")
	
	await get_tree().create_timer(0.1).timeout
	
	## 修改：调用 LightingManager 的统一函数
	LightingManager.setup_ui_breathing_effect(self)

#func setup_breathing_effect():
	#var point_lights = _find_nodes_by_type(self, "PointLight2D")
	#for light in point_lights:
		#if light is PointLight2D:
			#light.energy = 1.0
			#if not light.is_in_group("ui_point_lights"):
				#light.add_to_group("ui_point_lights")
	#
	#LightingManager.stop_all_light_effects()
	#await get_tree().create_timer(0.05).timeout
	#LightingManager.create_breathing_effect()
#
#func _find_nodes_by_type(root: Node, type: String) -> Array:
	#var result = []
	#if root.get_class() == type:
		#result.append(root)
	#
	#for child in root.get_children():
		#result.append_array(_find_nodes_by_type(child, type))
	#
	#return result

func _on_start_button_pressed():
	AudioManager.play_sfx("button_click")
	
	LightingManager.stop_all_light_effects()
	await SceneManager.switch_scene(ScenePaths.UI_SAVE_SELECT, 0.15)

func _on_settings_button_pressed():
	start_button.disabled = true
	settings_button.disabled = true  # 修复：改为 settings_button
	quit_button.disabled = true
	
	await FadeManager.fade_out(0.15)
	
	if not settings_scene_resource:
		push_error("TitleScene: settings_scene_resource 未配置！请在 Inspector 中拖拽 SettingsScene.tscn")
		return
	
	var settings_scene = settings_scene_resource.instantiate()
	settings_scene.setup("TitleScene", self)
	get_tree().root.add_child(settings_scene)
	
	await FadeManager.fade_in(0.15)

# TitleScene.gd - 修改_on_settings_closed函数
func _on_settings_closed():
	start_button.disabled = false
	settings_button.disabled = false
	quit_button.disabled = false
	
	## 关键修复：等待淡入完成后重新设置呼吸效果
	await FadeManager.fade_in(0.15)
	
	## 新增：重新设置灯光呼吸效果
	## 等待一帧确保淡入完成
	await get_tree().process_frame
	
	## 调用 LightingManager 统一函数
	LightingManager.setup_ui_breathing_effect(self)

func _on_quit_button_pressed():
	AudioManager.play_sfx("button_click")
	get_tree().quit()

func _exit_tree():
	LightingManager.stop_all_light_effects()
