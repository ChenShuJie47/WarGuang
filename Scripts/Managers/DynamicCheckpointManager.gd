extends Node
# 自动加载的单例

var current_checkpoint_id: int = -1
var current_checkpoint_room: String = ""
var checkpoints: Dictionary = {}  # checkpoint_id -> position
var checkpoint_rooms: Dictionary = {}  # checkpoint_id -> room_id

func _ready():
	add_to_group("dynamic_checkpoint_manager")
	await get_tree().process_frame

## 注册检查点
func register_checkpoint(checkpoint_id: int, position: Vector2, room_id: String):
	# 检查 ID 是否重复
	if checkpoints.has(checkpoint_id):
		var old_room: String = checkpoint_rooms.get(checkpoint_id, "未知")
		var old_pos: Vector2 = checkpoints.get(checkpoint_id, Vector2.ZERO)
		
		# 处理“重复注册但内容一致”的情况：
		# 进入存档/切回同一房间时，检查点可能会被再次注册，而动态检查点应该表现为幂等。
		# 如果房间与位置都相同，则不报警，避免刷屏。
		if old_room == room_id and old_pos.distance_to(position) < 0.001:
			return
		
		print("警告：检查点 ID 重复：", checkpoint_id,
			  "，旧房间:", old_room,
			  "，新房间:", room_id,
			  "（旧位置:", old_pos, "，新位置:", position, "）")
	
	checkpoints[checkpoint_id] = position
	checkpoint_rooms[checkpoint_id] = room_id

## 设置当前检查点（移除优先级参数）
func set_current_checkpoint(id: int, current_room: String):
	# 检查检查点是否属于当前房间
	var checkpoint_room = checkpoint_rooms.get(id, "")
	
	if checkpoint_room != "" and checkpoint_room != current_room:
		print("错误：尝试激活不属于当前房间的检查点")
		print("  检查点 ID:", id, "所属房间:", checkpoint_room, "当前房间:", current_room)
		return
	
	# 关键修复：无条件更新当前检查点并通知 Global
	current_checkpoint_id = id
	current_checkpoint_room = checkpoint_room
	if Global and Global.has_method("set_dynamic_checkpoint"):
		Global.set_dynamic_checkpoint(checkpoints.get(id, Vector2.ZERO))

## 获取当前检查点位置（检查房间归属）
func get_current_checkpoint_position(check_room: String = "") -> Vector2:
	if current_checkpoint_id == -1:
		print("无动态检查点，返回默认位置")
		return Vector2.ZERO
	
	# 检查当前检查点是否属于指定房间
	if check_room != "":
		var checkpoint_room = checkpoint_rooms.get(current_checkpoint_id, "")
		if checkpoint_room != "" and checkpoint_room != check_room:
			print("当前检查点", current_checkpoint_id, "属于房间", checkpoint_room, 
				  "，请求房间为", check_room, "，返回默认位置")
			return Vector2.ZERO
	
	return checkpoints.get(current_checkpoint_id, Vector2.ZERO)

## 新增：房间切换时清除动态检查点记录
func on_room_changed(_new_room_id: String):
	# 保留最近一次激活的动态检查点，不在切换房间时重置。
	# 参数保留用于 API 兼容。
	pass

## 玩家死亡时清除所有动态检查点记录
func clear_all_checkpoints_on_death():
	# 重置当前激活的检查点
	current_checkpoint_id = -1
	current_checkpoint_room = ""
	if Global and Global.has_method("clear_dynamic_checkpoints"):
		Global.clear_dynamic_checkpoints()

## 获取指定房间内的所有动态检查点信息。
func get_room_checkpoints(room_id: String) -> Array:
	var result: Array = []
	for checkpoint_id in checkpoints.keys():
		if checkpoint_rooms.get(checkpoint_id, "") != room_id:
			continue
		result.append({
			"id": checkpoint_id,
			"position": checkpoints[checkpoint_id],
			"room_id": room_id
		})
	return result

## 选择最适合 Door 进入后的动态检查点：先按距离，再按玩家面向方向偏置。
func get_best_checkpoint_for_room(room_id: String, origin_position: Vector2, facing_right: bool, tie_distance: float = 64.0) -> Dictionary:
	var candidates := get_room_checkpoints(room_id)
	if candidates.is_empty():
		return {}

	# 优先使用不高于门位太多的候选点，避免门后出生在空中 DOWN。
	var near_ground_candidates: Array = []
	for candidate in candidates:
		var candidate_pos: Vector2 = candidate.get("position", Vector2.ZERO)
		if candidate_pos.y >= origin_position.y - 12.0:
			near_ground_candidates.append(candidate)
	if not near_ground_candidates.is_empty():
		candidates = near_ground_candidates

	var best_candidate: Dictionary = {}
	var best_score: float = INF
	var best_facing_score: float = -INF
	var facing_direction := Vector2.RIGHT if facing_right else Vector2.LEFT
	var tie_tolerance: float = tie_distance * tie_distance
	var up_penalty_threshold: float = 20.0
	var up_penalty_weight: float = 6.0
	var vertical_penalty_weight: float = 0.12

	for candidate in candidates:
		var candidate_pos: Vector2 = candidate.get("position", Vector2.ZERO)
		var delta: Vector2 = candidate_pos - origin_position
		var distance_sq: float = delta.length_squared()
		var vertical_delta: float = candidate_pos.y - origin_position.y
		var upward_amount: float = maxf(-(vertical_delta + up_penalty_threshold), 0.0)
		var upward_penalty: float = upward_amount * upward_amount * up_penalty_weight
		var vertical_penalty: float = absf(vertical_delta) * vertical_penalty_weight
		var score: float = distance_sq + upward_penalty + vertical_penalty
		var facing_score: float = delta.normalized().dot(facing_direction) if delta.length_squared() > 0.0001 else 1.0

		if best_candidate.is_empty():
			best_candidate = candidate
			best_score = score
			best_facing_score = facing_score
			continue

		if score + 0.001 < best_score:
			best_candidate = candidate
			best_score = score
			best_facing_score = facing_score
			continue

		if absf(score - best_score) <= tie_tolerance and facing_score > best_facing_score:
			best_candidate = candidate
			best_score = score
			best_facing_score = facing_score

	return best_candidate
