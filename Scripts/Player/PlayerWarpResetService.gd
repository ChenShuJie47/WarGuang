extends RefCounted
class_name PlayerWarpResetService

# 统一重置传送伤害飞行运行时状态，供多个流程复用。
static func reset_warp_runtime_state(player: Node) -> void:
	player.is_warp_damage = false
	player.warp_flight_active = false
	player.warp_flight_target_position = Vector2.ZERO
	player.warp_flight_target_source = "unknown"
	player.warp_precomputed_target_position = Vector2.ZERO
	player.warp_flight_phase = 0
	player.warp_flight_phase_timer = 0.0
	player.warp_flight_lift_target_position = Vector2.ZERO
	player.warp_flight_hover_target_position = Vector2.ZERO
	if player.warp_flight_collision_backup_valid:
		player.collision_layer = player.warp_flight_prev_collision_layer
		player.collision_mask = player.warp_flight_prev_collision_mask
		player.warp_flight_collision_backup_valid = false
