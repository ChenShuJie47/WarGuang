extends Node
class_name RoomCinematicEventDirector

const ROOM_DREAM10_FIRST_ENTER_FLAG: String = "room_dream10_first_enter"

@export_category("Binding")
## Player 节点路径（相对本节点）。
@export var player_path: NodePath = NodePath("../../Player")
## BootCinematicDirector 节点路径（相对本节点）。
@export var boot_cinematic_director_path: NodePath = NodePath("../../BootCinematicDirector")

@export_category("Room Event")
## 是否启用首次进入 RoomDream10 的事件演出。
@export var roomdream10_first_enter_enabled: bool = true
## 首入事件目标房间 ID。
@export var roomdream10_event_room_id: String = "RoomDream10"

@export_category("Intro Text")
## 是否默认启用文字阶段；事件演出可在开场配置中关闭。
@export var intro_text_enabled_by_default: bool = true
## 开场文字分段，按顺序逐段播放。
@export var intro_text_lines: PackedStringArray = PackedStringArray([])
## 每段文字独立停留时长（秒）。
@export var intro_text_hold_time: float = 2.5
## 每段文字淡入淡出时长（秒）。
@export var intro_text_fade_time: float = 0.5
## 水平对齐：控制文本在可视区域内的左右对齐（左/中/右）。
@export var intro_text_horizontal_alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER
## 垂直对齐：控制文本在可视区域内的上下位置（上/中/下）。
@export var intro_text_vertical_alignment: VerticalAlignment = VERTICAL_ALIGNMENT_CENTER
## 文本主题资源（如 Theme9x9.tres）；为空时使用默认主题。
@export var intro_text_theme: Theme
## 文本字号（当 theme 未提供对应字体大小时生效）。
@export var intro_text_font_size: int = 40

@export_category("Intro Visual Sequence")
## 是否默认启用视觉序列阶段；事件演出可在开场配置中关闭。
@export var intro_visual_enabled_by_default: bool = true
## 视觉序列帧列表（按顺序播放，不需要帧动画资源）。
@export var intro_visual_frames: Array[Texture2D] = []
## 每帧持续时长（秒）。
@export var intro_visual_frame_durations: PackedFloat32Array = PackedFloat32Array([])
## 视觉序列单帧默认时长（秒）。
@export var intro_visual_default_frame_time: float = 1.2
## 视觉序列切换淡入淡出时长（秒）。
@export var intro_visual_fade_time: float = 0.5

@export_category("Sequence Mode")
## 按顺序播放的开场步骤。
@export var intro_sequence_order: PackedStringArray = PackedStringArray([])
## 按顺序播放的开场步骤（显式字典）。
@export var intro_sequence_steps: Array[Dictionary] = []

@export_category("Gameplay Drop")
## 掉落演出开始时使用的相机缩放值。
@export var gameplay_camera_start_zoom: float = 4.0
## 掉落演出结束后恢复的相机缩放值。
@export var gameplay_camera_target_zoom: float = 2.0
## 相机从起始缩放过渡到目标缩放所需时长（秒）。
@export var gameplay_camera_zoom_duration: float = 4.0
## 演出式掉落速度（像素/秒），独立于 Player 常规下落速度。
@export var gameplay_drop_speed: float = 260.0
## 落地后停留时间（秒）。
@export var gameplay_landing_settle_time: float = 5.0
## 掉落演出动画名（直接驱动 AnimatedSprite2D，不改状态机）。
@export var gameplay_drop_animation_name: StringName = &"DOWN"
## 落地后停留阶段动画名（直接驱动 AnimatedSprite2D，不改状态机）。
@export var gameplay_landed_animation_name: StringName = &"DIE"
## 交还控制前恢复动画名（直接驱动 AnimatedSprite2D，不改状态机）。
@export var gameplay_end_animation_name: StringName = &"IDLE"
## 控制锁类型标签，仅用于日志与排查。
@export var gameplay_lock_type: String = "event_cinematic"
## 黑幕淡出的默认时长（秒）。
@export var event_reveal_duration: float = 0.45

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
	room_payload["reveal_duration"] = event_reveal_duration
	await boot_cinematic_director.play_blocking_intro_event(player, room_payload)

	if Global and Global.has_method("set_cinematic_flag"):
		Global.set_cinematic_flag(ROOM_DREAM10_FIRST_ENTER_FLAG, true)
		if SaveManager and Global.current_save_slot >= 0 and SaveManager.has_method("save_game"):
			SaveManager.save_game(Global.current_save_slot, Global.get_save_data())
	_room_event_running = false

func _build_room_event_payload() -> Dictionary:
	var payload: Dictionary = _build_cinematic_payload()
	payload["pause_world"] = true
	return payload

func _build_cinematic_payload() -> Dictionary:
	var payload: Dictionary = {}
	payload["sequence_steps"] = _build_sequence_steps()
	payload["gameplay_camera_start_zoom"] = gameplay_camera_start_zoom
	payload["gameplay_camera_target_zoom"] = gameplay_camera_target_zoom
	payload["gameplay_camera_zoom_duration"] = gameplay_camera_zoom_duration
	payload["gameplay_drop_speed"] = gameplay_drop_speed
	payload["gameplay_landing_settle_time"] = gameplay_landing_settle_time
	payload["gameplay_drop_animation_name"] = gameplay_drop_animation_name
	payload["gameplay_landed_animation_name"] = gameplay_landed_animation_name
	payload["gameplay_end_animation_name"] = gameplay_end_animation_name
	payload["gameplay_lock_type"] = gameplay_lock_type
	return payload

func _build_sequence_steps() -> Array[Dictionary]:
	if intro_sequence_steps.size() > 0:
		return intro_sequence_steps.duplicate(true)
	if intro_sequence_order.is_empty():
		return []

	var steps: Array[Dictionary] = []
	var text_lines: PackedStringArray = intro_text_lines.duplicate()
	var text_index: int = 0
	var frame_index: int = 0
	for item in intro_sequence_order:
		var token: String = String(item).strip_edges().to_upper()
		if token == "TEXT":
			if not intro_text_enabled_by_default:
				continue
			var text_block := PackedStringArray([])
			if text_index < text_lines.size():
				text_block.append(text_lines[text_index])
				text_index += 1
			else:
				text_block = text_lines
			steps.append({
				"type": "TEXT",
				"lines": text_block,
				"hold_time": intro_text_hold_time,
				"fade_time": intro_text_fade_time,
				"horizontal_alignment": intro_text_horizontal_alignment,
				"vertical_alignment": intro_text_vertical_alignment,
				"theme": intro_text_theme,
				"font_size": intro_text_font_size
			})
		elif token == "VISUAL":
			if not intro_visual_enabled_by_default:
				continue
			var frame_block: Array[Texture2D] = []
			var duration_block := PackedFloat32Array([])
			if frame_index < intro_visual_frames.size():
				frame_block.append(intro_visual_frames[frame_index])
				var duration_value: float = intro_visual_default_frame_time
				if frame_index < intro_visual_frame_durations.size():
					duration_value = maxf(float(intro_visual_frame_durations[frame_index]), 0.01)
				duration_block.append(duration_value)
				frame_index += 1
			else:
				frame_block = intro_visual_frames.duplicate()
				duration_block = intro_visual_frame_durations.duplicate()
			steps.append({
				"type": "VISUAL",
				"frames": frame_block,
				"frame_durations": duration_block,
				"default_frame_time": intro_visual_default_frame_time,
				"fade_time": intro_visual_fade_time
			})
		elif token == "BLACK_HOLD":
			steps.append({
				"type": "BLACK_HOLD",
				"hold_time": 0.35
			})
	return steps
