extends RefCounted
class_name PlayerEdgeCorrectionService

## 统一处理跳跃和冲刺的边缘校正，避免轻微角点碰撞直接打断动作。
static func apply_edge_correction(player: Node, fixed_delta: float) -> void:
	if not is_instance_valid(player):
		return
	if _apply_wall_jump_edge_correction(player, fixed_delta):
		return
	if _apply_jump_edge_correction(player, fixed_delta):
		return
	_apply_dash_edge_correction(player, fixed_delta)

## 跳跃边缘校正：当上升中的未来位置被极小碰撞卡住时，尝试横向微移。
static func _apply_jump_edge_correction(player: Node, fixed_delta: float) -> bool:
	if player.current_state != player.PlayerState.JUMP and player.current_state != player.PlayerState.DOWN:
		return false
	if player.velocity.y >= 0.0:
		return false
	var base_motion: Vector2 = player.velocity * fixed_delta
	if _is_future_position_free(player, base_motion, Vector2.ZERO):
		return false
	var preferred_direction: int = sign(player.velocity.x)
	if player.current_state == player.PlayerState.WALLJUMP and player.wall_grip_direction != 0:
		preferred_direction = -player.wall_grip_direction
	if preferred_direction == 0:
		preferred_direction = 1 if player.is_facing_right else -1
	return _try_perpendicular_nudges(player, base_motion, preferred_direction, player.jump_edge_correction_step, player.jump_edge_correction_steps, true)

## 冲刺边缘校正：当 dash 的未来位置只差一点角点时，尝试竖向微移。
static func _apply_dash_edge_correction(player: Node, fixed_delta: float) -> bool:
	if player.current_state != player.PlayerState.DASH and player.current_state != player.PlayerState.SUPERDASH:
		return false
	var base_motion: Vector2 = player.velocity * fixed_delta
	if _is_future_position_free(player, base_motion, Vector2.ZERO):
		return false
	var preferred_direction: int = -1
	if player.velocity.y > 0.0:
		preferred_direction = 1
	return _try_perpendicular_nudges(player, base_motion, preferred_direction, player.dash_edge_correction_step, player.dash_edge_correction_steps, false)

## 按给定方向做有限次小幅偏移，并检查未来位置是否完全空闲。
static func _try_perpendicular_nudges(player: Node, base_motion: Vector2, preferred_direction: int, step_size: float, max_steps: int, horizontal_nudge: bool) -> bool:
	if step_size <= 0.0 or max_steps <= 0:
		return false
	var directions: Array[int] = [preferred_direction, -preferred_direction]
	for direction in directions:
		if direction == 0:
			continue
		for step_index in range(1, max_steps + 1):
			var nudge: Vector2 = Vector2.ZERO
			if horizontal_nudge:
				nudge.x = step_size * float(step_index) * float(direction)
			else:
				nudge.y = step_size * float(step_index) * float(direction)
			if _is_future_position_free(player, base_motion, nudge):
				player.global_position += nudge
				return true
	return false

## 墙跳边缘校正：复用跳跃校正，但将优先方向固定为离墙方向。
static func _apply_wall_jump_edge_correction(player: Node, fixed_delta: float) -> bool:
	if player.current_state != player.PlayerState.WALLJUMP:
		return false
	if player.velocity.y >= 0.0:
		return false
	var base_motion: Vector2 = player.velocity * fixed_delta
	if _is_future_position_free(player, base_motion, Vector2.ZERO):
		return false
	var preferred_direction: int = -player.wall_grip_direction
	if preferred_direction == 0:
		preferred_direction = sign(player.velocity.x)
	if preferred_direction == 0:
		preferred_direction = 1 if player.is_facing_right else -1
	return _try_perpendicular_nudges(player, base_motion, preferred_direction, player.wall_jump_edge_correction_step, player.wall_jump_edge_correction_steps, true)

## 检查未来位置是否空闲，依赖玩家自身碰撞形状和场景物理空间。
static func _is_future_position_free(player: Node, base_motion: Vector2, nudge: Vector2) -> bool:
	if not is_instance_valid(player):
		return false
	var collision_shape: CollisionShape2D = _find_collision_shape_node(player)
	if collision_shape == null or collision_shape.shape == null:
		return false
	if player.get_world_2d() == null:
		return false
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = collision_shape.shape
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.collision_mask = player.collision_mask
	query.exclude = [player.get_rid()]
	var transform := collision_shape.global_transform
	transform.origin += base_motion + nudge
	query.transform = transform
	var results: Array = player.get_world_2d().direct_space_state.intersect_shape(query, 1)
	return results.is_empty()

## 从玩家节点树中递归查找可用的碰撞形状。
static func _find_collision_shape_node(root: Node) -> CollisionShape2D:
	for child in root.get_children():
		if child is CollisionShape2D and child.shape != null:
			return child
		if child is Node:
			var nested_shape: CollisionShape2D = _find_collision_shape_node(child)
			if nested_shape != null:
				return nested_shape
	return null