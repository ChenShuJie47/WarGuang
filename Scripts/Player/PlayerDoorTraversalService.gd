extends RefCounted
class_name PlayerDoorTraversalService

# 初始化 Door 自动走位状态。
static func begin_autowalk(player: Node, room_id: String, door_position: Vector2, facing_right: bool, allow_jump: bool = true, timeout: float = 1.4) -> bool:
	if not DynamicCheckpointManager:
		return false
	if not DynamicCheckpointManager.has_method("get_best_checkpoint_for_room"):
		return false
	var best_checkpoint: Dictionary = DynamicCheckpointManager.get_best_checkpoint_for_room(room_id, door_position, facing_right)
	if best_checkpoint.is_empty():
		return false

	player.door_autowalk_active = true
	player.door_autowalk_target_position = best_checkpoint.get("position", door_position)
	player.door_autowalk_timeout = maxf(timeout, 0.35)
	player.door_autowalk_facing_right = facing_right
	player.door_autowalk_jump_used = not allow_jump
	player.velocity = Vector2.ZERO
	player.is_facing_right = facing_right
	player.animated_sprite.flip_h = not facing_right
	player.change_state(player.PlayerState.IDLE)
	player.control_lock_timer = player.door_autowalk_timeout + 0.2
	player.is_control_locked = true
	player.set_process_input(false)
	return true

# 每帧更新 Door 自动走位，返回 true 表示完成。
static func update_autowalk(player: Node, fixed_delta: float) -> bool:
	if not player.door_autowalk_active:
		return true

	player.door_autowalk_timeout -= fixed_delta
	if player.door_autowalk_timeout <= 0.0:
		finish_autowalk(player)
		return true

	var target: Vector2 = player.door_autowalk_target_position
	var delta: Vector2 = target - player.global_position
	var horizontal_distance: float = absf(delta.x)
	var vertical_distance: float = delta.y
	var horizontal_direction: float = 0.0
	if horizontal_distance > 3.0:
		horizontal_direction = 1.0 if delta.x > 0.0 else -1.0

	var target_speed: float = player.run_move_speed * 0.85
	var acceleration: float = player.ground_acceleration * player.run_move_speed * 1.2
	player.velocity.x = move_toward(player.velocity.x, horizontal_direction * target_speed, acceleration * fixed_delta)

	if player.is_on_floor() and vertical_distance < -18.0 and not player.door_autowalk_jump_used:
		var gravity_strength: float = player.gravity * maxf(player.effective_gravity_multiplier, 0.1)
		var height_needed: float = absf(vertical_distance) + 8.0
		player.velocity.y = -sqrt(maxf(2.0 * gravity_strength * height_needed, 1.0))
		player.door_autowalk_jump_used = true
		player.change_state(player.PlayerState.JUMP)
	elif not player.is_on_floor():
		player.apply_gravity(fixed_delta)

	player.move_and_slide()

	if player.is_on_floor():
		if absf(player.velocity.x) > 8.0:
			player.change_state(player.PlayerState.MOVE)
		else:
			player.change_state(player.PlayerState.IDLE)
	else:
		if player.velocity.y < 0.0:
			player.change_state(player.PlayerState.JUMP)
		else:
			player.change_state(player.PlayerState.DOWN)

	if player.is_on_floor() and horizontal_distance <= 4.0 and absf(vertical_distance) <= 8.0:
		player.global_position = target
		player.velocity = Vector2.ZERO
		finish_autowalk(player)
		return true

	return false

# 结束 Door 自动走位并恢复输入。
static func finish_autowalk(player: Node) -> void:
	player.door_autowalk_active = false
	player.door_autowalk_timeout = 0.0
	player.door_autowalk_jump_used = false
	player.velocity = Vector2.ZERO
	player.control_lock_timer = 0.0
	player.is_control_locked = false
	player.set_process_input(true)
	if player.is_on_floor():
		player.change_state(player.PlayerState.IDLE)
	else:
		player.change_state(player.PlayerState.DOWN)
