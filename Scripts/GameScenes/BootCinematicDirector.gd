extends CanvasLayer
class_name BootCinematicDirector

signal intro_sequence_finished
signal gameplay_drop_started
signal gameplay_drop_finished

enum IntroStepType {
	TEXT,
	VISUAL,
	BLACK_HOLD
}

@export_category("Intro Text")
## 是否默认启用文字阶段；事件演出可在 payload 中关闭。
@export var intro_text_enabled_by_default: bool = true
## 开场文字分段，按顺序逐段播放。
@export var intro_text_lines: PackedStringArray = ["序章", "黑暗正在退去", "新的旅程开始了"]
## 每段文字停留时长（秒）。
@export var intro_text_hold_time: float = 2.5
## 每段文字淡入淡出时长（秒）。
@export var intro_text_fade_time: float = 0.5

@export_category("Intro Visual Sequence")
## 是否默认启用视觉序列阶段；事件演出可在 payload 中关闭。
@export var intro_visual_enabled_by_default: bool = true
## 视觉序列帧列表（按顺序播放，不需要帧动画资源）。
@export var intro_visual_frames: Array[Texture2D] = []
## 每帧持续时长（秒）；数量不足时回退到默认时长。
@export var intro_visual_frame_durations: PackedFloat32Array = PackedFloat32Array([])
## 视觉序列单帧默认时长（秒）。
@export var intro_visual_default_frame_time: float = 1.2
## 视觉序列切换淡入淡出时长（秒）。
@export var intro_visual_fade_time: float = 0.5
## 按顺序播放的开场步骤列表；留空时回退到默认步骤。
@export var intro_sequence_steps: Array[Dictionary] = []

@export_category("Gameplay Drop")
## 掉落演出开始时使用的相机缩放值。
@export var gameplay_camera_start_zoom: float = 4.0
## 掉落演出结束后恢复的相机缩放值。
@export var gameplay_camera_target_zoom: float = 2.0
## 相机从起始缩放过渡到目标缩放所需时长（秒）。
@export var gameplay_camera_zoom_duration: float = 4.0
## 演出式掉落速度（像素/秒），独立于 Player 常规下落速度。
@export var gameplay_drop_speed: float = 180.0
## 落地后 DIE 演出停留时间（秒）。
@export var gameplay_landing_settle_time: float = 5.0
## 掉落演出动画名（直接驱动 AnimatedSprite2D，不改状态机）。
@export var gameplay_drop_animation_name: StringName = &"DOWN"
## 落地后停留阶段动画名（直接驱动 AnimatedSprite2D，不改状态机）。
@export var gameplay_landed_animation_name: StringName = &"DIE"
## 交还控制前恢复动画名（直接驱动 AnimatedSprite2D，不改状态机）。
@export var gameplay_end_animation_name: StringName = &"IDLE"
## 控制锁类型标签，仅用于日志与排查：
## 推荐值：opening_cinematic（新存档开场）、boss_cinematic（Boss 演出）、event_cinematic（剧情事件）
@export var gameplay_lock_type: String = "opening_cinematic"

# 当前是否正在播放任意导入阶段。
var _intro_running: bool = false
# 当前是否正在进行演出式掉落。
var _drop_running: bool = false
# 当前掉落演出是否已经正式开始。
var _drop_started: bool = false
# 当前序列参数（来自 payload 或默认配置）。
var _active_payload: Dictionary = {}

# 演出控制中的玩家实例。
var _player: Player = null
# 玩家相机控制器引用。
var _camera_controller: PlayerCameraController = null
# 玩家 PhantomCamera2D 引用。
var _phantom_camera: Node = null
# 主 Camera2D 引用。
var _camera_2d: Camera2D = null

# 覆盖层根节点。
var _overlay_root: Control = null
# 黑幕节点。
var _black_rect: ColorRect = null
# 文本节点。
var _text_label: RichTextLabel = null
# 视觉帧显示节点。
var _visual_rect: TextureRect = null

# 演出前 lookahead 开关备份。
var _lookahead_backup: bool = true
# 演出前 focus capture 开关备份。
var _focus_capture_backup: bool = true
# 演出前玩家物理处理开关备份。
var _player_physics_process_backup: bool = true
# 演出前玩家输入处理开关备份。
var _player_input_process_backup: bool = true
# 演出前玩家动画缓存字符串备份。
var _player_current_animation_backup: String = ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 1105
	_build_overlay()
	if is_instance_valid(_overlay_root):
		_overlay_root.visible = false

func play_sequence(_sequence_id: StringName, payload: Dictionary = {}) -> void:
	# 事件侧按需开启阶段：不提供统一强制流程。
	var run_intro: bool = bool(payload.get("run_intro_phase", false))
	var run_drop: bool = bool(payload.get("run_drop_phase", false))
	if run_intro:
		await play_intro_sequence(payload)
	if run_drop:
		var target_player: Player = payload.get("player_ref", null)
		if is_instance_valid(target_player):
			start_gameplay_drop(target_player, payload)
			while not _drop_started:
				await get_tree().process_frame

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

func start_gameplay_drop(player_ref: Player, payload: Dictionary = {}) -> void:
	if _drop_running:
		return
	_drop_running = true
	_drop_started = false
	_player = player_ref
	_active_payload = payload.get("payload", payload) if typeof(payload.get("payload", payload)) == TYPE_DICTIONARY else {}
	call_deferred("_start_drop_flow_deferred")

func _start_drop_flow_deferred() -> void:
	await _start_drop_flow()

func is_gameplay_drop_started() -> bool:
	return _drop_started

func _start_drop_flow() -> void:
	if not is_instance_valid(_player):
		_drop_started = true
		gameplay_drop_started.emit()
		gameplay_drop_finished.emit()
		_drop_running = false
		return
	_cache_camera_nodes()
	_cache_player_runtime_switches()
	_enter_cinematic_control_mode()

	# 这里是对 SceneManager 的关键同步点：只有真正开始掉落才允许外部淡入。
	_drop_started = true
	gameplay_drop_started.emit()
	_apply_gameplay_overlay_visibility(false)

	var drop_speed: float = maxf(float(_active_payload.get("gameplay_drop_speed", gameplay_drop_speed)), 10.0)
	var zoom_from: float = float(_active_payload.get("gameplay_camera_start_zoom", gameplay_camera_start_zoom))
	var zoom_to: float = float(_active_payload.get("gameplay_camera_target_zoom", gameplay_camera_target_zoom))
	var zoom_duration: float = maxf(float(_active_payload.get("gameplay_camera_zoom_duration", gameplay_camera_zoom_duration)), 0.05)

	_set_camera_zoom(zoom_from)
	if is_instance_valid(_player):
		_play_player_animation(gameplay_drop_animation_name)

	var zoom_tween := create_tween()
	zoom_tween.set_trans(Tween.TRANS_SINE)
	zoom_tween.set_ease(Tween.EASE_OUT)
	zoom_tween.tween_method(Callable(self, "_apply_zoom_step"), zoom_from, zoom_to, zoom_duration)

	var landed: bool = false
	while is_instance_valid(_player):
		await get_tree().physics_frame
		if not is_instance_valid(_player):
			break
		if _manual_drop_step(drop_speed):
			landed = true
			break

	if landed and is_instance_valid(_player):
		_play_player_animation(gameplay_landed_animation_name)
		await get_tree().create_timer(maxf(gameplay_landing_settle_time, 0.1)).timeout

	if is_instance_valid(_player):
		_play_player_animation(gameplay_end_animation_name)
		_player.velocity = Vector2.ZERO
		_player.current_animation = ""
		if _player.current_state != _player.PlayerState.IDLE:
			_player.change_state(_player.PlayerState.IDLE)
		if _player.has_method("unlock_control"):
			_player.unlock_control()
		if _player.has_method("set_player_control"):
			_player.set_player_control(true)

	_restore_camera_behavior()
	_restore_player_runtime_switches()
	_drop_running = false
	gameplay_drop_finished.emit()

func _manual_drop_step(drop_speed: float) -> bool:
	if not is_instance_valid(_player):
		return true
	var delta: float = 1.0 / maxf(float(Engine.physics_ticks_per_second), 30.0)
	var motion: Vector2 = Vector2.DOWN * drop_speed * delta
	var collision := _player.move_and_collide(motion)
	if collision:
		_player.velocity = Vector2.ZERO
		return true
	return false

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

func _apply_gameplay_overlay_visibility(show_overlay: bool) -> void:
	if is_instance_valid(_overlay_root):
		_overlay_root.visible = show_overlay

func _cache_camera_nodes() -> void:
	if not is_instance_valid(_player):
		return
	_camera_controller = _player.camera_controller
	_phantom_camera = _player.get_node_or_null("PhantomCamera2D")
	_camera_2d = _player.get_viewport().get_camera_2d() if _player.get_viewport() else null
	if _camera_controller and _camera_controller.has_method("get"):
		_lookahead_backup = bool(_camera_controller.get("lookahead_enabled"))
		_focus_capture_backup = bool(_camera_controller.get("focus_capture_enabled"))

func _cache_player_runtime_switches() -> void:
	if not is_instance_valid(_player):
		return
	_player_physics_process_backup = _player.is_physics_processing()
	_player_input_process_backup = _player.is_processing_input()
	_player_current_animation_backup = _player.current_animation

func _enter_cinematic_control_mode() -> void:
	if not is_instance_valid(_player):
		return
	if _camera_controller and _camera_controller.has_method("set"):
		_camera_controller.set("lookahead_enabled", false)
		_camera_controller.set("focus_capture_enabled", false)
	if _player.has_method("lock_control"):
		_player.lock_control(999.0, gameplay_lock_type)
	if _player.has_method("set_player_control"):
		_player.set_player_control(false)
	_player.set_physics_process(false)
	_player.velocity = Vector2.ZERO

func _restore_player_runtime_switches() -> void:
	if not is_instance_valid(_player):
		return
	_player.set_physics_process(_player_physics_process_backup)
	_player.set_process_input(_player_input_process_backup)
	_player.current_animation = _player_current_animation_backup

func _restore_camera_behavior() -> void:
	if _camera_controller and _camera_controller.has_method("set"):
		_camera_controller.set("lookahead_enabled", _lookahead_backup)
		_camera_controller.set("focus_capture_enabled", _focus_capture_backup)

func _set_camera_zoom(zoom_value: float) -> void:
	var zoom_vector := Vector2.ONE * maxf(zoom_value, 0.01)
	if is_instance_valid(_phantom_camera):
		if _phantom_camera.has_method("set_zoom"):
			_phantom_camera.set_zoom(zoom_vector)
		else:
			_phantom_camera.zoom = zoom_vector
	if is_instance_valid(_camera_2d):
		_camera_2d.zoom = zoom_vector

func _apply_zoom_step(zoom_value: float) -> void:
	_set_camera_zoom(zoom_value)

func _play_player_animation(anim_name: StringName) -> void:
	if not is_instance_valid(_player):
		return
	if not is_instance_valid(_player.animated_sprite):
		return
	var anim_text := String(anim_name)
	if anim_text == "":
		return
	if _player.animated_sprite.sprite_frames and _player.animated_sprite.sprite_frames.has_animation(anim_text):
		_player.animated_sprite.play(anim_text)

func _run_intro_sequence_steps() -> void:
	var sequence_steps: Array = _active_payload.get("sequence_steps", intro_sequence_steps)
	sequence_steps = sequence_steps.duplicate(true)
	if sequence_steps.is_empty():
		var use_intro_text: bool = _active_payload.get("use_intro_text", intro_text_enabled_by_default)
		var use_intro_visual: bool = _active_payload.get("use_intro_visual", intro_visual_enabled_by_default)
		if use_intro_text:
			sequence_steps.append({"type": IntroStepType.TEXT, "lines": intro_text_lines})
		if use_intro_visual:
			sequence_steps.append({"type": IntroStepType.VISUAL, "frames": intro_visual_frames, "frame_durations": intro_visual_frame_durations})
	for step in sequence_steps:
		if typeof(step) != TYPE_DICTIONARY:
			continue
		await _run_intro_step(step)

func _run_intro_step(step: Dictionary) -> void:
	var step_type: int = int(step.get("type", IntroStepType.BLACK_HOLD))
	match step_type:
		IntroStepType.TEXT:
			await _run_intro_text_block(step)
		IntroStepType.VISUAL:
			await _run_intro_visual_block(step)
		IntroStepType.BLACK_HOLD:
			await _run_black_hold_block(step)
		_:
			await _run_black_hold_block(step)

func _run_intro_text_block(step: Dictionary) -> void:
	var lines: PackedStringArray = step.get("lines", _active_payload.get("intro_text_lines", intro_text_lines))
	if lines.is_empty():
		return
	var hold_time: float = float(step.get("hold_time", _active_payload.get("intro_text_hold_time", intro_text_hold_time)))
	var fade_time: float = float(step.get("fade_time", _active_payload.get("intro_text_fade_time", intro_text_fade_time)))
	for line_text in lines:
		if line_text.strip_edges() == "":
			continue
		if not is_instance_valid(_text_label):
			return
		_text_label.text = line_text
		_text_label.visible = true
		_text_label.modulate.a = 0.0
		var fade_in := create_tween()
		fade_in.set_trans(Tween.TRANS_SINE)
		fade_in.set_ease(Tween.EASE_OUT)
		fade_in.tween_property(_text_label, "modulate:a", 1.0, maxf(fade_time, 0.01))
		await fade_in.finished
		await get_tree().create_timer(maxf(hold_time, 0.01)).timeout
		var fade_out := create_tween()
		fade_out.set_trans(Tween.TRANS_SINE)
		fade_out.set_ease(Tween.EASE_IN)
		fade_out.tween_property(_text_label, "modulate:a", 0.0, maxf(fade_time, 0.01))
		await fade_out.finished
	_text_label.visible = false
	_text_label.text = ""

func _run_intro_visual_block(step: Dictionary) -> void:
	if not is_instance_valid(_visual_rect):
		return
	var visual_frames: Array[Texture2D] = step.get("frames", _active_payload.get("intro_visual_frames", intro_visual_frames))
	if visual_frames.is_empty():
		return
	var frame_durations: PackedFloat32Array = step.get("frame_durations", _active_payload.get("intro_visual_frame_durations", intro_visual_frame_durations))
	var default_frame_time: float = float(step.get("default_frame_time", _active_payload.get("intro_visual_default_frame_time", intro_visual_default_frame_time)))
	var fade_time: float = float(step.get("fade_time", _active_payload.get("intro_visual_fade_time", intro_visual_fade_time)))
	for index in range(visual_frames.size()):
		var frame_tex: Texture2D = visual_frames[index]
		if frame_tex == null:
			continue
		_visual_rect.texture = frame_tex
		_visual_rect.visible = true
		_visual_rect.modulate.a = 0.0
		var frame_duration: float = default_frame_time
		if index < frame_durations.size():
			frame_duration = maxf(float(frame_durations[index]), 0.01)
		var fade_in := create_tween()
		fade_in.set_trans(Tween.TRANS_SINE)
		fade_in.set_ease(Tween.EASE_OUT)
		fade_in.tween_property(_visual_rect, "modulate:a", 1.0, maxf(fade_time, 0.01))
		await fade_in.finished
		await get_tree().create_timer(frame_duration).timeout
		var fade_out := create_tween()
		fade_out.set_trans(Tween.TRANS_SINE)
		fade_out.set_ease(Tween.EASE_IN)
		fade_out.tween_property(_visual_rect, "modulate:a", 0.0, maxf(fade_time, 0.01))
		await fade_out.finished
	_visual_rect.visible = false
	_visual_rect.texture = null

func _run_black_hold_block(step: Dictionary) -> void:
	if not is_instance_valid(_black_rect):
		return
	_black_rect.visible = true
	_black_rect.color.a = 1.0
	var hold_time: float = float(step.get("hold_time", 0.35))
	if hold_time > 0.0:
		await get_tree().create_timer(hold_time).timeout

func _fade_overlay_to_black() -> void:
	if not is_instance_valid(_black_rect):
		return
	_black_rect.visible = true
	var fade := create_tween()
	fade.set_trans(Tween.TRANS_SINE)
	fade.set_ease(Tween.EASE_IN_OUT)
	fade.tween_property(_black_rect, "color:a", 1.0, 0.35)
	await fade.finished
