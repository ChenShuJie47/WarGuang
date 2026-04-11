extends RefCounted
class_name PlayerWarpFlightService

const PHASE_LIFT: int = 0
const PHASE_PAUSE_BEFORE_CRUISE: int = 1
const PHASE_CRUISE: int = 2
const PHASE_PAUSE_AFTER_CRUISE: int = 3

# 开始传送伤害飞行：HURT 结束后进入 JUMP2 飞行到目标检查点。
static func begin_flight(player: Node) -> void:
	if player.warp_flight_active:
		return
	var safe_data := PlayerWarpFlowService.resolve_warp_safe_spot(player)
	player.warp_flight_target_position = safe_data.get("position", Vector2.ZERO)
	player.warp_flight_target_source = safe_data.get("source", "unknown")
	if player.warp_flight_target_position == Vector2.ZERO:
		# 无目标时退化为原地结束，避免中断流程。
		player.warp_flight_target_position = player.global_position

	player.warp_flight_active = true
	player.warp_flight_phase = PHASE_LIFT
	player.warp_flight_phase_timer = 0.0
	player.warp_flight_lift_target_position = player.global_position + Vector2(0.0, -player.warp_flight_lift_distance)
	player.warp_flight_hover_target_position = player.warp_flight_target_position + Vector2(0.0, -player.warp_flight_target_height_offset)
	player.warp_flight_prev_collision_layer = player.collision_layer
	player.warp_flight_prev_collision_mask = player.collision_mask
	player.warp_flight_collision_backup_valid = true
	player.collision_layer = 0
	player.collision_mask = 0
	player.velocity = Vector2.ZERO
	player.is_invincible = true
	player.invincible_timer = player.hurt_invincible_time
	player.is_control_locked = false
	player.control_lock_timer = 0.0
	player.set_process_input(false)
	player.current_animation = "JUMP2"
	player.animated_sprite.play("JUMP2")
	player.is_double_jump_holding = true
	player.has_double_jumped = true
	player.animated_sprite.modulate.a = 0.5
	if player.point_light:
		player.point_light.visible = true
		player.point_light.energy = 0.5

# 每帧更新飞行，返回 true 表示飞行结束。
static func update_flight(player: Node, fixed_delta: float) -> bool:
	if not player.warp_flight_active:
		return true
	var safe_delta: float = maxf(fixed_delta, 0.0001)

	# 飞行期间强制保持 JUMP2 + 旋转，避免被 HURT 动画覆盖。
	if player.current_animation != "JUMP2":
		player.current_animation = "JUMP2"
		player.animated_sprite.play("JUMP2")
	player.animated_sprite.modulate.a = 0.5
	player.animated_sprite.rotation_degrees = fmod(player.animated_sprite.rotation_degrees + player.jump2_rotation_speed * fixed_delta, 360.0)

	if player.warp_flight_phase == PHASE_LIFT:
		if _move_to_point(player, player.warp_flight_lift_target_position, player.warp_flight_lift_speed, safe_delta, player.warp_flight_arrive_epsilon):
			player.warp_flight_phase = PHASE_PAUSE_BEFORE_CRUISE
			player.warp_flight_phase_timer = player.warp_flight_phase_pause_time
			player.velocity = Vector2.ZERO
		return false

	if player.warp_flight_phase == PHASE_PAUSE_BEFORE_CRUISE:
		player.velocity = Vector2.ZERO
		player.warp_flight_phase_timer -= safe_delta
		if player.warp_flight_phase_timer <= 0.0:
			player.warp_flight_phase = PHASE_CRUISE
		return false

	if player.warp_flight_phase == PHASE_CRUISE:
		var to_target: Vector2 = player.warp_flight_hover_target_position - player.global_position
		var dist: float = to_target.length()
		var speed: float = clampf(dist * 4.5, player.warp_flight_min_speed, player.warp_flight_peak_speed)
		if _move_to_point(player, player.warp_flight_hover_target_position, speed, safe_delta, player.warp_flight_arrive_epsilon):
			player.warp_flight_phase = PHASE_PAUSE_AFTER_CRUISE
			player.warp_flight_phase_timer = player.warp_flight_phase_pause_time
			player.velocity = Vector2.ZERO
		return false

	player.velocity = Vector2.ZERO
	player.warp_flight_phase_timer -= safe_delta
	if player.warp_flight_phase_timer <= 0.0:
		finish_flight(player)
		return true

	return false

# 完成飞行并恢复正常控制。
static func finish_flight(player: Node) -> void:
	player.warp_flight_active = false
	player.warp_flight_phase = PHASE_PAUSE_AFTER_CRUISE
	player.warp_flight_phase_timer = 0.0
	player.global_position = player.warp_flight_hover_target_position
	player.velocity = Vector2.ZERO
	if player.warp_flight_collision_backup_valid:
		player.collision_layer = player.warp_flight_prev_collision_layer
		player.collision_mask = player.warp_flight_prev_collision_mask
		player.warp_flight_collision_backup_valid = false
	player.animated_sprite.rotation_degrees = 0.0
	PlayerRoomTransitionService.notify_warp_arrival(player)
	player.reset_after_warp()
	player.is_control_locked = false
	player.control_lock_timer = 0.0
	player.set_process_input(true)
	player.change_state(player.PlayerState.DOWN)
	player.is_invincible = true
	player.invincible_timer = player.hurt_invincible_time
	player.animated_sprite.modulate.a = 0.5
	print("传送伤害飞行完成：位置=", player.global_position,
		" 来源=", player.warp_flight_target_source,
		" 房间=", RoomManager.current_room if RoomManager else "",
		" 无敌时间=", player.hurt_invincible_time)

static func _move_to_point(player: Node, target: Vector2, speed: float, fixed_delta: float, epsilon: float) -> bool:
	var to_target: Vector2 = target - player.global_position
	var dist: float = to_target.length()
	if dist <= epsilon:
		player.global_position = target
		player.velocity = Vector2.ZERO
		return true
	var step: float = maxf(speed, 0.0) * maxf(fixed_delta, 0.0)
	if dist <= step + epsilon:
		player.global_position = target
		player.velocity = Vector2.ZERO
		return true
	var dir: Vector2 = to_target / maxf(dist, 0.001)
	player.velocity = dir * speed
	player.is_facing_right = dir.x >= 0.0
	player.animated_sprite.flip_h = not player.is_facing_right
	return false
