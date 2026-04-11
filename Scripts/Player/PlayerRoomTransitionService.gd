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

static func sync_camera_to_player_center(player: Node) -> void:
	PlayerCameraBridgeServiceScript.sync_camera_to_player_center(player)

static func sync_room_and_camera_for_respawn(player: Node) -> void:
	if RoomManager and RoomManager.has_method("get_room_id_by_position") and RoomManager.has_method("load_room"):
		var target_room_id: String = RoomManager.get_room_id_by_position(player.global_position)
		if target_room_id != "":
			if RoomManager.has_method("suppress_player_room_enter"):
				RoomManager.suppress_player_room_enter(0.25)
			if RoomManager.current_room != target_room_id:
				RoomManager.load_room(target_room_id)
			elif RoomManager.has_method("update_camera_limits"):
				RoomManager.update_camera_limits()

	# 等房间限制同步后再做居中相机同步。
	if player and player.get_tree():
		await player.get_tree().process_frame
	PlayerCameraBridgeServiceScript.sync_camera_to_player_center(player)

static func sync_phantom_camera_after_teleport(player: Node) -> void:
	PlayerCameraBridgeServiceScript.sync_phantom_camera_after_teleport(player)

static func force_sync_camera_position_after_teleport(player: Node) -> void:
	await PlayerCameraBridgeServiceScript.force_sync_camera_position_after_teleport(player)

static func start_door_camera_catchup_after_teleport(player: Node, catchup_duration: float = 0.20, unlock_duration: float = 0.32) -> void:
	PlayerCameraBridgeServiceScript.start_door_camera_catchup_after_teleport(player, catchup_duration, unlock_duration)

static func start_door_autowalk_to_dynamic_checkpoint(player: Node, room_id: String, door_position: Vector2, facing_right: bool, allow_jump: bool = true, timeout: float = 1.4) -> bool:
	return PlayerDoorTraversalServiceScript.begin_autowalk(player, room_id, door_position, facing_right, allow_jump, timeout)
