extends Node
class_name NewSaveOpeningEventDirector

enum EventStepType {
	TEXT,
	VISUAL,
	BLACK_HOLD
}

@export_category("Binding")
## 新存档开场对应的初始房间。
@export var opening_room_id: String = "Room1"
## Player 节点路径（相对本节点）。
@export var player_path: NodePath = NodePath("../../Player")
## BootCinematicDirector 节点路径（相对本节点）。
@export var boot_cinematic_director_path: NodePath = NodePath("../../BootCinematicDirector")

@export_category("Intro Text")
## 是否默认启用文字阶段；事件演出可在开场配置中关闭。
@export var intro_text_enabled_by_default: bool = true
## 开场文字分段，按顺序逐段播放。
@export var intro_text_lines: PackedStringArray = PackedStringArray([])
## 每段文字独立停留时长（秒）；数量不足时回退到 Boot 内部默认停留时长。
@export var intro_text_line_hold_times: PackedFloat32Array = PackedFloat32Array([])

@export_category("Text Layout & Style")
## 水平对齐：控制文本在可视区域内的左右对齐（左/中/右）。
@export var intro_text_horizontal_alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER
## 垂直对齐：控制文本在可视区域内的上下位置（上/中/下）。
@export var intro_text_vertical_alignment: VerticalAlignment = VERTICAL_ALIGNMENT_CENTER
## 文本主题资源（如 Theme9x9.tres）；为空时使用默认主题。
@export var intro_text_theme: Theme
## 文本字号（当 theme 未提供对应字体大小时生效）。
@export var intro_text_font_size: int = 28

@export_category("Intro Visual Sequence")
## 是否默认启用视觉序列阶段；事件演出可在开场配置中关闭。
@export var intro_visual_enabled_by_default: bool = true
## 视觉序列帧列表（按顺序播放，不需要帧动画资源）。
@export var intro_visual_frames: Array[Texture2D] = []
## 每帧持续时长（秒）；数量不足时回退到 Boot 内部默认时长。
@export var intro_visual_frame_durations: PackedFloat32Array = PackedFloat32Array([])

@export_category("Sequence Mode")
## 按顺序播放的开场步骤。
@export var intro_sequence_order: Array[EventStepType] = [EventStepType.TEXT, EventStepType.VISUAL, EventStepType.TEXT, EventStepType.BLACK_HOLD]

@export_category("Gameplay Drop")
## 掉落演出开始时使用的相机缩放值。
@export var gameplay_camera_start_zoom: float = 4.0
## 掉落演出结束后恢复的相机缩放值。
@export var gameplay_camera_target_zoom: float = 2.0
## 相机从起始缩放过渡到目标缩放所需时长（秒）。
@export var gameplay_camera_zoom_duration: float = 4.0
## 演出式掉落速度（像素/秒），独立于 Player 常规下落速度。
@export var gameplay_drop_speed: float = 260.0
## 落地后 DIE 演出停留时间（秒）。
@export var gameplay_landing_settle_time: float = 5.0
## 掉落演出动画名（直接驱动 AnimatedSprite2D，不改状态机）。
@export var gameplay_drop_animation_name: StringName = &"DOWN"
## 落地后停留阶段动画名（直接驱动 AnimatedSprite2D，不改状态机）。
@export var gameplay_landed_animation_name: StringName = &"DIE"
## 交还控制前恢复动画名（直接驱动 AnimatedSprite2D，不改状态机）。
@export var gameplay_end_animation_name: StringName = &"IDLE"
## 统一控制锁标签：所有演出统一视为 event_cinematic。
@export var gameplay_lock_type: String = "event_cinematic"

const DROP_WAIT_MAX_SECONDS: float = 20.0

var _opening_running: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

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

	var opening_payload: Dictionary = _build_opening_payload(boot_request)
	opening_payload["reveal_duration"] = boot_cinematic_director.get_default_fade_duration()
	var physics_process_backup: bool = player.is_physics_processing()
	var input_process_backup: bool = player.is_processing_input()

	# 先完整同步房间与相机，再开始开场编排，避免新存档开场时视角停留在旧位置。
	if opening_room_id != "" and player.has_method("sync_room_and_camera_for_respawn"):
		await player.sync_room_and_camera_for_respawn(opening_room_id, true)
	elif player.has_method("sync_camera_to_player_center"):
		player.sync_camera_to_player_center(true)

	# Intro 阶段冻结玩家，避免在文字/视觉序列期间提前下坠到地面。
	if player.has_method("lock_control"):
		player.lock_control(999.0, "new_save_intro")
	if player.has_method("set_player_control"):
		player.set_player_control(false)
	player.set_physics_process(false)

	# 切换黑幕控制权：先让 Boot 覆盖层接管，再释放 FadeManager，避免开场动画被全局黑幕遮住。
	if boot_cinematic_director.has_method("force_overlay_black"):
		boot_cinematic_director.force_overlay_black()
	await get_tree().process_frame
	await _await_boot_overlay_black_ready(boot_cinematic_director)
	var intro_state: Variant = boot_cinematic_director.play_intro_sequence(opening_payload)
	await _await_intro_phase_started(boot_cinematic_director)
	if FadeManager and FadeManager.has_method("force_fade_in"):
		FadeManager.force_fade_in()
	if intro_state is GDScriptFunctionState:
		await intro_state
	# 掉落交接前恢复 physics/input 基线，确保 Boot 的状态备份与恢复行为正确。
	player.set_physics_process(physics_process_backup)
	player.set_process_input(input_process_backup)
	boot_cinematic_director.start_gameplay_drop(player, opening_payload)

	var wait_elapsed: float = 0.0
	while boot_cinematic_director.has_method("is_gameplay_drop_running") and boot_cinematic_director.is_gameplay_drop_running() and wait_elapsed < DROP_WAIT_MAX_SECONDS:
		await get_tree().process_frame
		wait_elapsed += 1.0 / maxf(float(Engine.physics_ticks_per_second), 30.0)

	if boot_cinematic_director.has_method("is_gameplay_drop_running") and boot_cinematic_director.is_gameplay_drop_running():
		push_warning("NewSaveOpeningEventDirector: 掉落流程超时未结束，执行兜底揭黑。")
		if boot_cinematic_director.has_method("reveal_overlay_to_gameplay"):
			await boot_cinematic_director.reveal_overlay_to_gameplay(boot_cinematic_director.get_default_fade_duration())

	_opening_running = false

func _await_boot_overlay_black_ready(boot_cinematic_director: BootCinematicDirector) -> void:
	if not is_instance_valid(boot_cinematic_director):
		return
	if not boot_cinematic_director.has_method("is_overlay_fully_black"):
		return
	for _i in range(6):
		if boot_cinematic_director.is_overlay_fully_black():
			return
		await get_tree().process_frame

func _await_intro_phase_started(boot_cinematic_director: BootCinematicDirector) -> void:
	if not is_instance_valid(boot_cinematic_director):
		return
	if not boot_cinematic_director.has_method("is_intro_running"):
		await get_tree().process_frame
		return
	for _i in range(6):
		if boot_cinematic_director.is_intro_running():
			await get_tree().process_frame
			return
		await get_tree().process_frame

func _build_opening_payload(boot_request: Dictionary = {}) -> Dictionary:
	var payload: Dictionary = {}
	if typeof(boot_request) == TYPE_DICTIONARY:
		if boot_request.has("payload") and typeof(boot_request.get("payload")) == TYPE_DICTIONARY:
			payload = (boot_request.get("payload") as Dictionary).duplicate(true)
		else:
			payload = boot_request.duplicate(true)

	payload["intro_text_enabled"] = intro_text_enabled_by_default
	payload["intro_text_lines"] = intro_text_lines.duplicate()
	payload["intro_text_line_hold_times"] = intro_text_line_hold_times.duplicate()
	payload["intro_text_horizontal_alignment"] = intro_text_horizontal_alignment
	payload["intro_text_vertical_alignment"] = intro_text_vertical_alignment
	payload["intro_text_theme"] = intro_text_theme
	payload["intro_text_font_size"] = intro_text_font_size
	payload["intro_visual_enabled"] = intro_visual_enabled_by_default
	payload["intro_visual_frames"] = intro_visual_frames.duplicate()
	payload["intro_visual_frame_durations"] = intro_visual_frame_durations.duplicate()
	payload["sequence_order"] = intro_sequence_order.duplicate()
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
