extends RefCounted
class_name PlayerAirAbilityService

const PlayerAirStateServiceScript = preload("res://Scripts/Player/PlayerAirStateService.gd")

static func try_jump(player: Node, jump_just_pressed: bool) -> bool:
	if player.is_on_floor() or player.coyote_time_active:
		if jump_just_pressed or player.jump_buffer_timer.time_left > 0:
			player.velocity.y = player.jump_velocity
			player.jump_hold_timer = 0.0
			PlayerAirStateServiceScript.apply_first_jump_state(player)

			if player.current_state == player.PlayerState.RUN or (player.coyote_time_active and player.was_running_before_coyote):
				player.is_run_jumping = true
				player.run_jump_timer = player.run_jump_boost_duration
				player.run_jump_original_direction = 1 if player.is_facing_right else -1

			player.change_state(player.PlayerState.JUMP)
			player.jump_buffer_timer.stop()
			return true

	return false

static func try_double_jump(player: Node, jump_just_pressed: bool) -> bool:
	if not player.double_jump_unlocked:
		return false

	if player.can_compensation_jump and not player.compensation_jump_used and jump_just_pressed and not player.is_on_floor() and not player.coyote_time_active:
		player.velocity.y = player.double_jump_velocity
		player.jump_hold_timer = 0.0
		PlayerAirStateServiceScript.apply_double_jump_state(player, true)
		if player.has_method("mark_double_jump_started"):
			player.mark_double_jump_started()
		player.change_state(player.PlayerState.JUMP)
		return true

	if jump_just_pressed and player.can_double_jump and not player.has_double_jumped and not player.is_on_floor() and not player.coyote_time_active:
		player.velocity.y = player.double_jump_velocity
		player.jump_hold_timer = 0.0
		PlayerAirStateServiceScript.apply_double_jump_state(player, false)
		if player.has_method("mark_double_jump_started"):
			player.mark_double_jump_started()
		player.change_state(player.PlayerState.JUMP)
		return true

	return false

static func start_glide(player: Node) -> void:
	player.is_gliding = true
	player.glide_timer = 0.0
	player.glide_direction = 1 if player.is_facing_right else -1
	player.velocity.x = player.glide_direction * player.glide_init_h_speed
	player.velocity.y = 0
	player.change_state(player.PlayerState.GLIDE)

static func exit_glide(player: Node) -> void:
	player.is_gliding = false
	player.glide_timer = 0.0
	player.is_double_jump_holding = false
	if player.velocity.y < 0:
		player.change_state(player.PlayerState.JUMP)
	else:
		player.change_state(player.PlayerState.DOWN)
