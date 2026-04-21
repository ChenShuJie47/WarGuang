extends RefCounted
class_name PlayerDoorTraversalService
# 鍒濆鍖?Door 鑷姩璧颁綅鐘舵€併€?
static func begin_autowalk(player: Node, room_id: String, door_position: Vector2, facing_right: bool, allow_jump: bool = true, timeout: float = 1.4) -> bool:
	if not DynamicCheckpointManager:
		return false
	if not DynamicCheckpointManager.has_method("get_best_checkpoint_for_room"):
		return false
	var best_checkpoint: Dictionary = DynamicCheckpointManager.get_best_checkpoint_for_room(room_id, door_position, facing_right)
	if best_checkpoint.is_empty():
		return false
	var target_position: Vector2 = best_checkpoint.get("position", door_position)
	if target_position.y < door_position.y - 6.0:
		target_position.y = door_position.y
	if absf(target_position.x - door_position.x) < 18.0:
		return false

	player.door_autowalk_active = true
	player.door_autowalk_target_position = target_position
	player.door_autowalk_timeout = maxf(timeout, 0.35)
	var target_delta_x: float = float(player.door_autowalk_target_position.x - door_position.x)
	var resolved_facing_right: bool = facing_right
	if absf(target_delta_x) > 0.5:
		resolved_facing_right = target_delta_x > 0.0
	player.door_autowalk_facing_right = resolved_facing_right
	player.door_autowalk_jump_used = not allow_jump
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

	var target_speed: float = player.run_move_speed * 0.85
	var acceleration: float = player.ground_acceleration * player.run_move_speed * 1.2
	player.velocity.x = move_toward(player.velocity.x, horizontal_direction * target_speed, acceleration * fixed_delta)

	var allow_autowalk_jump: bool = horizontal_distance >= 36.0
	if player.is_on_floor() and allow_autowalk_jump and vertical_distance < -18.0 and not player.door_autowalk_jump_used:
		var gravity_strength: float = player.gravity * maxf(player.effective_gravity_multiplier, 0.1)
		var height_needed: float = absf(vertical_distance) + 8.0
		player.velocity.y = -sqrt(maxf(2.0 * gravity_strength * height_needed, 1.0))
		# 鐩爣楂樹笖姘村钩杈冭繙鏃讹紝鎸変及绠楁粸绌烘椂闂存彁鍗囨按骞冲垵閫熷害锛岄伩鍏嶁€滃彧澶熸姮楂樹笉澶熷墠杩涒€濄€?
		if horizontal_direction != 0.0 and horizontal_distance > 48.0:
			var estimated_air_time: float = (2.0 * absf(player.velocity.y)) / maxf(gravity_strength, 1.0)
			var required_horizontal_speed: float = horizontal_distance / maxf(estimated_air_time, 0.08)
			var boosted_horizontal_speed: float = clampf(required_horizontal_speed, target_speed, player.run_move_speed * 1.6)
			player.velocity.x = horizontal_direction * boosted_horizontal_speed
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

	var horizontal_distance_after_move: float = absf(target.x - player.global_position.x)
	if player.is_on_floor():
		if horizontal_distance_after_move <= 1.5:
			player.global_position = Vector2(target.x, player.global_position.y)
			player.velocity = Vector2.ZERO
			finish_autowalk(player)
			return true

	return false

# 缁撴潫 Door 鑷姩璧颁綅骞舵仮澶嶈緭鍏ャ€?
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
