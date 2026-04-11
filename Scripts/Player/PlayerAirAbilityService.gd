extends RefCounted
class_name PlayerAirAbilityService

# 复用空气状态工具，保证跳跃、二段跳与滑翔状态切换一致。
const PlayerAirStateServiceScript = preload("res://Scripts/Player/PlayerAirStateService.gd")

# 尝试执行一段跳。
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

	# 尝试执行二段跳或补偿跳。
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

# 进入滑翔状态时清理移动计时和初速度。
static func start_glide(player: Node) -> void:
	player.is_gliding = true
	player.glide_timer = 0.0
	player.glide_direction = 1 if player.is_facing_right else -1
	player.velocity.x = 0.0
	player.velocity.y = 0
	player.change_state(player.PlayerState.GLIDE)

# 退出滑翔状态时回到跳跃或下落流程。
static func exit_glide(player: Node) -> void:
	player.is_gliding = false
	player.glide_timer = 0.0
	player.is_double_jump_holding = false
	if player.velocity.y < 0:
		player.change_state(player.PlayerState.JUMP)
	else:
		player.change_state(player.PlayerState.DOWN)

# 由 JumpBox 触发弹跳并进入持续二段跳状态。
static func start_jumpbox_bounce(player: Node, vertical_force: float, trigger_grade: String = "normal", effect_overrides: Dictionary = {}) -> void:
	if not player.can_accept_jumpbox_bounce():
		return

	player.jumpbox_last_bounce_time_ms = Time.get_ticks_msec()
	player.jumpbox_trigger_grade = "perfect" if trigger_grade == "perfect" else "normal"
	player.jumpbox_afterimage_type = "jumpbox_perfect" if player.jumpbox_trigger_grade == "perfect" else "jumpbox_normal"
	player.jumpbox_horizontal_boost_multiplier = float(effect_overrides.get("horizontal_boost_multiplier", 1.0))
	player.jumpbox_boost_duration_multiplier = float(effect_overrides.get("boost_duration_multiplier", 1.0))
	player.jumpbox_max_vertical_force_multiplier = float(effect_overrides.get("max_vertical_force_multiplier", 1.0))
	player.trigger_feedback_event(&"jumpbox_bounce_started", {
		"grade": player.jumpbox_trigger_grade,
		"afterimage_type": player.jumpbox_afterimage_type,
		"vertical_force": vertical_force,
		"effect_overrides": effect_overrides
	})

	player.jump_hold_timer = player.max_jump_hold_time

	var max_vertical_cap: float = player.jumpbox_max_vertical_force * player.jumpbox_max_vertical_force_multiplier
	player.velocity.y = -clamp(vertical_force, 0.0, max_vertical_cap)

	player.has_dashed_in_air = false
	player.can_dash = true

	player.is_jumpbox_triggered = true
	player.jumpbox_force_applied = true

	player.has_double_jumped = true
	player.is_double_jump_holding = true

	player.is_jumpbox_continuous_jump = true
	player.is_jump_interrupt_decaying = false

	player.is_jump2_boost_active = true
	player.jump2_boost_timer = 0.0

	var move_input: float = Input.get_axis("left", "right")
	player.jump2_boost_direction = 1 if move_input > 0 else -1 if move_input < 0 else (1 if player.is_facing_right else -1)
	if move_input != 0:
		var boosted: float = player.jump2_horizontal_boost * player.jumpbox_horizontal_boost_multiplier
		_apply_jumpbox_horizontal_speed(player, player.jump_move_speed + boosted, player.jump2_boost_direction)

	player.has_jumpbox_afterimage = true
	player.change_state(player.PlayerState.JUMP)

# 处理 JumpBox 触发期间的水平速度加成。
static func handle_jump2_boost(player: Node, fixed_delta: float) -> void:
	if not player.is_jump2_boost_active:
		return

	if player.current_animation == "JUMP2":
		player.jump2_boost_timer += fixed_delta
		var boosted: float = player.jump2_horizontal_boost * player.jumpbox_horizontal_boost_multiplier
		var boost_duration_scaled: float = player.jump2_boost_duration * player.jumpbox_boost_duration_multiplier

		var move_input: float = Input.get_axis("left", "right")
		var current_direction: int = 1 if move_input > 0 else -1 if move_input < 0 else player.jump2_boost_direction

		if move_input != 0:
			player.jump2_boost_direction = current_direction

		var total_duration: float = boost_duration_scaled + player.jump2_boost_decrease_time

		if player.jump2_boost_timer <= boost_duration_scaled:
			if move_input != 0:
				_apply_jumpbox_horizontal_speed(player, player.jump_move_speed + boosted, player.jump2_boost_direction)
			else:
				player.velocity.x = move_toward(player.velocity.x, 0, player.air_control * player.ground_deceleration * (player.jump_move_speed + boosted) * player.effective_acceleration_multiplier)
		elif player.jump2_boost_timer <= total_duration:
			var progress: float = (player.jump2_boost_timer - boost_duration_scaled) / player.jump2_boost_decrease_time
			var current_boost: float = boosted * (1.0 - progress)

			if move_input != 0:
				_apply_jumpbox_horizontal_speed(player, player.jump_move_speed + current_boost, player.jump2_boost_direction)
			else:
				player.velocity.x = move_toward(player.velocity.x, 0, player.air_control * player.ground_deceleration * (player.jump_move_speed + current_boost) * player.effective_acceleration_multiplier)
		else:
			player.is_jump2_boost_active = false
	else:
		player.is_jump2_boost_active = false

# 开始打断 JumpBox 持续二段跳。
static func start_jump_interrupt(player: Node) -> void:
	player.is_jumpbox_continuous_jump = false

	player.is_double_jump_holding = false
	player.animated_sprite.rotation_degrees = 0
	player.jump2_rotation = 0

	player.is_jump2_boost_active = false
	player.has_jumpbox_afterimage = false

	player.is_jump_interrupt_decaying = true
	player.jump_interrupt_decay_timer = 0.0

	player.has_double_jumped = false
	player.can_double_jump = true

	player.has_dashed_in_air = false
	player.can_dash = true

# 处理打断后的垂直速度衰减。
static func handle_jump_interrupt_decay(player: Node, fixed_delta: float) -> void:
	if not player.is_jump_interrupt_decaying:
		return

	if player.current_state == player.PlayerState.DASH or player.current_state == player.PlayerState.HURT or player.current_state == player.PlayerState.DIE:
		player.is_jump_interrupt_decaying = false
		return

	player.jump_interrupt_decay_timer += fixed_delta
	var progress: float = min(player.jump_interrupt_decay_timer / player.jump2_interrupt_decay_time, 1.0)
	player.velocity.y = lerp(player.velocity.y, 0.0, progress)

	if player.jump_interrupt_decay_timer >= player.jump2_interrupt_decay_time:
		player.is_jump_interrupt_decaying = false

# JumpBox 连续跳结束时重置触发态。
static func end_jumpbox_continuous_jump(player: Node) -> void:
	player.is_jumpbox_continuous_jump = false
	player.is_jumpbox_triggered = false
	player.jumpbox_horizontal_boost_multiplier = 1.0
	player.jumpbox_boost_duration_multiplier = 1.0

# 清除 JumpBox 触发效果。
static func clear_jumpbox_effect(player: Node) -> void:
	if not player.is_jumpbox_triggered:
		return
	player.has_double_jumped = false
	player.can_double_jump = true
	player.jump_count = 1

	player.is_jumpbox_triggered = false
	player.jumpbox_trigger_grade = "normal"
	player.jumpbox_afterimage_type = "jumpbox_perfect"
	player.jumpbox_horizontal_boost_multiplier = 1.0
	player.jumpbox_boost_duration_multiplier = 1.0
	player.jumpbox_max_vertical_force_multiplier = 1.0
	player.is_jump2_boost_active = false
	player.has_jumpbox_afterimage = false
	player.is_double_jump_holding = false

	player.is_jumpbox_continuous_jump = false
	player.is_jump_interrupt_decaying = false

static func _apply_jumpbox_horizontal_speed(player: Node, base_speed: float, direction: int) -> void:
	var signed_speed: float = base_speed * player.effective_horizontal_multiplier * direction
	player.velocity.x = clamp(signed_speed, -player.jumpbox_max_horizontal_speed, player.jumpbox_max_horizontal_speed)
