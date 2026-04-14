# SettingsScene.gd
extends CanvasLayer

## 设置场景主脚本

## 节点引用
@onready var audio_button = $SettingsRoot/AudioButton          # 音量按钮
@onready var controls_button = $SettingsRoot/ControlsButton    # 按键映射按钮
@onready var graphics_button = $SettingsRoot/GraphicsButton    # 画面按钮
@onready var audio_page = $SettingsRoot/AudioPage              # 音频页面
@onready var controls_page = $SettingsRoot/ControlsPage        # 控制页面
@onready var graphics_page = get_node_or_null("SettingsRoot/GraphicsPage") # 画面页面
@onready var effect_level_option: OptionButton = get_node_or_null("SettingsRoot/GraphicsPage/EffectLevelContainer/EffectLevelOption")
@onready var close_button = $BackButton                        # 关闭按钮
@onready var ui_transition_animator: UITransitionAnimator = $UITransitionAnimator

## 音量滑块引用（根据你的实际节点路径调整）
@onready var master_volume_slider = $SettingsRoot/AudioPage/VolumeContainer/MasterVolumeLabel/MasterVolumeSlider
@onready var bgm_volume_slider = $SettingsRoot/AudioPage/VolumeContainer/BGMVolumeLabel/BGMVolumeSlider
@onready var sfx_volume_slider = $SettingsRoot/AudioPage/VolumeContainer/SFXVolumeLabel/SFXVolumeSlider
@onready var voice_volume_slider = $SettingsRoot/AudioPage/VolumeContainer/VoiceVolumeLabel/VoiceVolumeSlider

## 场景来源信息
var opened_from: String = ""
var parent_scene: Node = null
## ESC键启用状态
var esc_enabled: bool = false
var _scene_input_locked: bool = true
var _current_page_name: String = "controls"
var _page_switch_in_progress: bool = false

@export_category("Settings 页面内切换动画")
@export var page_enter_duration: float = 0.22
@export var page_exit_duration: float = 0.18
@export var page_peak_scale_multiplier: float = 1.12
@export var page_exit_min_scale_multiplier: float = 0.02
@export var page_drift_distance: float = 18.0

enum UiEffectLevel {
	LOW,
	MEDIUM,
	HIGH
}

var ui_effect_level: int = UiEffectLevel.MEDIUM
var _page_base_positions: Dictionary = {}
var _page_base_scales: Dictionary = {}
var _page_base_modulates: Dictionary = {}

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	
	# 连接按钮信号
	audio_button.pressed.connect(_on_audio_button_pressed)
	controls_button.pressed.connect(_on_controls_button_pressed)
	graphics_button.pressed.connect(_on_graphics_button_pressed)
	close_button.pressed.connect(_on_close_button_pressed)
	
	# 连接音量滑块信号
	if master_volume_slider:
		master_volume_slider.value_changed.connect(_on_master_volume_changed)
	if bgm_volume_slider:
		bgm_volume_slider.value_changed.connect(_on_bgm_volume_changed)
	if sfx_volume_slider:
		sfx_volume_slider.value_changed.connect(_on_sfx_volume_changed)
	if voice_volume_slider:
		voice_volume_slider.value_changed.connect(_on_voice_volume_changed)
	
	_cache_page_base_states()
	_switch_to_page("controls", false)
	_populate_effect_level_options()
	if effect_level_option:
		effect_level_option.item_selected.connect(_on_effect_level_selected)
	
	# 设置焦点
	if audio_button is Control:
		audio_button.grab_focus()

	_set_scene_input_locked(true)
	if ui_transition_animator:
		ui_transition_animator.reset_state()
		if FadeManager and FadeManager.has_method("get_black_alpha") and FadeManager.get_black_alpha() <= 0.01:
			call_deferred("_on_scene_transition_enter_begin")
	else:
		_set_scene_input_locked(false)
	
	# ESC冷却
	var esc_timer = Timer.new()
	esc_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	esc_timer.wait_time = 0.1
	esc_timer.one_shot = true
	esc_timer.autostart = true
	esc_timer.timeout.connect(func():
		esc_enabled = true
		if esc_timer.is_inside_tree():
			remove_child(esc_timer)
			esc_timer.queue_free()
	)
	add_child(esc_timer)

## 设置场景来源
func setup(from_scene: String, parent: Node = null):
	opened_from = from_scene
	parent_scene = parent

## 切换页面
func switch_to_page(page_name: String):
	await _switch_to_page(page_name, true)

func _switch_to_page(page_name: String, animated: bool = true) -> void:
	if page_name == _current_page_name and animated:
		return
	var target_page: CanvasItem = _resolve_page(page_name)
	if target_page == null:
		return
	if _page_switch_in_progress:
		return
	var previous_page: CanvasItem = _resolve_page(_current_page_name)
	_page_switch_in_progress = true
	_set_category_buttons_enabled(false)
	if animated and previous_page and previous_page != target_page:
		await _play_page_exit(previous_page)
		previous_page.visible = false
		_restore_page_base_state(previous_page)
	elif previous_page and previous_page != target_page:
		previous_page.visible = false
		_restore_page_base_state(previous_page)

	target_page.visible = true
	if animated:
		await _play_page_enter(target_page)
	else:
		_restore_page_base_state(target_page)

	_current_page_name = page_name
	_set_category_button_state(page_name)
	_set_category_buttons_enabled(true)
	_page_switch_in_progress = false

func _resolve_page(page_name: String) -> CanvasItem:
	match page_name:
		"audio":
			return audio_page
		"controls":
			return controls_page
		"graphics":
			return graphics_page
		_:
			return null

func _cache_page_base_states() -> void:
	for page_name in ["audio", "controls", "graphics"]:
		var page: CanvasItem = _resolve_page(page_name)
		if page:
			_page_base_positions[page_name] = page.position
			_page_base_scales[page_name] = page.scale
			_page_base_modulates[page_name] = page.modulate

func _restore_page_base_state(page: CanvasItem) -> void:
	var page_name := _name_by_page(page)
	if page_name == "":
		return
	page.position = _page_base_positions.get(page_name, page.position)
	page.scale = _page_base_scales.get(page_name, page.scale)
	page.modulate = _page_base_modulates.get(page_name, page.modulate)

func _play_page_enter(page: CanvasItem) -> void:
	var page_name := _name_by_page(page)
	if page_name == "":
		return
	var base_position: Vector2 = _page_base_positions.get(page_name, page.position)
	var base_scale: Vector2 = _page_base_scales.get(page_name, page.scale)
	var base_modulate: Color = _page_base_modulates.get(page_name, page.modulate)
	page.position = Vector2(base_position.x, base_position.y + page_drift_distance)
	page.scale = base_scale * page_peak_scale_multiplier
	page.modulate = Color(base_modulate.r, base_modulate.g, base_modulate.b, 0.0)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(page, "position:y", base_position.y, page_enter_duration)
	tween.parallel().tween_property(page, "scale", base_scale, page_enter_duration)
	tween.parallel().tween_property(page, "modulate:a", base_modulate.a, page_enter_duration)
	await tween.finished

func _play_page_exit(page: CanvasItem) -> void:
	var page_name := _name_by_page(page)
	if page_name == "":
		return
	var base_position: Vector2 = _page_base_positions.get(page_name, page.position)
	var base_scale: Vector2 = _page_base_scales.get(page_name, page.scale)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(page, "position:y", base_position.y + page_drift_distance, page_exit_duration)
	tween.parallel().tween_property(page, "scale", base_scale * page_exit_min_scale_multiplier, page_exit_duration)
	tween.parallel().tween_property(page, "modulate:a", 0.0, page_exit_duration)
	await tween.finished

func _name_by_page(page: CanvasItem) -> String:
	if page == audio_page:
		return "audio"
	if page == controls_page:
		return "controls"
	if page == graphics_page:
		return "graphics"
	return ""

func _set_category_buttons_enabled(enabled: bool) -> void:
	audio_button.disabled = not enabled
	controls_button.disabled = not enabled
	graphics_button.disabled = not enabled

func _set_category_button_state(active_page: String) -> void:
	audio_button.disabled = active_page == "audio"
	controls_button.disabled = active_page == "controls"
	graphics_button.disabled = active_page == "graphics"

func _populate_effect_level_options() -> void:
	if not effect_level_option:
		return
	effect_level_option.clear()
	effect_level_option.add_item("低", UiEffectLevel.LOW)
	effect_level_option.add_item("中", UiEffectLevel.MEDIUM)
	effect_level_option.add_item("高", UiEffectLevel.HIGH)
	effect_level_option.select(ui_effect_level)

func _on_effect_level_selected(index: int) -> void:
	ui_effect_level = index
	_apply_effect_level(ui_effect_level)

func _apply_effect_level(level: int) -> void:
	match level:
		UiEffectLevel.LOW:
			print("SettingsScene: 特效等级=低")
		UiEffectLevel.MEDIUM:
			print("SettingsScene: 特效等级=中")
		UiEffectLevel.HIGH:
			print("SettingsScene: 特效等级=高")

## 音频按钮按下
func _on_audio_button_pressed():
	if _scene_input_locked or _page_switch_in_progress:
		return
	AudioManager.play_sfx("button_click")
	
	# 静默取消控制页面中的映射
	if controls_page and controls_page.has_method("cancel_current_mapping"):
		controls_page.cancel_current_mapping()
	
	await _switch_to_page("audio")

## 控制按钮按下
func _on_controls_button_pressed():
	if _scene_input_locked or _page_switch_in_progress:
		return
	AudioManager.play_sfx("button_click")
	
	# 静默取消任何映射
	if controls_page and controls_page.has_method("cancel_current_mapping"):
		controls_page.cancel_current_mapping()
	
	await _switch_to_page("controls")

func _on_graphics_button_pressed():
	if _scene_input_locked or _page_switch_in_progress:
		return
	AudioManager.play_sfx("button_click")
	if controls_page and controls_page.has_method("cancel_current_mapping"):
		controls_page.cancel_current_mapping()
	await _switch_to_page("graphics")

## 关闭按钮按下
func _on_close_button_pressed():
	if _scene_input_locked:
		return
	AudioManager.play_sfx("button_click")
	_close_settings()

## 处理输入
func _input(event):
	if _scene_input_locked:
		if event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton:
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") and esc_enabled:
		# 检查是否正在重新映射
		if InputMapManager.is_remapping():
			# 正在重新映射，不关闭设置
			return
		
		get_viewport().set_input_as_handled()
		_close_settings()

## 关闭设置场景
func _close_settings():
	set_process_input(false)
	set_process_unhandled_input(false)
	
	if close_button:
		close_button.disabled = true
	
	# 取消任何正在进行的重新映射
	if InputMapManager:
		InputMapManager.cancel_remap()

	_set_scene_input_locked(true)
	if ui_transition_animator:
		await ui_transition_animator.play_exit_transition()
	
	# 根据来源通知父场景
	if opened_from == "GameSettingScene" and parent_scene and is_instance_valid(parent_scene):
		if parent_scene.has_method("_on_settings_closed"):
			await parent_scene._on_settings_closed(self)
	elif opened_from == "TitleScene" and parent_scene and is_instance_valid(parent_scene):
		if parent_scene.has_method("_on_settings_closed"):
			await parent_scene._on_settings_closed(self)
	else:
		queue_free()

## 音量控制函数
func _on_master_volume_changed(value: float):
	AudioManager.set_bus_volume_percent("Master", value)

func _on_bgm_volume_changed(value: float):
	AudioManager.set_bus_volume_percent("BGM", value)

func _on_sfx_volume_changed(value: float):
	AudioManager.set_bus_volume_percent("SFX", value)

func _on_voice_volume_changed(value: float):
	AudioManager.set_bus_volume_percent("Voice", value)

func _exit_tree():
	LightingManager.stop_all_light_effects()

func is_scene_interaction_locked() -> bool:
	return _scene_input_locked

func _set_scene_input_locked(locked: bool) -> void:
	_scene_input_locked = locked
	audio_button.disabled = locked
	controls_button.disabled = locked
	graphics_button.disabled = locked
	close_button.disabled = locked

func _on_scene_transition_enter_begin() -> void:
	_set_scene_input_locked(true)
	if ui_transition_animator:
		await ui_transition_animator.play_enter_transition()
	_set_scene_input_locked(false)
