extends Node
class_name RoomCinematicEventDirector

enum EventStepType {
	TEXT,
	VISUAL,
	BLACK_HOLD
}

@export_category("Binding")
## 要监听的房间 ID。
@export var trigger_room_id: String = "RoomDream10"
## 本存档内一次性触发标记。
@export var trigger_flag_id: String = "room_dream10_first_enter"
## 是否启用该事件。
@export var event_enabled: bool = true
## 演出时是否暂停世界逻辑（推荐 true）。
@export var pause_world_during_event: bool = false

@export_category("Simple Text")
## 文本池（按 TEXT 顺序消费）。
@export var text_lines: PackedStringArray = PackedStringArray([])
## 每段文本独立停留时长（秒）；数量不足时回退到内部默认停留时长。
@export var text_line_hold_times: PackedFloat32Array = PackedFloat32Array([])

@export_category("Text Layout & Style")
## 水平对齐：控制文本在可视区域内的左右对齐（左/中/右）。
@export var text_horizontal_alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER
## 垂直对齐：控制文本在可视区域内的上下位置（上/中/下）。
@export var text_vertical_alignment: VerticalAlignment = VERTICAL_ALIGNMENT_CENTER
## 文本主题资源（如 Theme9x9.tres）；为空时使用默认主题。
@export var text_theme: Theme
## 文本字号（当 theme 未提供对应字体大小时生效）。
@export var text_font_size: int = 28

@export_category("Simple Visual")
## 视觉帧（按 VISUAL 顺序消费）。
@export var visual_frames: Array[Texture2D] = []
## 视觉时长（秒）。
@export var visual_frame_durations: PackedFloat32Array = PackedFloat32Array([1.8, 2.1])

@export_category("Sequence Mode")
## 步骤顺序（可直接选择 TEXT/VISUAL/BLACK_HOLD）。
@export var event_order: Array[EventStepType] = []

@export_category("Node Paths")
## Player 节点路径（相对本节点）。
@export var player_path: NodePath = NodePath("../../Player")
## BootCinematicDirector 节点路径（相对本节点）。
@export var cinematic_director_path: NodePath = NodePath("../../BootCinematicDirector")

# Internal Runtime State
## 当前事件是否正在播放，防止重入。
var _event_running: bool = false

const _ROOM_TRANSITION_SETTLE_TIMEOUT: float = 0.35
const _BLACK_WINDOW_WAIT_TIMEOUT: float = 1.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if RoomManager and RoomManager.has_signal("room_loaded") and not RoomManager.room_loaded.is_connected(_on_room_loaded):
		RoomManager.room_loaded.connect(_on_room_loaded)
	call_deferred("_try_play_on_ready")

func _try_play_on_ready() -> void:
	if not event_enabled:
		return
	if trigger_room_id.strip_edges() == "":
		return
	if _event_running:
		return
	if Global and Global.has_method("has_cinematic_flag") and Global.has_cinematic_flag(trigger_flag_id):
		return
	if RoomManager and String(RoomManager.current_room) == trigger_room_id:
		call_deferred("_play_event")

func _on_room_loaded(room_id: String, _previous_room: String) -> void:
	if not event_enabled:
		return
	if trigger_room_id.strip_edges() == "" or room_id != trigger_room_id:
		return
	if _event_running:
		return
	if Global and Global.has_method("has_cinematic_flag") and Global.has_cinematic_flag(trigger_flag_id):
		return
	call_deferred("_play_event")

func _play_event() -> void:
	if _event_running:
		return
	var player: Player = get_node_or_null(player_path)
	var cinematic_director: BootCinematicDirector = get_node_or_null(cinematic_director_path)
	if not is_instance_valid(player) or not is_instance_valid(cinematic_director):
		return

	_event_running = true
	var timing_defaults: Dictionary = cinematic_director.get_default_cinematic_timing_defaults() if cinematic_director.has_method("get_default_cinematic_timing_defaults") else {}
	var settled: bool = await _await_room_transition_settle(player)
	if not settled:
		_event_running = false
		call_deferred("_play_event")
		return
	await _await_black_window_or_timeout()
	if FadeManager and FadeManager.has_method("is_fully_black") and not FadeManager.is_fully_black():
		FadeManager.force_black()
	if cinematic_director.has_method("force_overlay_black"):
		cinematic_director.force_overlay_black()
	await get_tree().process_frame
	if FadeManager and FadeManager.has_method("force_fade_in"):
		FadeManager.force_fade_in()

	var runtime_steps: Array = _build_runtime_steps(cinematic_director, timing_defaults)
	await cinematic_director.play_blocking_intro_event(player, {
		"sequence_steps": runtime_steps,
		"reveal_duration": float(timing_defaults.get("fade_duration", 0.5)),
		"pause_world": pause_world_during_event,
		"freeze_player": false,
		"intro_text_horizontal_alignment": text_horizontal_alignment,
		"intro_text_vertical_alignment": text_vertical_alignment,
		"intro_text_theme": text_theme,
		"intro_text_font_size": text_font_size
	})

	if Global and Global.has_method("set_cinematic_flag"):
		Global.set_cinematic_flag(trigger_flag_id, true)
		if SaveManager and Global.current_save_slot >= 0 and SaveManager.has_method("save_game"):
			SaveManager.save_game(Global.current_save_slot, Global.get_save_data())
	_event_running = false

func _build_runtime_steps(_cinematic_director: BootCinematicDirector, timing_defaults: Dictionary = {}) -> Array:
	var runtime_frames: Array[Texture2D] = visual_frames.duplicate()
	# 不再回退到 Boot 开场素材，避免首次进入 RoomDream10 误播“新存档开场”视觉序列。
	var default_text_hold: float = float(timing_defaults.get("text_hold", 1.8))
	var default_visual_frame_time: float = float(timing_defaults.get("visual_frame", 2.0))
	var default_black_hold: float = float(timing_defaults.get("black_hold", 0.2))
	var default_fade_duration: float = float(timing_defaults.get("fade_duration", 0.5))

	var steps: Array = []
	var text_index: int = 0
	var frame_index: int = 0
	for token_type in event_order:
		if int(token_type) == int(EventStepType.TEXT):
			var line_block := PackedStringArray([])
			var hold_block := PackedFloat32Array([])
			if text_index < text_lines.size():
				line_block.append(text_lines[text_index])
				var text_hold_value: float = default_text_hold
				if text_index < text_line_hold_times.size():
					text_hold_value = maxf(float(text_line_hold_times[text_index]), 0.01)
				hold_block.append(text_hold_value)
				text_index += 1
			elif text_lines.size() > 0:
				line_block = text_lines
				hold_block = text_line_hold_times
			if line_block.size() > 0:
				steps.append({
					"type": "TEXT",
					"lines": line_block,
					"hold_time": default_text_hold,
					"line_hold_times": hold_block,
					"fade_time": default_fade_duration
				})
		elif int(token_type) == int(EventStepType.VISUAL):
			if runtime_frames.is_empty():
				continue
			var frame_block: Array[Texture2D] = []
			var duration_block := PackedFloat32Array([])
			if frame_index < runtime_frames.size():
				frame_block.append(runtime_frames[frame_index])
				var duration_value: float = default_visual_frame_time
				if frame_index < visual_frame_durations.size():
					duration_value = maxf(float(visual_frame_durations[frame_index]), 0.01)
				duration_block.append(duration_value)
				frame_index += 1
			else:
				frame_block = runtime_frames
				duration_block = visual_frame_durations
			steps.append({
				"type": "VISUAL",
				"frames": frame_block,
				"frame_durations": duration_block,
				"default_frame_time": default_visual_frame_time,
				"fade_time": default_fade_duration
			})
		elif int(token_type) == int(EventStepType.BLACK_HOLD):
			steps.append({
				"type": "BLACK_HOLD",
				"hold_time": default_black_hold
			})

	if steps.is_empty():
		steps.append({"type": "BLACK_HOLD", "hold_time": default_black_hold})
	return steps

func _await_room_transition_settle(player: Player) -> bool:
	if not is_instance_valid(player):
		return false
	await get_tree().process_frame
	await get_tree().physics_frame
	var elapsed: float = 0.0
	while elapsed < _ROOM_TRANSITION_SETTLE_TIMEOUT:
		if not is_instance_valid(player):
			return false
		await get_tree().physics_frame
		elapsed += 1.0 / maxf(float(Engine.physics_ticks_per_second), 30.0)
	return true

func _await_black_window_or_timeout() -> void:
	if not (FadeManager and FadeManager.has_method("is_fully_black")):
		return
	var elapsed: float = 0.0
	while elapsed < _BLACK_WINDOW_WAIT_TIMEOUT and not FadeManager.is_fully_black():
		await get_tree().process_frame
		elapsed += 1.0 / maxf(float(Engine.physics_ticks_per_second), 30.0)
