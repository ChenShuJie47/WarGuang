extends RefCounted
class_name PlayerWarpFlowService

# 启动传送伤害流程：记录计时、预计算目标点并提前触发相机追镜。
static func begin_warp_damage_flow(player: Node) -> void:
	player.is_warp_damage = true
	var pre_target_info := PlayerDamageService.resolve_warp_safe_spot()
	player.warp_precomputed_target_position = pre_target_info.get("position", Vector2.ZERO)

# 解析本次传送的安全点与来源。
static func resolve_warp_safe_spot(player: Node) -> Dictionary:
	var safe_spot_info := PlayerDamageService.resolve_warp_safe_spot()
	var safe_spot: Vector2 = player.warp_precomputed_target_position if player.warp_precomputed_target_position != Vector2.ZERO else safe_spot_info.get("position", Vector2.ZERO)
	return {
		"position": safe_spot,
		"source": safe_spot_info.get("source", "unknown")
	}
