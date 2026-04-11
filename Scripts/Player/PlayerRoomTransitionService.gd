extends RefCounted
class_name PlayerRoomTransitionService

# Warp 到达后的相机桥接通知（保持行为不变，仅做职责收敛）。
static func notify_warp_arrival(player: Node) -> void:
	if player.camera_controller and player.camera_controller.has_method("notify_warp_player_teleported"):
		player.camera_controller.notify_warp_player_teleported()
