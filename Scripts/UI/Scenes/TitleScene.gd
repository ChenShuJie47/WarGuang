extends CanvasLayer  # 修复：改为 CanvasLayer

## 设置界面场景（在 Inspector 中拖拽 SettingsScene.tscn）
@export var settings_scene_resource: PackedScene

@onready var start_button = $UI/StartButton
@onready var settings_button = $UI/SettingsButton
@onready var quit_button = $UI/QuitButton
@onready var ui_transition_animator: UITransitionAnimator = $UITransitionAnimator
@onready var external_material_animator: AnimationPlayer = $ExternalMaterialAnimator

var _scene_input_locked: bool = true
var _settings_overlay_open: bool = false

func _ready():
	start_button.pressed.connect(_on_start_button_pressed)
	settings_button.pressed.connect(_on_settings_button_pressed)
	quit_button.pressed.connect(_on_quit_button_pressed)
	
	_set_scene_input_locked(true)
	if not ui_transition_animator:
		FadeManager.fade_in(FadeManager.ui_overlay_fade_duration)
		_set_scene_input_locked(false)
	else:
		ui_transition_animator.reset_state()
		if FadeManager and FadeManager.has_method("get_black_alpha") and FadeManager.get_black_alpha() <= 0.01:
			call_deferred("_on_scene_transition_enter_begin")
	
	## 播放 UI BGM
	AudioManager.play_bgm("BGM0")
	
	await get_tree().create_timer(0.1).timeout
	await _play_external_material_enter()
	
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
	if _scene_input_locked:
		return
	AudioManager.play_sfx("button_click")
	
	_set_scene_input_locked(true)
	LightingManager.stop_all_light_effects()
	if ui_transition_animator:
		await ui_transition_animator.play_exit_transition()
	await _play_external_material_exit()
	await SceneManager.switch_scene(ScenePaths.UI_SAVE_SELECT)

func _on_settings_button_pressed():
	if _scene_input_locked:
		return
	start_button.disabled = true
	settings_button.disabled = true  # 修复：改为 settings_button
	quit_button.disabled = true
	_set_scene_input_locked(true)
	
	if ui_transition_animator:
		await ui_transition_animator.play_exit_transition()
	await _play_external_material_exit()
	await FadeManager.fade_out(FadeManager.ui_overlay_fade_duration)
	
	if not settings_scene_resource:
		push_error("TitleScene: settings_scene_resource 未配置！请在 Inspector 中拖拽 SettingsScene.tscn")
		return
	
	var settings_scene = settings_scene_resource.instantiate()
	settings_scene.setup("TitleScene", self)
	get_tree().root.add_child(settings_scene)
	_settings_overlay_open = true
	if settings_scene.has_method("_on_scene_transition_enter_begin"):
		settings_scene._on_scene_transition_enter_begin()
	
	await FadeManager.fade_in(FadeManager.ui_overlay_fade_duration)

# TitleScene.gd - 修改_on_settings_closed函数
func _on_settings_closed(settings_scene: Node = null):
	_settings_overlay_open = false
	await FadeManager.fade_out(FadeManager.ui_overlay_fade_duration)
	if settings_scene and is_instance_valid(settings_scene):
		settings_scene.queue_free()
	start_button.disabled = false
	settings_button.disabled = false
	quit_button.disabled = false
	if ui_transition_animator:
		_on_scene_transition_enter_begin()
	
	## 关键修复：等待淡入完成后重新设置呼吸效果
	await FadeManager.fade_in(FadeManager.ui_overlay_fade_duration)
	await _play_external_material_enter()
	
	## 新增：重新设置灯光呼吸效果
	## 等待一帧确保淡入完成
	await get_tree().process_frame
	
	## 调用 LightingManager 统一函数
	LightingManager.setup_ui_breathing_effect(self)

func _on_quit_button_pressed():
	if _scene_input_locked:
		return
	_set_scene_input_locked(true)
	AudioManager.play_sfx("button_click")
	if ui_transition_animator:
		await ui_transition_animator.play_exit_transition()
	await _play_external_material_exit()
	get_tree().quit()

func _input(event):
	if _settings_overlay_open:
		return
	if not _scene_input_locked:
		return
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton:
		get_viewport().set_input_as_handled()

func is_scene_interaction_locked() -> bool:
	return _scene_input_locked

func _set_scene_input_locked(locked: bool) -> void:
	_scene_input_locked = locked
	start_button.disabled = locked
	settings_button.disabled = locked
	quit_button.disabled = locked

func _on_scene_transition_enter_begin() -> void:
	_set_scene_input_locked(true)
	if ui_transition_animator:
		await ui_transition_animator.play_enter_transition()
	_set_scene_input_locked(false)

func _play_external_material_enter() -> void:
	if not external_material_animator:
		return
	if external_material_animator.has_animation("material_enter"):
		external_material_animator.play("material_enter")
		await external_material_animator.animation_finished
	if external_material_animator.has_animation("material_loop"):
		external_material_animator.play("material_loop")

func _play_external_material_exit() -> void:
	if not external_material_animator:
		return
	if external_material_animator.has_animation("material_exit"):
		external_material_animator.play("material_exit")
		await external_material_animator.animation_finished

func _exit_tree():
	LightingManager.stop_all_light_effects()
