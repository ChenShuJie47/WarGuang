extends RefCounted
class_name PlayerDoorTraversalService
# 鍒濆鍖?Door 鑷姩璧颁綅鐘舵€併€?
static func begin_autowalk(player: Node, room_id: String, door_position: Vector2, facing_right: bool, allow_jump: bool = true, timeout: float = 1.4) -> bool:
	if TimerControlManager and TimerControlManager.has_method("stop_slow_motion"):
		TimerControlManager.stop_slow_motion()
	if is_instance_valid(player) and player.has_method("disable_counter_slow_effects"):
		player.disable_counter_slow_effects()
	if not DynamicCheckpointManager:
		return false
	if not DynamicCheckpointManager.has_method("get_best_checkpoint_for_room"):
		return false
	var best_checkpoint: Dictionary = DynamicCheckpointManager.get_best_checkpoint_for_room(room_id, door_position, facing_right)
	if best_checkpoint.is_empty():
		return false
	var target_position: Vector2 = best_checkpoint.get("position", door_position)
	if absf(target_position.x - door_position.x) < 18.0:
		return false

	player.door_autowalk_active = true
	player.door_autowalk_target_position = target_position
	player.door_autowalk_timeout = maxf(timeout, 0.35)
	player.door_autowalk_jump_used = not allow_jump
	player.door_autowalk_jump_phase = 0
	player.door_autowalk_jump_velocity = Vector2.ZERO
	player.door_autowalk_jump_velocity_ready = false
	var target_delta_x: float = float(player.door_autowalk_target_position.x - door_position.x)
	var resolved_facing_right: bool = facing_right
	if absf(target_delta_x) > 0.5:
		resolved_facing_right = target_delta_x > 0.0
	player.door_autowalk_facing_right = resolved_facing_right
	player.velocity = Vector2.ZERO
	player.is_facing_right = resolved_facing_right
	player.animated_sprite.flip_h = not resolved_facing_right
	player.change_state(player.PlayerState.IDLE)
	player.control_lock_timer = player.door_autowalk_timeout + 0.2
	player.is_control_locked = true
	player.set_process_input(false)
	return true

# 姣忓抚鏇存柊 Door 鑷姩璧颁綅锛岃繑鍥?true 琛ㄧず瀹屾垚銆?
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

	if player.is_on_floor() and horizontal_distance <= 2.5 and absf(vertical_distance) <= 4.0:
		player.global_position = Vector2(target.x, target.y)
		player.velocity = Vector2.ZERO
		finish_autowalk(player)
		return true

	var previous_position: Vector2 = player.global_position
	var previous_delta_x: float = target.x - previous_position.x
	var target_speed: float = player.run_move_speed * 0.85
	var acceleration: float = player.ground_acceleration * player.run_move_speed * 1.2
	if player.door_autowalk_jump_used:
		if player.door_autowalk_jump_phase == 1:
			if not player.door_autowalk_jump_velocity_ready:
				player.door_autowalk_jump_velocity = _compute_vertical_jump_velocity(player, target)
				player.velocity = player.door_autowalk_jump_velocity
				player.door_autowalk_jump_velocity_ready = true
			player.velocity.x = 0.0
			if not player.is_on_floor():
				player.apply_gravity(fixed_delta)
			player.move_and_slide()
			if player.global_position.y <= target.y + 4.0 or player.velocity.y >= 0.0:
				player.door_autowalk_jump_phase = 2
				player.door_autowalk_jump_velocity_ready = false
		elif player.door_autowalk_jump_phase == 2:
			if not player.door_autowalk_jump_velocity_ready:
				player.door_autowalk_jump_velocity = _compute_jump_velocity(player, target)
				player.velocity = player.door_autowalk_jump_velocity
				player.door_autowalk_jump_velocity_ready = true
			if not player.is_on_floor():
				player.apply_gravity(fixed_delta)
			player.move_and_slide()
		else:
			player.door_autowalk_jump_phase = 1
			player.door_autowalk_jump_velocity_ready = false
	else:
		player.velocity.x = move_toward(player.velocity.x, horizontal_direction * target_speed, acceleration * fixed_delta)
		if not player.is_on_floor():
			player.apply_gravity(fixed_delta)
		player.move_and_slide()
		var horizontal_progress: float = absf(player.global_position.x - previous_position.x)
		var blocked_by_wall: bool = player.is_on_wall() and horizontal_distance > 20.0
		var target_is_higher: bool = vertical_distance < -14.0
		if blocked_by_wall and target_is_higher:
			player.door_autowalk_jump_used = true
			player.door_autowalk_jump_phase = 1
			player.door_autowalk_jump_velocity_ready = false
			player.velocity = Vector2.ZERO
			player.change_state(player.PlayerState.JUMP)
			return false
		elif horizontal_progress >= maxf(target_speed * fixed_delta * 0.25, 0.5):
			pass

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

	var current_delta_x: float = target.x - player.global_position.x
	var horizontal_distance_after_move: float = absf(current_delta_x)
	var crossed_target_x: bool = absf(previous_delta_x) > 0.01 and sign(previous_delta_x) != sign(current_delta_x)
	var moving_away_from_target: bool = absf(player.velocity.x) > 8.0 and sign(player.velocity.x) != sign(current_delta_x)
	if player.is_on_floor():
		if horizontal_distance_after_move <= 1.5 or crossed_target_x or (player.door_autowalk_jump_used and (horizontal_distance_after_move <= 10.0 or moving_away_from_target)):
			player.global_position = Vector2(target.x, target.y if absf(target.y - player.global_position.y) <= 12.0 else player.global_position.y)
			player.velocity = Vector2.ZERO
			finish_autowalk(player)
			return true

	return false

static func _compute_vertical_jump_velocity(player: Node, target: Vector2) -> Vector2:
	var delta: Vector2 = target - player.global_position
	var gravity_strength: float = player.gravity * maxf(player.effective_gravity_multiplier, 0.1)
	var minimum_lift_height: float = maxf(absf(delta.y) + 24.0, 48.0)
	var launch_speed: float = maxf(absf(player.jump_velocity), sqrt(maxf(2.0 * gravity_strength * minimum_lift_height, 0.0)))
	return Vector2(0.0, -launch_speed)

static func _compute_jump_velocity(player: Node, target: Vector2) -> Vector2:
	var delta: Vector2 = target - player.global_position
	var gravity_strength: float = player.gravity * maxf(player.effective_gravity_multiplier, 0.1)
	var horizontal_time: float = absf(delta.x) / maxf(player.run_move_speed * 0.9, 1.0)
	var vertical_time: float = sqrt(maxf(absf(delta.y) * 2.0 / maxf(gravity_strength, 1.0), 0.0))
	var travel_time: float = clampf(maxf(horizontal_time, vertical_time * 1.05), 0.24, 0.95)
	var velocity_x: float = delta.x / travel_time
	var velocity_y: float = (delta.y - 0.5 * gravity_strength * travel_time * travel_time) / travel_time
	return Vector2(velocity_x, velocity_y)

# 缁撴潫 Door 鑷姩璧颁綅骞舵仮澶嶈緭鍏ャ€?
static func finish_autowalk(player: Node) -> void:
	player.door_autowalk_active = false
	player.door_autowalk_timeout = 0.0
	player.door_autowalk_jump_used = false
	player.door_autowalk_jump_phase = 0
	player.door_autowalk_jump_velocity = Vector2.ZERO
	player.door_autowalk_jump_velocity_ready = false
	player.velocity = Vector2.ZERO
	player.control_lock_timer = 0.0
	player.is_control_locked = false
	player.set_process_input(true)
	if player.is_on_floor():
		player.change_state(player.PlayerState.IDLE)
	else:
		player.change_state(player.PlayerState.DOWN)
