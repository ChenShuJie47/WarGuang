extends RefCounted
class_name PlayerRoomTransitionService

# 房间切换、Door 传送与相机同步的统一入口。
const PlayerCameraBridgeServiceScript = preload("res://Scripts/Player/PlayerCameraBridgeService.gd")
const PlayerDoorTraversalServiceScript = preload("res://Scripts/Player/PlayerDoorTraversalService.gd")

# Warp 到达后的相机桥接通知（保持行为不变，仅做职责收敛）。
static func notify_warp_arrival(player: Node) -> void:
	if player.camera_controller and player.camera_controller.has_method("notify_warp_player_teleported"):
		player.camera_controller.notify_warp_player_teleported()

static func sync_camera_after_room_teleport(player: Node) -> void:
	PlayerCameraBridgeServiceScript.sync_camera_after_room_teleport(player)

static func sync_camera_to_player_center(player: Node, immediate: bool = false) -> void:
	if player and player.camera_controller and player.camera_controller.has_method("end_death_camera_freeze"):
		player.camera_controller.end_death_camera_freeze()
	PlayerCameraBridgeServiceScript.sync_camera_to_player_center(player, immediate)

static func sync_room_and_camera_for_respawn(player: Node, preferred_room_id: String = "", immediate: bool = false) -> void:
	if RoomManager and RoomManager.has_method("get_room_id_by_position") and RoomManager.has_method("load_room"):
		var target_room_id: String = preferred_room_id
		if target_room_id == "":
			target_room_id = RoomManager.get_room_id_by_position(player.global_position)
		if target_room_id == "" and Global and typeof(Global.last_save_room) == TYPE_STRING and Global.last_save_room != "":
			target_room_id = Global.last_save_room
		if target_room_id != "":
			if RoomManager.has_method("suppress_player_room_enter"):
				RoomManager.suppress_player_room_enter(1.25)
			if player:
				PlayerCameraBridgeServiceScript.clear_observe_offset_runtime(player)
			if player and player.camera_controller and player.camera_controller.has_method("begin_blackout_camera_transition"):
				player.camera_controller.begin_blackout_camera_transition()
			if RoomManager.has_method("ensure_room_loaded"):
				RoomManager.ensure_room_loaded(target_room_id)
			elif RoomManager.current_room != target_room_id:
				RoomManager.load_room(target_room_id)
			elif RoomManager.has_method("update_camera_limits"):
				RoomManager.update_camera_limits()

	await _await_camera_controller_ready(player)

	# 等房间限制同步后再做居中相机同步；跨房间时额外等待物理帧，避免旧限制残留。
	if player and player.get_tree():
		await player.get_tree().process_frame
		await player.get_tree().process_frame
		await player.get_tree().physics_frame
	if RoomManager and RoomManager.has_method("update_camera_limits"):
		RoomManager.update_camera_limits()
	if player and player.has_method("sync_camera_after_room_teleport"):
		player.sync_camera_after_room_teleport()
	PlayerCameraBridgeServiceScript.sync_camera_to_player_center(player, immediate)
	if player and player.get_tree():
		await player.get_tree().physics_frame
	if RoomManager and RoomManager.has_method("update_camera_limits"):
		RoomManager.update_camera_limits()
	if player and player.camera_controller and player.camera_controller.has_method("restore_blackout_camera_transition"):
		player.camera_controller.restore_blackout_camera_transition()
	if RoomManager and RoomManager.has_method("update_camera_limits"):
		RoomManager.update_camera_limits()
	PlayerCameraBridgeServiceScript.sync_camera_to_player_center(player, true)

static func _await_camera_controller_ready(player: Node) -> void:
	if not player or not player.get_tree():
		return
	for _i in range(8):
		if player.camera_controller and player.camera_controller.setup_completed:
			return
		await player.get_tree().process_frame

static func sync_phantom_camera_after_teleport(player: Node) -> void:
	PlayerCameraBridgeServiceScript.sync_phantom_camera_after_teleport(player)

static func force_sync_camera_position_after_teleport(player: Node) -> void:
	await PlayerCameraBridgeServiceScript.force_sync_camera_position_after_teleport(player)

static func start_door_camera_catchup_after_teleport(player: Node, catchup_duration: float = 0.20, unlock_duration: float = 0.32) -> void:
	PlayerCameraBridgeServiceScript.start_door_camera_catchup_after_teleport(player, catchup_duration, unlock_duration)

static func start_door_autowalk_to_dynamic_checkpoint(player: Node, room_id: String, door_position: Vector2, facing_right: bool, allow_jump: bool = true, timeout: float = 1.4) -> bool:
	return PlayerDoorTraversalServiceScript.begin_autowalk(player, room_id, door_position, facing_right, allow_jump, timeout)
