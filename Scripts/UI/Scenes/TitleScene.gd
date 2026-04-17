extends CanvasLayer  # 修复：改为 CanvasLayer

## 设置界面场景（在 Inspector 中拖拽 SettingsScene.tscn）
@export var settings_scene_resource: PackedScene

@onready var start_button = $UI/StartButton
@onready var settings_button = $UI/SettingsButton
@onready var quit_button = $UI/QuitButton
@onready var ui_transition_animator: UITransitionAnimator = $UITransitionAnimator
@onready var external_material_animator: AnimationPlayer = $ExternalMaterialAnimator
@onready var title_sprite_a: Sprite2D = $Title
@onready var title_sprite_b: Sprite2D = get_node_or_null("TitleB")
@onready var title_click_area_a: BaseButton = get_node_or_null("TitleClickAreaA")
@onready var title_click_area_b: BaseButton = get_node_or_null("TitleClickAreaB")

## 场景输入锁状态
var _scene_input_locked: bool = true
## Settings 覆盖层打开状态
var _settings_overlay_open: bool = false
## 当前标题点击计数
var _title_click_count: int = 0
## 标题是否正在抖动
var _title_shaking: bool = false
## 标题A初始位置
var _title_a_base_position: Vector2 = Vector2.ZERO
## 标题A初始缩放
var _title_a_base_scale: Vector2 = Vector2.ONE
## 标题B初始位置
var _title_b_base_position: Vector2 = Vector2.ZERO
## 标题B初始缩放
var _title_b_base_scale: Vector2 = Vector2.ONE

enum TitleVariant {
	A,
	B
}

const TITLE_UI_STATE_PATH: String = "user://ui_state.cfg"
const TITLE_UI_STATE_SECTION: String = "title_scene"
const TITLE_UI_STATE_KEY: String = "active_variant"

var _active_title_variant: int = TitleVariant.A

@export_category("标题可点击区域互动")
@export var title_shake_duration: float = 0.5
@export var title_shake_strength: float = 7.0
@export var title_shake_interval: float = 0.03

## 初始化标题场景
func _ready():
	start_button.pressed.connect(_on_start_button_pressed)
	settings_button.pressed.connect(_on_settings_button_pressed)
	quit_button.pressed.connect(_on_quit_button_pressed)
	if title_click_area_a:
		title_click_area_a.pressed.connect(_on_title_area_a_pressed)
	if title_click_area_b:
		title_click_area_b.pressed.connect(_on_title_area_b_pressed)
	# 先把动画器还原到编辑器基态，再记录标题A/B初始位姿，避免拿到入场偏移后的错误基准。
	if ui_transition_animator:
		ui_transition_animator.reset_state()
	if title_sprite_a:
		_title_a_base_position = title_sprite_a.position
		_title_a_base_scale = title_sprite_a.scale
	if title_sprite_b:
		_title_b_base_position = title_sprite_b.position
		_title_b_base_scale = title_sprite_b.scale
	_load_title_variant_state()
	_apply_title_variant_state(false)
	
	_set_scene_input_locked(true)
	if not ui_transition_animator:
		FadeManager.fade_in(FadeManager.ui_overlay_fade_duration)
		_set_scene_input_locked(false)
	else:
		_sync_animator_title_target()
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

## 处理开始按钮按下
func _on_start_button_pressed():
	if _scene_input_locked:
		return
	AudioManager.play_sfx("button_click")
	_reset_title_click_state()
	
	_set_scene_input_locked(true)
	LightingManager.stop_all_light_effects()
	if ui_transition_animator:
		await ui_transition_animator.play_exit_transition()
	await _play_external_material_exit()
	await SceneManager.switch_scene(ScenePaths.UI_SAVE_SELECT)

## 处理设置按钮按下
func _on_settings_button_pressed():
	if _scene_input_locked:
		return
	_reset_title_click_state()
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
		settings_scene.call_deferred("_on_scene_transition_enter_begin")
	
	await FadeManager.fade_in(FadeManager.ui_overlay_fade_duration)

## 处理Settings返回标题
func _on_settings_closed(settings_scene: Node = null):
	_settings_overlay_open = false
	_reset_title_click_state()
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

## 处理退出按钮按下
func _on_quit_button_pressed():
	if _scene_input_locked:
		return
	_reset_title_click_state()
	_set_scene_input_locked(true)
	AudioManager.play_sfx("button_click")
	if ui_transition_animator:
		await ui_transition_animator.play_exit_transition()
	await _play_external_material_exit()
	get_tree().quit()

## 处理标题场景输入
func _input(event):
	if _settings_overlay_open:
		return
	if not _scene_input_locked:
		return
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton:
		get_viewport().set_input_as_handled()

## 查询当前场景交互锁
func is_scene_interaction_locked() -> bool:
	return _scene_input_locked

## 设置标题场景输入锁
func _set_scene_input_locked(locked: bool) -> void:
	_scene_input_locked = locked
	start_button.disabled = locked
	settings_button.disabled = locked
	quit_button.disabled = locked

## 播放标题场景入场动画
func _on_scene_transition_enter_begin() -> void:
	_set_scene_input_locked(true)
	if ui_transition_animator:
		await ui_transition_animator.play_enter_transition()
	_set_scene_input_locked(false)

## 播放外部材质入场动画
func _play_external_material_enter() -> void:
	if not external_material_animator:
		return
	if external_material_animator.has_animation("material_enter"):
		external_material_animator.play("material_enter")
		await external_material_animator.animation_finished
	if external_material_animator.has_animation("material_loop"):
		external_material_animator.play("material_loop")

## 播放外部材质退场动画
func _play_external_material_exit() -> void:
	if not external_material_animator:
		return
	if external_material_animator.has_animation("material_exit"):
		external_material_animator.play("material_exit")
		await external_material_animator.animation_finished

## 处理标题A点击
func _on_title_area_a_pressed() -> void:
	if _scene_input_locked or _settings_overlay_open or _title_shaking:
		return
	if _active_title_variant != TitleVariant.A:
		return
	await _on_title_variant_click()

## 处理标题B点击
func _on_title_area_b_pressed() -> void:
	if _scene_input_locked or _settings_overlay_open or _title_shaking:
		return
	if _active_title_variant != TitleVariant.B:
		return
	await _on_title_variant_click()

## 处理标题点击计数
func _on_title_variant_click() -> void:
	var active_title: Sprite2D = title_sprite_a if _active_title_variant == TitleVariant.A else title_sprite_b
	await _play_title_shake(active_title)
	_title_click_count += 1
	if _title_click_count >= 3:
		_title_click_count = 0
		await _toggle_title_variant()

## 播放标题抖动反馈
func _play_title_shake(target: Sprite2D) -> void:
	if not target:
		return
	_title_shaking = true
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var base_position: Vector2 = target.position
	var elapsed: float = 0.0
	while elapsed < title_shake_duration:
		target.position = base_position + Vector2(
			rng.randf_range(-title_shake_strength, title_shake_strength),
			rng.randf_range(-title_shake_strength, title_shake_strength)
		)
		await get_tree().create_timer(title_shake_interval).timeout
		elapsed += title_shake_interval
	target.position = base_position
	_title_shaking = false

## 切换标题变体
func _toggle_title_variant() -> void:
	if _active_title_variant == TitleVariant.A:
		await _swap_title_variant(title_sprite_a, title_sprite_b)
		_active_title_variant = TitleVariant.B
	else:
		await _swap_title_variant(title_sprite_b, title_sprite_a)
		_active_title_variant = TitleVariant.A
	_save_title_variant_state()
	_apply_title_variant_state(false)

## 执行标题变体切换动画
func _swap_title_variant(from_sprite: Sprite2D, to_sprite: Sprite2D) -> void:
	if not from_sprite or not to_sprite:
		return
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(from_sprite, "scale:y", 0.05, 0.2)
	tween.tween_property(from_sprite, "modulate:a", 0.0, 0.1)
	await tween.finished
	from_sprite.visible = false

	to_sprite.visible = true
	var base_scale_b: Vector2 = _title_b_base_scale if to_sprite == title_sprite_b else _title_a_base_scale
	var base_position_b: Vector2 = _title_b_base_position if to_sprite == title_sprite_b else _title_a_base_position
	to_sprite.position = base_position_b
	to_sprite.scale = base_scale_b
	to_sprite.scale.y = 0.05
	to_sprite.modulate.a = 0.0
	var tween_b := create_tween()
	tween_b.set_trans(Tween.TRANS_CUBIC)
	tween_b.set_ease(Tween.EASE_OUT)
	tween_b.parallel().tween_property(to_sprite, "scale:y", base_scale_b.y, 0.22)
	tween_b.parallel().tween_property(to_sprite, "modulate:a", 1.0, 0.22)
	await tween_b.finished

## 应用当前标题变体状态
func _apply_title_variant_state(reset_counter: bool = true) -> void:
	if title_sprite_a:
		title_sprite_a.position = _title_a_base_position
		title_sprite_a.scale = _title_a_base_scale
		title_sprite_a.visible = _active_title_variant == TitleVariant.A
		title_sprite_a.modulate.a = 1.0
	if title_sprite_b:
		title_sprite_b.position = _title_b_base_position
		title_sprite_b.scale = _title_b_base_scale
		title_sprite_b.visible = _active_title_variant == TitleVariant.B
		title_sprite_b.modulate.a = 1.0
	if title_click_area_a:
		title_click_area_a.visible = _active_title_variant == TitleVariant.A
	if title_click_area_b:
		title_click_area_b.visible = _active_title_variant == TitleVariant.B
	_sync_animator_title_target()
	if ui_transition_animator:
		ui_transition_animator.reset_state()
	if reset_counter:
		_title_click_count = 0

## 同步动画器标题目标
func _sync_animator_title_target() -> void:
	if not ui_transition_animator:
		return
	ui_transition_animator.title_path = NodePath("../Title") if _active_title_variant == TitleVariant.A else NodePath("../TitleB")
	if ui_transition_animator.has_method("refresh_title_target_only"):
		ui_transition_animator.refresh_title_target_only()
	elif ui_transition_animator.has_method("refresh_targets"):
		ui_transition_animator.refresh_targets()

## 读取标题变体持久化状态
func _load_title_variant_state() -> void:
	var config := ConfigFile.new()
	var err := config.load(TITLE_UI_STATE_PATH)
	if err != OK:
		_active_title_variant = TitleVariant.A
		return
	_active_title_variant = int(config.get_value(TITLE_UI_STATE_SECTION, TITLE_UI_STATE_KEY, TitleVariant.A))

## 保存标题变体持久化状态
func _save_title_variant_state() -> void:
	var config := ConfigFile.new()
	config.load(TITLE_UI_STATE_PATH)
	config.set_value(TITLE_UI_STATE_SECTION, TITLE_UI_STATE_KEY, _active_title_variant)
	config.save(TITLE_UI_STATE_PATH)

## 重置标题点击状态（切场前后统一调用）
## 重置标题点击状态
func _reset_title_click_state() -> void:
	_title_click_count = 0
	_title_shaking = false

func _exit_tree():
	LightingManager.stop_all_light_effects()
