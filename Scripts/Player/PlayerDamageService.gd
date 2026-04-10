extends RefCounted
class_name PlayerDamageService

# 判断是否属于传送型伤害。
static func is_warp_damage_type(damage_type: int) -> bool:
	return damage_type == 2 or damage_type == 3

# 判断是否属于阴影伤害系。
static func is_shadow_damage_type(damage_type: int) -> bool:
	return damage_type == 1 or damage_type == 3

# 统一解析传送伤害的安全点，附带来源标签便于调试。
static func resolve_warp_safe_spot() -> Dictionary:
	var checkpoint_pos: Vector2 = Global.get_last_checkpoint_position()
	if checkpoint_pos != Vector2.ZERO:
		return {
			"position": checkpoint_pos,
			"source": "checkpoint"
		}
	
	var save_pos: Vector2 = Global.get_save_point_position()
	return {
		"position": save_pos,
		"source": "save_point"
	}

# 通过位置推断目标房间，用于传送前先切换房间上下文。
static func resolve_room_for_position(world_pos: Vector2, fallback_room: String = "") -> String:
	if RoomManager and RoomManager.has_method("get_room_id_by_position"):
		return RoomManager.get_room_id_by_position(world_pos)
	return fallback_room
