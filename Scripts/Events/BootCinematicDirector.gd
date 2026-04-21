extends CanvasLayer
class_name BootCinematicDirector

## Intro 序列执行完成。
signal intro_sequence_finished
## 掉落演出开始。
signal gameplay_drop_started
## 掉落演出完成。
signal gameplay_drop_finished

## Intro 步骤类型枚举。
enum IntroStepType {
	TEXT,
	VISUAL,
	BLACK_HOLD
}

@export_category("Unified Event Timing")
## 所有事件步骤（TEXT/VISUAL/BLACK_HOLD）的统一淡入淡出时长（秒）。
@export var unified_step_fade_duration: float = 0.3
## BLACK_HOLD 的统一停留时长（秒）。
@export var unified_black_hold_duration: float = 1.0
## 文本步骤缺失独立停留时长时的统一兜底时长（秒）。
@export var unified_text_hold_fallback_duration: float = 1.2
## 视觉步骤缺失独立停留时长时的统一兜底时长（秒）。
@export var unified_visual_hold_fallback_duration: float = 1.6
## 揭黑默认时长（秒）。
const DEFAULT_REVEAL_DURATION: float = 2.5
## 掉落流程最长运行时间（秒），用于避免异常情况下永不解控。
const DROP_FLOW_TIMEOUT_SECONDS: float = 12.0

# 当前是否正在执行 Intro。
var _intro_running: bool = false
# 当前是否正在执行掉落流程。
var _drop_running: bool = false
# 当前掉落流程是否已开始。
var _drop_started: bool = false
# 掉落协程是否已进入首帧。
var _drop_flow_entered: bool = false
# 掉落是否已完成首帧运动更新（用于揭黑前防露静帧）。
var _drop_motion_visual_ready: bool = false
# 节点是否处于退出树流程中（用于协程安全中止）。
var _shutting_down: bool = false
# 当前 payload 黑幕锁是否已释放。
var _black_hold_released: bool = false
# 当前执行参数载荷。
var _active_payload: Dictionary = {}

# 当前受控玩家。
var _player: Player = null
# 玩家相机控制器引用。
var _camera_controller: PlayerCameraController = null
# 玩家 PhantomCamera2D 引用。
var _phantom_camera: Node = null
# 当前主 Camera2D 引用。
var _camera_2d: Camera2D = null
# 掉落期间 dead zone 备份值。
var _drop_dead_zone_backup: Vector2 = Vector2.ZERO
# 掉落期间 dead zone 备份有效标记。
var _drop_dead_zone_backup_valid: bool = false

# 演出覆盖层根节点。
var _overlay_root: Control = null
# 黑幕节点。
var _black_rect: ColorRect = null
# 文本节点。
var _text_label: RichTextLabel = null
# 视觉节点。
var _visual_rect: TextureRect = null

# 玩家 focus capture 开关备份。
var _focus_capture_backup: bool = true
# 玩家 physics_process 开关备份。
var _player_physics_process_backup: bool = true
# 玩家 input_process 开关备份。
var _player_input_process_backup: bool = true
# 玩家 current_animation 备份。
var _player_current_animation_backup: String = ""

## 初始化执行器与覆盖层。
func _ready() -> void:
	_shutting_down = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 1105
	_build_overlay()
	if is_instance_valid(_overlay_root):
		_overlay_root.visible = false

func _exit_tree() -> void:
	_shutting_down = true
	_release_black_hold_if_needed()
	_abort_drop_flow()

## 事件播放入口：按 payload 指示运行 intro/drop。
func play_sequence(_sequence_id: StringName, payload: Dictionary = {}) -> void:
	var run_intro: bool = bool(payload.get("run_intro_phase", false))
	var run_drop: bool = bool(payload.get("run_drop_phase", false))
	if run_intro:
		await play_intro_sequence(payload)
	if run_drop:
		var target_player: Player = payload.get("player_ref", null)
		if is_instance_valid(target_player):
			start_gameplay_drop(target_player, payload)
			while not _drop_started:
				if not is_inside_tree():
					return
				var tree := get_tree()
				if _shutting_down or tree == null:
					return
				await tree.process_frame

## 执行 Intro 序列。
func play_intro_sequence(payload: Dictionary = {}) -> void:
	if _intro_running:
		return
	_intro_running = true
	_active_payload = payload.get("payload", payload) if typeof(payload.get("payload", payload)) == TYPE_DICTIONARY else {}
	if is_instance_valid(_overlay_root):
		_overlay_root.visible = true
	_reset_overlay_state()
	await _run_intro_sequence_steps()
	await _fade_overlay_to_black()
	intro_sequence_finished.emit()
	_intro_running = false

## 启动掉落流程。
func start_gameplay_drop(player_ref: Player, payload: Dictionary = {}) -> void:
	if _shutting_down:
		return
	if _drop_running:
		return
	_drop_running = true
	_drop_started = true
	_drop_flow_entered = false
	_drop_motion_visual_ready = false
	_black_hold_released = false
	gameplay_drop_started.emit()
	_player = player_ref
	_active_payload = payload.get("payload", payload) if typeof(payload.get("payload", payload)) == TYPE_DICTIONARY else {}
	call_deferred("_start_drop_flow_deferred")

## 延迟启动掉落，保证 Intro 完整结束。
func _start_drop_flow_deferred() -> void:
	while _intro_running:
		if not is_inside_tree():
			_abort_drop_flow()
			return
		var wait_tree := get_tree()
		if _shutting_down or wait_tree == null:
			_abort_drop_flow()
			return
		await wait_tree.process_frame
	if not is_inside_tree():
		_abort_drop_flow()
		return
	var tree := get_tree()
	if _shutting_down or tree == null:
		_abort_drop_flow()
		return
	await tree.process_frame
	if _shutting_down:
		_abort_drop_flow()
		return
	await _start_drop_flow()

## 查询掉落是否已开始。
func is_gameplay_drop_started() -> bool:
	return _drop_started

## 查询掉落是否执行中。
func is_gameplay_drop_running() -> bool:
	return _drop_running

## 查询 Intro 是否执行中。
func is_intro_running() -> bool:
	return _intro_running

## 强制覆盖层纯黑。
func force_overlay_black() -> void:
	if not is_instance_valid(_overlay_root):
		return
	_overlay_root.visible = true
	if is_instance_valid(_black_rect):
		_black_rect.visible = true
		_black_rect.color.a = 1.0
	if is_instance_valid(_text_label):
		_text_label.visible = false
		_text_label.text = ""
		_text_label.modulate.a = 0.0
	if is_instance_valid(_visual_rect):
		_visual_rect.visible = false
		_visual_rect.texture = null
		_visual_rect.modulate.a = 0.0

## 判断覆盖层是否为完全黑幕。
func is_overlay_fully_black(threshold: float = 0.995) -> bool:
	if not is_instance_valid(_overlay_root) or not is_instance_valid(_black_rect):
		return false
	if not _overlay_root.visible:
		return false
	if not _black_rect.visible:
		return false
	return _black_rect.color.a >= clampf(threshold, 0.0, 1.0)

## 进入掉落主流程。
func _start_drop_flow() -> void:
	if _shutting_down or not is_inside_tree() or get_tree() == null:
		_abort_drop_flow()
		return
	if not is_instance_valid(_player):
		await reveal_overlay_to_gameplay(float(_active_payload.get("reveal_duration", get_default_fade_duration())))
		if FadeManager and FadeManager.has_method("force_fade_in"):
			FadeManager.force_fade_in()
		_abort_drop_flow()
		if not _shutting_down:
			gameplay_drop_finished.emit()
		return
	_cache_camera_nodes()
	_cache_player_runtime_switches()
	_enter_cinematic_control_mode()
	call_deferred("_run_drop_motion_flow")

	var drop_start_wait: float = 0.0
	while not _drop_flow_entered and drop_start_wait < 0.35:
		if not is_inside_tree():
			_abort_drop_flow()
			return
		var tree := get_tree()
		if _shutting_down or tree == null:
			_abort_drop_flow()
			return
		await tree.process_frame
		drop_start_wait += 1.0 / maxf(float(Engine.physics_ticks_per_second), 30.0)
	var visual_ready_wait: float = 0.0
	while not _drop_motion_visual_ready and visual_ready_wait < 0.5:
		if not is_inside_tree():
			_abort_drop_flow()
			return
		var visual_tree := get_tree()
		if _shutting_down or visual_tree == null:
			_abort_drop_flow()
			return
		await visual_tree.process_frame
		visual_ready_wait += 1.0 / maxf(float(Engine.physics_ticks_per_second), 30.0)

	var reveal_duration: float = maxf(float(_active_payload.get("reveal_duration", DEFAULT_REVEAL_DURATION)), 0.0)
	await _run_reveal_phase(reveal_duration)

## 执行掉落运动与收尾。
func _run_drop_motion_flow() -> void:
	if _shutting_down or not is_inside_tree() or get_tree() == null:
		_abort_drop_flow()
		return
	_drop_flow_entered = true

	var drop_speed: float = maxf(float(_active_payload.get("gameplay_drop_speed")), 10.0)
	var zoom_from: float = float(_active_payload.get("gameplay_camera_start_zoom"))
	var zoom_to: float = float(_active_payload.get("gameplay_camera_target_zoom"))
	var zoom_duration: float = maxf(float(_active_payload.get("gameplay_camera_zoom_duration")), 0.05)
	var drop_animation_name: StringName = StringName(_active_payload.get("gameplay_drop_animation_name"))
	var landed_animation_name: StringName = StringName(_active_payload.get("gameplay_landed_animation_name"))
	var end_animation_name: StringName = StringName(_active_payload.get("gameplay_end_animation_name"))
	var settle_time: float = maxf(float(_active_payload.get("gameplay_landing_settle_time")), 0.0)

	_set_camera_zoom(zoom_from)
	if is_instance_valid(_player):
		_play_player_animation(drop_animation_name)

	var zoom_tween := create_tween()
	zoom_tween.set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	zoom_tween.set_trans(Tween.TRANS_SINE)
	zoom_tween.set_ease(Tween.EASE_OUT)
	zoom_tween.tween_method(Callable(self, "_apply_zoom_step"), zoom_from, zoom_to, zoom_duration)

	var landed: bool = false
	var aborted: bool = false
	var drop_elapsed: float = 0.0
	while is_instance_valid(_player):
		if not is_inside_tree():
			aborted = true
			break
		var tree := get_tree()
		if _shutting_down or tree == null or not _player.is_inside_tree() or _player.get_world_2d() == null:
			aborted = true
			break
		while tree != null and tree.paused:
			await tree.process_frame
			if not is_inside_tree():
				aborted = true
				break
			tree = get_tree()
			if _shutting_down or tree == null or not is_instance_valid(_player) or not _player.is_inside_tree() or _player.get_world_2d() == null:
				aborted = true
				break
		if aborted:
			break
		await tree.physics_frame
		if not is_inside_tree():
			aborted = true
			break
		tree = get_tree()
		if _shutting_down or tree == null or not is_instance_valid(_player) or not _player.is_inside_tree() or _player.get_world_2d() == null:
			aborted = true
			break
		_drop_motion_visual_ready = true
		drop_elapsed += 1.0 / maxf(float(Engine.physics_ticks_per_second), 30.0)
		if not is_instance_valid(_player):
			break
		if is_instance_valid(_camera_controller) and _camera_controller.has_method("physics_process"):
			_camera_controller.physics_process(1.0 / maxf(float(Engine.physics_ticks_per_second), 30.0))
		if _manual_drop_step(drop_speed):
			landed = true
			break
		if drop_elapsed >= DROP_FLOW_TIMEOUT_SECONDS:
			push_warning("BootCinematicDirector: 掉落流程超时，执行强制收尾并解控。")
			landed = true
			break

	if aborted:
		_abort_drop_flow()
		return

	if landed and is_instance_valid(_player):
		if CameraShakeManager and CameraShakeManager.has_method("shake") and is_instance_valid(_phantom_camera):
			CameraShakeManager.shake("y_strong", _phantom_camera)
		_play_player_animation(landed_animation_name)
		if settle_time > 0.0:
			await _wait_seconds_respecting_pause(settle_time)

	_restore_player_runtime_switches()

	if is_instance_valid(_player):
		_play_player_animation(end_animation_name)
		_player.velocity = Vector2.ZERO
		_player.current_animation = ""
		if _player.current_state != _player.PlayerState.IDLE:
			_player.change_state(_player.PlayerState.IDLE)
		if _player.has_method("unlock_control"):
			_player.unlock_control()
		if _player.has_method("set_player_control"):
			_player.set_player_control(true)
		_player.set_process_input(true)

	_restore_camera_behavior()
	_abort_drop_flow()
	gameplay_drop_finished.emit()

## 逐帧推进一次掉落位移。
func _manual_drop_step(drop_speed: float) -> bool:
	if _shutting_down:
		return true
	if not is_instance_valid(_player):
		return true
	if not _player.is_inside_tree() or _player.get_world_2d() == null:
		return true
	var delta: float = 1.0 / maxf(float(Engine.physics_ticks_per_second), 30.0)
	var motion: Vector2 = Vector2.DOWN * drop_speed * delta
	var collision := _player.move_and_collide(motion)
	if _player.is_on_floor():
		_player.velocity = Vector2.ZERO
		return true
	if collision:
		_player.velocity = Vector2.ZERO
		return true
	return false

func _abort_drop_flow() -> void:
	_release_black_hold_if_needed()
	_drop_started = false
	_drop_running = false
	_drop_flow_entered = false
	_drop_motion_visual_ready = false

func _release_black_hold_if_needed() -> void:
	if _black_hold_released:
		return
	var hold_tag: String = str(_active_payload.get("release_black_hold_tag", "")).strip_edges()
	if hold_tag == "":
		_black_hold_released = true
		return
	if FadeManager and FadeManager.has_method("release_black_hold"):
		FadeManager.release_black_hold(hold_tag)
	_black_hold_released = true

## 创建并挂载覆盖层节点。
func _build_overlay() -> void:
	_overlay_root = Control.new()
	_overlay_root.name = "BootCinematicOverlay"
	_overlay_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay_root)

	_black_rect = ColorRect.new()
	_black_rect.name = "BlackRect"
	_black_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_black_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black_rect.color = Color(0.0, 0.0, 0.0, 1.0)
	_overlay_root.add_child(_black_rect)

	_visual_rect = TextureRect.new()
	_visual_rect.name = "IntroVisualRect"
	_visual_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_visual_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_visual_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_visual_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_visual_rect.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_visual_rect.visible = false
	_overlay_root.add_child(_visual_rect)

	_text_label = RichTextLabel.new()
	_text_label.name = "IntroText"
	_text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_text_label.fit_content = false
	_text_label.bbcode_enabled = true
	_text_label.scroll_active = false
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_text_label.visible = false
	_text_label.add_theme_color_override("default_color", Color(1.0, 1.0, 1.0, 1.0))
	_text_label.add_theme_font_size_override("normal_font_size", 28)
	_text_label.add_theme_constant_override("margin_left", 72)
	_text_label.add_theme_constant_override("margin_top", 80)
	_text_label.add_theme_constant_override("margin_right", 72)
	_text_label.add_theme_constant_override("margin_bottom", 80)
	_overlay_root.add_child(_text_label)
	_apply_gameplay_overlay_visibility(false)

## 重置覆盖层到初始黑幕状态。
func _reset_overlay_state() -> void:
	if not is_instance_valid(_black_rect) or not is_instance_valid(_text_label) or not is_instance_valid(_visual_rect):
		return
	_black_rect.visible = true
	_black_rect.color.a = 1.0
	_text_label.visible = false
	_text_label.modulate.a = 0.0
	_text_label.text = ""
	_visual_rect.visible = false
	_visual_rect.texture = null
	_visual_rect.modulate.a = 0.0

## 显隐覆盖层。
func _apply_gameplay_overlay_visibility(show_overlay: bool) -> void:
	if is_instance_valid(_overlay_root):
		_overlay_root.visible = show_overlay

## 缓存相机相关节点。
func _cache_camera_nodes() -> void:
	if not is_instance_valid(_player):
		return
	_camera_controller = _player.camera_controller
	_phantom_camera = _player.get_node_or_null("PhantomCamera2D")
	_camera_2d = _player.get_viewport().get_camera_2d() if _player.get_viewport() else null
	if _camera_controller and _camera_controller.has_method("get"):
		_focus_capture_backup = bool(_camera_controller.get("focus_capture_enabled"))

## 缓存玩家运行态开关。
func _cache_player_runtime_switches() -> void:
	if not is_instance_valid(_player):
		return
	if _active_payload.has("player_physics_process_backup"):
		_player_physics_process_backup = bool(_active_payload.get("player_physics_process_backup"))
	else:
		_player_physics_process_backup = _player.is_physics_processing()
	if _active_payload.has("player_input_process_backup"):
		_player_input_process_backup = bool(_active_payload.get("player_input_process_backup"))
	else:
		_player_input_process_backup = _player.is_processing_input()
	_player_current_animation_backup = _player.current_animation

## 进入演出控制模式。
func _enter_cinematic_control_mode() -> void:
	if not is_instance_valid(_player):
		return
	var lock_type: String = str(_active_payload.get("gameplay_lock_type"))
	if lock_type.strip_edges() == "":
		lock_type = "event_cinematic"
	if _camera_controller and _camera_controller.has_method("set"):
		_camera_controller.set("focus_capture_enabled", false)
	if _player.has_method("lock_control"):
		_player.lock_control(999.0, lock_type)
	if _player.has_method("set_player_control"):
		_player.set_player_control(false)
	_player.set_physics_process(false)
	_player.velocity = Vector2.ZERO
	if is_instance_valid(_phantom_camera):
		_drop_dead_zone_backup = Vector2(_phantom_camera.dead_zone_width, _phantom_camera.dead_zone_height)
		_drop_dead_zone_backup_valid = true
		# 维持较小 dead-zone 以保证掉落中相机持续跟随玩家中心附近。
		_phantom_camera.dead_zone_width = 0.05
		_phantom_camera.dead_zone_height = 0.05

## 恢复玩家运行态开关。
func _restore_player_runtime_switches() -> void:
	if not is_instance_valid(_player):
		return
	_player.set_physics_process(_player_physics_process_backup)
	_player.set_process_input(_player_input_process_backup)
	_player.current_animation = _player_current_animation_backup

## 恢复相机行为参数。
func _restore_camera_behavior() -> void:
	if _camera_controller and _camera_controller.has_method("set"):
		_camera_controller.set("focus_capture_enabled", _focus_capture_backup)
	if is_instance_valid(_phantom_camera) and _drop_dead_zone_backup_valid:
		_phantom_camera.dead_zone_width = _drop_dead_zone_backup.x
		_phantom_camera.dead_zone_height = _drop_dead_zone_backup.y
	_drop_dead_zone_backup_valid = false

## 设置相机缩放。
func _set_camera_zoom(zoom_value: float) -> void:
	var zoom_vector := Vector2.ONE * maxf(zoom_value, 0.01)
	if is_instance_valid(_phantom_camera):
		if _phantom_camera.has_method("set_zoom"):
			_phantom_camera.set_zoom(zoom_vector)
		else:
			_phantom_camera.zoom = zoom_vector
	if is_instance_valid(_camera_2d):
		_camera_2d.zoom = zoom_vector

## 缩放 tween 的逐步回调。
func _apply_zoom_step(zoom_value: float) -> void:
	_set_camera_zoom(zoom_value)

## 播放玩家动画。
func _play_player_animation(anim_name: StringName) -> void:
	if not is_instance_valid(_player):
		return
	if not is_instance_valid(_player.animated_sprite):
		return
	var anim_text: String = str(anim_name)
	if anim_text == "":
		return
	if _player.animated_sprite.sprite_frames and _player.animated_sprite.sprite_frames.has_animation(anim_text):
		_player.animated_sprite.play(anim_text)

## 执行 Intro 步骤列表。
func _run_intro_sequence_steps() -> void:
	var sequence_steps: Array = _active_payload.get("sequence_steps", [])
	sequence_steps = sequence_steps.duplicate(true)
	if sequence_steps.is_empty():
		return
	_apply_text_style_from_payload()
	for step in sequence_steps:
		if typeof(step) != TYPE_DICTIONARY:
			continue
		await _run_intro_step(step)

## 应用文本样式参数。
func _apply_text_style_from_payload() -> void:
	if not is_instance_valid(_text_label):
		return
	if _active_payload.has("intro_text_horizontal_alignment"):
		_text_label.horizontal_alignment = int(_active_payload.get("intro_text_horizontal_alignment")) as HorizontalAlignment
	if _active_payload.has("intro_text_vertical_alignment"):
		_text_label.vertical_alignment = int(_active_payload.get("intro_text_vertical_alignment")) as VerticalAlignment
	if _active_payload.has("intro_text_theme"):
		var theme_variant: Variant = _active_payload.get("intro_text_theme")
		if theme_variant is Theme:
			_text_label.theme = theme_variant
	if _active_payload.has("intro_text_font_size"):
		_text_label.add_theme_font_size_override("normal_font_size", max(1, int(_active_payload.get("intro_text_font_size"))))

## 执行单个 Intro 步骤。
func _run_intro_step(step: Dictionary) -> void:
	var step_type: int = _resolve_intro_step_type(step.get("type", IntroStepType.BLACK_HOLD))
	match step_type:
		IntroStepType.TEXT:
			await _run_intro_text_block(step)
		IntroStepType.VISUAL:
			await _run_intro_visual_block(step)
		IntroStepType.BLACK_HOLD:
			await _run_black_hold_block(step)
		_:
			await _run_black_hold_block(step)

## 解析步骤类型为枚举。
func _resolve_intro_step_type(raw_type: Variant) -> int:
	if raw_type is String:
		match str(raw_type).to_upper():
			"TEXT":
				return IntroStepType.TEXT
			"VISUAL":
				return IntroStepType.VISUAL
			"BLACK_HOLD":
				return IntroStepType.BLACK_HOLD
			_:
				return IntroStepType.BLACK_HOLD
	return int(raw_type)

## 执行文本步骤（缺失时长时使用统一兜底）。
func _run_intro_text_block(step: Dictionary) -> void:
	var lines: PackedStringArray = _extract_text_lines(step)
	if lines.is_empty():
		return
	var fade_time: float = maxf(unified_step_fade_duration, 0.01)
	for line_text in lines:
		if line_text.strip_edges() == "":
			continue
		if not is_instance_valid(_text_label):
			return
		var hold_time: float = unified_text_hold_fallback_duration
		if step.has("hold_time"):
			hold_time = maxf(float(step.get("hold_time")), 0.01)
		_text_label.text = line_text
		_text_label.visible = true
		_text_label.modulate.a = 0.0
		var fade_in := create_tween()
		fade_in.set_trans(Tween.TRANS_SINE)
		fade_in.set_ease(Tween.EASE_OUT)
		fade_in.tween_property(_text_label, "modulate:a", 1.0, fade_time)
		await fade_in.finished
		await _wait_seconds(maxf(hold_time, 0.01))
		var fade_out := create_tween()
		fade_out.set_trans(Tween.TRANS_SINE)
		fade_out.set_ease(Tween.EASE_IN)
		fade_out.tween_property(_text_label, "modulate:a", 0.0, fade_time)
		await fade_out.finished
	_text_label.visible = false
	_text_label.text = ""

## 执行视觉步骤（缺失时长时使用统一兜底）。
func _run_intro_visual_block(step: Dictionary) -> void:
	if not is_instance_valid(_visual_rect):
		return
	var visual_frames: Array[Texture2D] = _extract_visual_frames(step)
	if visual_frames.is_empty():
		return
	var frame_durations: PackedFloat32Array = _extract_frame_durations(step)
	var fade_time: float = maxf(unified_step_fade_duration, 0.01)
	for index in range(visual_frames.size()):
		var frame_tex: Texture2D = visual_frames[index]
		if frame_tex == null:
			continue
		_visual_rect.texture = frame_tex
		_visual_rect.visible = true
		_visual_rect.modulate.a = 0.0
		var frame_duration: float = maxf(unified_visual_hold_fallback_duration, 0.01)
		if index < frame_durations.size():
			frame_duration = maxf(float(frame_durations[index]), 0.01)
		var fade_in := create_tween()
		fade_in.set_trans(Tween.TRANS_SINE)
		fade_in.set_ease(Tween.EASE_OUT)
		fade_in.tween_property(_visual_rect, "modulate:a", 1.0, fade_time)
		await fade_in.finished
		await _wait_seconds(frame_duration)
		var fade_out := create_tween()
		fade_out.set_trans(Tween.TRANS_SINE)
		fade_out.set_ease(Tween.EASE_IN)
		fade_out.tween_property(_visual_rect, "modulate:a", 0.0, fade_time)
		await fade_out.finished
	_visual_rect.visible = false
	_visual_rect.texture = null

## 执行 BLACK_HOLD 步骤（统一固定时长）。
func _run_black_hold_block(_step: Dictionary) -> void:
	if not is_instance_valid(_black_rect):
		return
	_black_rect.visible = true
	_black_rect.color.a = 1.0
	await _wait_seconds(maxf(unified_black_hold_duration, 0.01))

## 将覆盖层平滑拉回纯黑。
func _fade_overlay_to_black() -> void:
	if not is_instance_valid(_black_rect):
		return
	_black_rect.visible = true
	var fade := create_tween()
	fade.set_trans(Tween.TRANS_SINE)
	fade.set_ease(Tween.EASE_IN_OUT)
	fade.tween_property(_black_rect, "color:a", 1.0, maxf(unified_step_fade_duration, 0.01))
	await fade.finished

func _run_reveal_phase(reveal_duration: float) -> void:
	var release_global_fade: bool = bool(_active_payload.get("release_global_fade_after_reveal", false))
	var debug_reveal_flow: bool = bool(_active_payload.get("debug_reveal_flow", false))
	var reveal_start_ms: int = Time.get_ticks_msec()
	var global_alpha_before: float = FadeManager.get_black_alpha() if FadeManager and FadeManager.has_method("get_black_alpha") else -1.0
	if debug_reveal_flow:
		print("BootCinematicDirector: reveal begin, duration=", reveal_duration, ", release_global_fade=", release_global_fade, ", has_black_hold=", FadeManager.has_black_hold() if FadeManager else false, ", global_alpha_before=", global_alpha_before)
	if release_global_fade:
		_release_black_hold_if_needed()
		if FadeManager and FadeManager.has_method("force_fade_in"):
			FadeManager.force_fade_in()
	# 始终使用本地覆盖层揭黑，确保 reveal_duration 可见且可控。
	await reveal_overlay_to_gameplay(reveal_duration)
	var global_alpha_after: float = FadeManager.get_black_alpha() if FadeManager and FadeManager.has_method("get_black_alpha") else -1.0
	if debug_reveal_flow:
		print("BootCinematicDirector: reveal finished, elapsed_ms=", Time.get_ticks_msec() - reveal_start_ms, ", global_alpha_after=", global_alpha_after)

## 从黑幕揭开到游戏画面。
func reveal_overlay_to_gameplay(duration: float = -1.0) -> void:
	if not is_instance_valid(_overlay_root) or not is_instance_valid(_black_rect):
		return
	var reveal_duration: float = DEFAULT_REVEAL_DURATION if duration < 0.0 else duration
	_black_rect.visible = true
	_black_rect.color.a = 1.0
	if reveal_duration <= 0.0:
		_black_rect.color.a = 0.0
		_overlay_root.visible = false
		return
	var fade := create_tween()
	fade.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	fade.set_trans(Tween.TRANS_SINE)
	fade.set_ease(Tween.EASE_OUT)
	fade.tween_property(_black_rect, "color:a", 0.0, reveal_duration)
	await fade.finished
	_overlay_root.visible = false

## 运行阻塞式事件演出（常用于房间首入事件）。
func play_blocking_intro_event(player_ref: Player, payload: Dictionary = {}) -> void:
	if _intro_running or _drop_running:
		return
	if not is_instance_valid(player_ref):
		return
	_player = player_ref
	_black_hold_released = false
	_active_payload = payload.get("payload", payload) if typeof(payload.get("payload", payload)) == TYPE_DICTIONARY else {}
	var pause_world: bool = bool(_active_payload.get("pause_world", true))
	var tree := get_tree()
	var paused_backup: bool = tree.paused if tree else false
	var runtime_restored_before_reveal: bool = false
	_cache_camera_nodes()
	_cache_player_runtime_switches()
	_enter_cinematic_control_mode()
	if pause_world and tree:
		tree.paused = true
	force_overlay_black()
	await play_intro_sequence(payload)
	if is_instance_valid(_player):
		if RoomManager and RoomManager.has_method("update_camera_limits"):
			RoomManager.update_camera_limits()
		if _player.has_method("sync_camera_to_player_center"):
			_player.sync_camera_to_player_center(true)
		if is_inside_tree():
			await get_tree().process_frame
	var started_room_autowalk: bool = false
	var autowalk_room_id: String = str(_active_payload.get("post_intro_autowalk_room_id", ""))
	if autowalk_room_id.strip_edges() != "" and is_instance_valid(_player) and _player.has_method("start_door_autowalk_to_dynamic_checkpoint"):
		if pause_world and tree and tree.paused:
			tree.paused = paused_backup
		started_room_autowalk = await _start_post_intro_autowalk_with_retry(autowalk_room_id)
		if started_room_autowalk:
			_restore_camera_behavior()
			_restore_player_runtime_switches()
			runtime_restored_before_reveal = true
			if tree:
				var warmup_frames: int = max(1, int(_active_payload.get("post_intro_autowalk_warmup_frames", 10)))
				for _i in range(warmup_frames):
					if not is_instance_valid(_player) or not _player.door_autowalk_active:
						break
					if not is_inside_tree() or get_tree() == null:
						break
					await tree.physics_frame
			if is_instance_valid(_player):
				if RoomManager and RoomManager.has_method("update_camera_limits"):
					RoomManager.update_camera_limits()
				if _player.has_method("sync_camera_to_player_center"):
					_player.sync_camera_to_player_center(true)
				if is_inside_tree():
					await get_tree().process_frame
	if is_instance_valid(_player) and not started_room_autowalk:
		if RoomManager and RoomManager.has_method("update_camera_limits"):
			RoomManager.update_camera_limits()
		if _player.has_method("sync_camera_to_player_center"):
			_player.sync_camera_to_player_center(true)
		if is_inside_tree():
			await get_tree().process_frame
	var reveal_duration: float = maxf(float(_active_payload.get("reveal_duration", DEFAULT_REVEAL_DURATION)), 0.0)
	await _run_reveal_phase(reveal_duration)
	if pause_world and tree and not started_room_autowalk:
		tree.paused = paused_backup
	if not runtime_restored_before_reveal:
		_restore_camera_behavior()
		_restore_player_runtime_switches()
	if is_instance_valid(_player):
		var autowalk_active: bool = _player.door_autowalk_active
		if _player.has_method("get"):
			autowalk_active = bool(_player.get("door_autowalk_active"))
		# 自动走位激活时由 DoorTraversalService 接管锁控与收尾，避免这里提前解控导致走位失效。
		if not autowalk_active:
			_player.velocity = Vector2.ZERO
			if _player.has_method("unlock_control"):
				_player.unlock_control()
			if _player.has_method("set_player_control"):
				_player.set_player_control(true)

## 等待指定秒数（可在暂停树中继续）。
func _wait_seconds(seconds: float) -> void:
	var wait_time: float = maxf(seconds, 0.0)
	var tree := get_tree()
	if tree == null:
		return
	if wait_time <= 0.0:
		await tree.process_frame
		return
	await tree.create_timer(wait_time, true).timeout

## 等待秒数并在 pause 状态下冻结计时。
func _wait_seconds_respecting_pause(seconds: float) -> void:
	var remaining: float = maxf(seconds, 0.0)
	var tree := get_tree()
	if tree == null:
		return
	if remaining <= 0.0:
		await tree.process_frame
		return
	var step: float = 1.0 / maxf(float(Engine.physics_ticks_per_second), 30.0)
	while remaining > 0.0:
		if not is_inside_tree():
			return
		tree = get_tree()
		if tree == null:
			return
		await tree.process_frame
		if tree.paused:
			continue
		remaining -= step

## 首入房间自动走位的短重试：等待检查点注册完成后再启动。
func _start_post_intro_autowalk_with_retry(autowalk_room_id: String) -> bool:
	if not is_instance_valid(_player):
		return false
	var retry_seconds: float = maxf(float(_active_payload.get("post_intro_autowalk_retry_seconds", 0.5)), 0.0)
	var elapsed: float = 0.0
	var step: float = 1.0 / maxf(float(Engine.physics_ticks_per_second), 30.0)
	while elapsed <= retry_seconds:
		if _player.has_method("start_door_autowalk_to_dynamic_checkpoint"):
			var autowalk_started: bool = bool(_player.start_door_autowalk_to_dynamic_checkpoint(autowalk_room_id, _player.global_position, _player.is_facing_right))
			if autowalk_started:
				return true
		if not is_inside_tree() or get_tree() == null:
			return false
		await get_tree().process_frame
		elapsed += step
	return false

## 返回默认揭黑时长。
func get_default_fade_duration() -> float:
	return DEFAULT_REVEAL_DURATION

## 解析文本行数组。
func _extract_text_lines(step: Dictionary) -> PackedStringArray:
	var raw_lines: Variant = step.get("lines", PackedStringArray([]))
	var lines := PackedStringArray()
	if raw_lines is PackedStringArray:
		return raw_lines
	if raw_lines is Array:
		for item in raw_lines:
			lines.append(str(item))
	return lines

## 解析视觉帧数组。
func _extract_visual_frames(step: Dictionary) -> Array[Texture2D]:
	var raw_frames: Variant = step.get("frames", [])
	var visual_frames: Array[Texture2D] = []
	if raw_frames is Array:
		for item in raw_frames:
			if item is Texture2D:
				visual_frames.append(item)
	return visual_frames

## 解析视觉时长数组。
func _extract_frame_durations(step: Dictionary) -> PackedFloat32Array:
	var raw_durations: Variant = step.get("frame_durations", PackedFloat32Array([]))
	if raw_durations is PackedFloat32Array:
		return raw_durations
	var durations := PackedFloat32Array([])
	if raw_durations is Array:
		for item in raw_durations:
			durations.append(float(item))
	return durations
