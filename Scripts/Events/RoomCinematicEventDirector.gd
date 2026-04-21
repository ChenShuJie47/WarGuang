extends Node
class_name RoomCinematicEventDirector

const ROOM_DREAM10_FIRST_ENTER_FLAG: String = "room_dream10_first_enter"

@export_category("Binding")
@export var player_path: NodePath = NodePath("../../Player")
@export var boot_cinematic_director_path: NodePath = NodePath("../../BootCinematicDirector")

@export_category("Room Event")
@export var roomdream10_first_enter_enabled: bool = true
@export var roomdream10_event_room_id: String = "RoomDream10"

@export_category("Text Layout & Style")
@export var intro_text_horizontal_alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER
@export var intro_text_vertical_alignment: VerticalAlignment = VERTICAL_ALIGNMENT_CENTER
@export var intro_text_theme: Theme
@export var intro_text_font_size: int = 40

@export_category("Intro Text")
var intro_text_enabled: bool = true
@export var intro_text_lines: PackedStringArray = PackedStringArray([])
@export var intro_text_line_hold_times: PackedFloat32Array = PackedFloat32Array([])

@export_category("Intro Visual Sequence")
var intro_visual_enabled: bool = true
@export var intro_visual_frames: Array[Texture2D] = []
@export var intro_visual_frame_durations: PackedFloat32Array = PackedFloat32Array([])

@export_category("Sequence Mode")
@export var intro_sequence_order: Array[BootCinematicDirector.IntroStepType] = []

@export_category("Reveal")
@export var reveal_duration: float = 0.45

var _room_event_running: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if RoomManager and RoomManager.has_signal("room_loaded") and not RoomManager.room_loaded.is_connected(_on_room_loaded):
		RoomManager.room_loaded.connect(_on_room_loaded)

func _exit_tree() -> void:
	if RoomManager and RoomManager.has_signal("room_loaded") and RoomManager.room_loaded.is_connected(_on_room_loaded):
		RoomManager.room_loaded.disconnect(_on_room_loaded)

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

func _play_roomdream10_first_enter_event() -> void:
	if _room_event_running:
		return
	var player: Player = get_node_or_null(player_path)
	var boot_cinematic_director: BootCinematicDirector = get_node_or_null(boot_cinematic_director_path)
	if not is_instance_valid(player) or not is_instance_valid(boot_cinematic_director):
		return

	_room_event_running = true
	if FadeManager and FadeManager.has_method("force_black"):
		FadeManager.force_black()

	var room_payload: Dictionary = _build_room_event_payload()
	await boot_cinematic_director.play_blocking_intro_event(player, room_payload)

	if Global and Global.has_method("set_cinematic_flag"):
		Global.set_cinematic_flag(ROOM_DREAM10_FIRST_ENTER_FLAG, true)
		if SaveManager and Global.current_save_slot >= 0 and SaveManager.has_method("save_game"):
			SaveManager.save_game(Global.current_save_slot, Global.get_save_data())
	_room_event_running = false

func _build_room_event_payload() -> Dictionary:
	var payload: Dictionary = {}
	payload["sequence_steps"] = _build_intro_sequence_steps()
	payload["intro_text_horizontal_alignment"] = intro_text_horizontal_alignment
	payload["intro_text_vertical_alignment"] = intro_text_vertical_alignment
	payload["intro_text_theme"] = intro_text_theme
	payload["intro_text_font_size"] = intro_text_font_size
	payload["pause_world"] = true
	payload["reveal_duration"] = reveal_duration
	return payload

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
