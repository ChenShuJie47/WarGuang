extends Node
class_name RoomCinematicEventDirector

## RoomDream10 首入标记，存档中只允许播放一次。
const ROOM_DREAM10_FIRST_ENTER_FLAG: String = "room_dream10_first_enter"
## RoomDream10 首入黑幕锁标签，用于与 FadeManager 的黑幕持有逻辑对齐。
const ROOM_DREAM10_BLACK_HOLD_TAG: String = "room_dream10_first_enter"

@export_category("Binding")
## Player 节点路径，用于执行首入演出和后续状态恢复。
@export var player_path: NodePath = NodePath("../../Player")
## BootCinematicDirector 节点路径，用于驱动统一的阻塞式开场/事件演出。
@export var boot_cinematic_director_path: NodePath = NodePath("../../BootCinematicDirector")

@export_category("Room Event")
## 是否启用 RoomDream10 首次进入事件。
@export var roomdream10_first_enter_enabled: bool = true
## 首次进入事件的目标房间 ID。
@export var roomdream10_event_room_id: String = "RoomDream10"
## 事件接管前的短黑幕缓冲时长，用于衔接正常切房黑屏与事件动画。
@export var roomdream10_pre_event_black_hold_duration: float = 0.35

@export_category("Text Layout & Style")
## 事件文字水平对齐方式。
@export var intro_text_horizontal_alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER
## 事件文字垂直对齐方式。
@export var intro_text_vertical_alignment: VerticalAlignment = VERTICAL_ALIGNMENT_CENTER
## 事件文字主题。
@export var intro_text_theme: Theme
## 事件文字字号。
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
## 简化序列顺序数组，使用 BootCinematicDirector.IntroStepType 枚举值。
@export var intro_sequence_order: Array[BootCinematicDirector.IntroStepType] = []

@export_category("Reveal")
## 揭黑时长（秒），由 BootCinematicDirector 在 reveal 阶段执行。
@export var reveal_duration: float = 1.5

## 是否输出 RoomDream10 首入流程调试日志。
@export var debug_roomdream10_flow: bool = false

## 当前房间首入事件是否正在执行。
var _room_event_running: bool = false

## 初始化 RoomDream10 首入事件监听。
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if RoomManager and RoomManager.has_signal("room_loaded") and not RoomManager.room_loaded.is_connected(_on_room_loaded):
		RoomManager.room_loaded.connect(_on_room_loaded)

## 退出树时解除房间加载信号连接。
func _exit_tree() -> void:
	if RoomManager and RoomManager.has_signal("room_loaded") and RoomManager.room_loaded.is_connected(_on_room_loaded):
		RoomManager.room_loaded.disconnect(_on_room_loaded)

## 房间加载回调：仅在目标房间且未播放过时触发首入事件。
func _on_room_loaded(room_id: String, _previous_room: String) -> void:
	if not roomdream10_first_enter_enabled:
		return
	if room_id != roomdream10_event_room_id:
		return
	if _room_event_running:
		return
	if Global and Global.has_method("has_cinematic_flag") and Global.has_cinematic_flag(ROOM_DREAM10_FIRST_ENTER_FLAG):
		return
	call_deferred("_play_roomdream10_first_enter_event")

## 播放 RoomDream10 首次进入事件。
func _play_roomdream10_first_enter_event() -> void:
	if _room_event_running:
		return
	var player: Player = get_node_or_null(player_path)
	var boot_cinematic_director: BootCinematicDirector = get_node_or_null(boot_cinematic_director_path)
	if not is_instance_valid(player) or not is_instance_valid(boot_cinematic_director):
		return

	_room_event_running = true
	if debug_roomdream10_flow:
		print("RoomCinematicEventDirector: RoomDream10 first-enter begin, reveal_duration=", reveal_duration)
	if FadeManager and FadeManager.has_method("hold_black"):
		FadeManager.hold_black(ROOM_DREAM10_BLACK_HOLD_TAG)
	if FadeManager and FadeManager.has_method("force_black"):
		FadeManager.force_black()
	if is_inside_tree() and get_tree() != null:
		await get_tree().process_frame
		await get_tree().physics_frame
		var pre_hold: float = maxf(roomdream10_pre_event_black_hold_duration, 0.0)
		if pre_hold > 0.0:
			await get_tree().create_timer(pre_hold, true).timeout

	var room_payload: Dictionary = _build_room_event_payload()
	if debug_roomdream10_flow:
		print("RoomCinematicEventDirector: payload=", room_payload)
	await boot_cinematic_director.play_blocking_intro_event(player, room_payload)

	if Global and Global.has_method("set_cinematic_flag"):
		Global.set_cinematic_flag(ROOM_DREAM10_FIRST_ENTER_FLAG, true)
		if SaveManager and Global.current_save_slot >= 0 and SaveManager.has_method("save_game"):
			SaveManager.save_game(Global.current_save_slot, Global.get_save_data())
	_room_event_running = false
	if debug_roomdream10_flow:
		print("RoomCinematicEventDirector: RoomDream10 first-enter finished")

## 构建传给 BootCinematicDirector 的首入事件负载。
func _build_room_event_payload() -> Dictionary:
	var payload: Dictionary = {}
	payload["sequence_steps"] = _build_intro_sequence_steps()
	payload["intro_text_horizontal_alignment"] = intro_text_horizontal_alignment
	payload["intro_text_vertical_alignment"] = intro_text_vertical_alignment
	payload["intro_text_theme"] = intro_text_theme
	payload["intro_text_font_size"] = intro_text_font_size
	payload["pause_world"] = true
	payload["reveal_duration"] = reveal_duration
	payload["release_global_fade_after_reveal"] = true
	payload["release_black_hold_tag"] = ROOM_DREAM10_BLACK_HOLD_TAG
	payload["post_intro_autowalk_room_id"] = roomdream10_event_room_id
	payload["debug_reveal_flow"] = debug_roomdream10_flow
	return payload

## 按简化顺序构建首入动画步骤。
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
