extends Node
class_name NewSaveOpeningEventDirector

@export_category("Binding")
## 新存档开场对应的初始房间 ID。
@export var opening_room_id: String = "Room1"
## Player 节点路径（相对本节点）。
@export var player_path: NodePath = NodePath("../../Player")
## BootCinematicDirector 节点路径（相对本节点）。
@export var boot_cinematic_director_path: NodePath = NodePath("../../BootCinematicDirector")

@export_category("Text Layout & Style")
## 文本水平对齐。
@export var intro_text_horizontal_alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER
## 文本垂直对齐。
@export var intro_text_vertical_alignment: VerticalAlignment = VERTICAL_ALIGNMENT_CENTER
## 文本主题资源。
@export var intro_text_theme: Theme
## 文本字号。
@export var intro_text_font_size: int = 40

@export_category("Intro Text")
## 是否启用文字步骤。
var intro_text_enabled: bool = true
## 文字内容数组，按顺序播放。
@export var intro_text_lines: PackedStringArray = PackedStringArray([])
## 每条文字对应停留时长数组（秒）。
@export var intro_text_line_hold_times: PackedFloat32Array = PackedFloat32Array([])

@export_category("Intro Visual Sequence")
## 是否启用视觉步骤。
var intro_visual_enabled: bool = true
## 视觉帧数组，按顺序播放。
@export var intro_visual_frames: Array[Texture2D] = []
## 视觉帧对应停留时长数组（秒）。
@export var intro_visual_frame_durations: PackedFloat32Array = PackedFloat32Array([])

@export_category("Sequence Mode")
## 简化序列顺序数组（TEXT/VISUAL/BLACK_HOLD）。
@export var intro_sequence_order: Array[BootCinematicDirector.IntroStepType] = []

@export_category("Gameplay Drop")
## 掉落演出开始镜头缩放值。
@export var gameplay_camera_start_zoom: float = 4.0
## 掉落演出目标镜头缩放值。
@export var gameplay_camera_target_zoom: float = 2.0
## 掉落镜头缩放过渡时长（秒）。
@export var gameplay_camera_zoom_duration: float = 4.0
## 掉落速度（像素/秒）。
@export var gameplay_drop_speed: float = 260.0
## 落地停留时长（秒）。
@export var gameplay_landing_settle_time: float = 5.0
## 掉落阶段动画名。
var gameplay_drop_animation_name: StringName = &"DOWN"
## 落地阶段动画名。
var gameplay_landed_animation_name: StringName = &"DIE"
## 收尾阶段动画名。
var gameplay_end_animation_name: StringName = &"IDLE"
## 控制锁标签。
var gameplay_lock_type: String = "event_cinematic"

@export_category("Reveal")
## 揭黑时长（秒）。
@export var reveal_duration: float = 2.5

## 掉落阶段最大等待时长（秒）。
const DROP_WAIT_MAX_SECONDS: float = 20.0

# 开场流程执行锁。
var _opening_running: bool = false

## 初始化执行模式。
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

## 播放新存档开场流程。
func play_opening(boot_request: Dictionary = {}) -> void:
	if _opening_running:
		return
	var player: Player = get_node_or_null(player_path)
	var boot_cinematic_director: BootCinematicDirector = get_node_or_null(boot_cinematic_director_path)
	if not is_instance_valid(player) or not is_instance_valid(boot_cinematic_director):
		return

	_opening_running = true
	if FadeManager and FadeManager.has_method("force_black"):
		FadeManager.force_black()
	if FadeManager and FadeManager.has_method("hold_black"):
		FadeManager.hold_black("new_save_opening")

	var opening_payload: Dictionary = _build_opening_payload(boot_request)
	var physics_process_backup: bool = player.is_physics_processing()
	var input_process_backup: bool = player.is_processing_input()

	if opening_room_id != "" and player.has_method("sync_room_and_camera_for_respawn"):
		await player.sync_room_and_camera_for_respawn(opening_room_id, true)
	elif player.has_method("sync_camera_to_player_center"):
		player.sync_camera_to_player_center(true)

	if player.has_method("lock_control"):
		player.lock_control(999.0, "new_save_intro")
	if player.has_method("set_player_control"):
		player.set_player_control(false)
	player.set_physics_process(false)

	if boot_cinematic_director.has_method("force_overlay_black"):
		boot_cinematic_director.force_overlay_black()
	await get_tree().process_frame
	await _await_boot_overlay_black_ready(boot_cinematic_director)
	opening_payload["player_physics_process_backup"] = physics_process_backup
	opening_payload["player_input_process_backup"] = input_process_backup
	await boot_cinematic_director.play_intro_sequence(opening_payload)
	boot_cinematic_director.start_gameplay_drop(player, opening_payload)

	var wait_elapsed: float = 0.0
	while boot_cinematic_director.has_method("is_gameplay_drop_running") and boot_cinematic_director.is_gameplay_drop_running() and wait_elapsed < DROP_WAIT_MAX_SECONDS:
		await get_tree().process_frame
		wait_elapsed += 1.0 / maxf(float(Engine.physics_ticks_per_second), 30.0)

	if boot_cinematic_director.has_method("is_gameplay_drop_running") and boot_cinematic_director.is_gameplay_drop_running():
		push_warning("NewSaveOpeningEventDirector: 掉落流程超时未结束，执行强制揭黑。")
		if boot_cinematic_director.has_method("reveal_overlay_to_gameplay"):
			await boot_cinematic_director.reveal_overlay_to_gameplay(reveal_duration)

	_opening_running = false

## 等待覆盖层黑幕准备完成。
func _await_boot_overlay_black_ready(boot_cinematic_director: BootCinematicDirector) -> void:
	if not is_instance_valid(boot_cinematic_director):
		return
	if not boot_cinematic_director.has_method("is_overlay_fully_black"):
		return
	for _i in range(6):
		if boot_cinematic_director.is_overlay_fully_black():
			return
		await get_tree().process_frame

## 等待 Intro 阶段开始。
func _await_intro_phase_started(boot_cinematic_director: BootCinematicDirector) -> void:
	if not is_instance_valid(boot_cinematic_director):
		return
	if not boot_cinematic_director.has_method("is_intro_running"):
		await get_tree().process_frame
		return
	for _i in range(30):
		if FadeManager and FadeManager.has_method("force_black"):
			FadeManager.force_black()
		if boot_cinematic_director.is_intro_running():
			await get_tree().process_frame
			return
		await get_tree().process_frame

## 等待 Intro 阶段结束。
func _await_intro_phase_finished(boot_cinematic_director: BootCinematicDirector) -> void:
	if not is_instance_valid(boot_cinematic_director):
		return
	if not boot_cinematic_director.has_method("is_intro_running"):
		await get_tree().process_frame
		return
	var timeout: float = 0.0
	while boot_cinematic_director.is_intro_running() and timeout < 30.0:
		if FadeManager and FadeManager.has_method("force_black"):
			FadeManager.force_black()
		await get_tree().process_frame
		timeout += 1.0 / maxf(float(Engine.physics_ticks_per_second), 30.0)

## 构建并返回开场执行参数。
func _build_opening_payload(boot_request: Dictionary = {}) -> Dictionary:
	var payload: Dictionary = {}
	if typeof(boot_request) == TYPE_DICTIONARY:
		if boot_request.has("payload") and typeof(boot_request.get("payload")) == TYPE_DICTIONARY:
			payload = (boot_request.get("payload") as Dictionary).duplicate(true)
		else:
			payload = boot_request.duplicate(true)

	payload["sequence_steps"] = _build_intro_sequence_steps()
	payload["intro_text_horizontal_alignment"] = intro_text_horizontal_alignment
	payload["intro_text_vertical_alignment"] = intro_text_vertical_alignment
	payload["intro_text_theme"] = intro_text_theme
	payload["intro_text_font_size"] = intro_text_font_size
	payload["gameplay_camera_start_zoom"] = gameplay_camera_start_zoom
	payload["gameplay_camera_target_zoom"] = gameplay_camera_target_zoom
	payload["gameplay_camera_zoom_duration"] = gameplay_camera_zoom_duration
	payload["gameplay_drop_speed"] = gameplay_drop_speed
	payload["gameplay_landing_settle_time"] = gameplay_landing_settle_time
	payload["gameplay_drop_animation_name"] = gameplay_drop_animation_name
	payload["gameplay_landed_animation_name"] = gameplay_landed_animation_name
	payload["gameplay_end_animation_name"] = gameplay_end_animation_name
	payload["gameplay_lock_type"] = gameplay_lock_type
	payload["reveal_duration"] = reveal_duration
	payload["release_global_fade_after_reveal"] = true
	payload["release_black_hold_tag"] = "new_save_opening"
	return payload

## 按简化顺序构建步骤列表。
func _build_intro_sequence_steps() -> Array:
	if intro_sequence_order.is_empty():
		return []

	var steps: Array = []
	var text_index: int = 0
	var visual_index: int = 0

	for step_type in intro_sequence_order:
		if step_type == BootCinematicDirector.IntroStepType.TEXT:
			if not intro_text_enabled:
				continue
			if text_index >= intro_text_lines.size():
				continue
			var text_step: Dictionary = {
				"type": BootCinematicDirector.IntroStepType.TEXT,
				"lines": PackedStringArray([intro_text_lines[text_index]])
			}
			if text_index < intro_text_line_hold_times.size():
				text_step["hold_time"] = maxf(float(intro_text_line_hold_times[text_index]), 0.0)
			steps.append(text_step)
			text_index += 1
		elif step_type == BootCinematicDirector.IntroStepType.VISUAL:
			if not intro_visual_enabled:
				continue
			if visual_index >= intro_visual_frames.size():
				continue
			var visual_step: Dictionary = {
				"type": BootCinematicDirector.IntroStepType.VISUAL,
				"frames": [intro_visual_frames[visual_index]]
			}
			if visual_index < intro_visual_frame_durations.size():
				visual_step["frame_durations"] = PackedFloat32Array([maxf(float(intro_visual_frame_durations[visual_index]), 0.0)])
			steps.append(visual_step)
			visual_index += 1
		elif step_type == BootCinematicDirector.IntroStepType.BLACK_HOLD:
			steps.append({
				"type": BootCinematicDirector.IntroStepType.BLACK_HOLD
			})

	return steps
