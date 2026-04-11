extends RefCounted
class_name PlayerMovementService

# 复用空气能力服务，避免移动状态和跳跃状态各自写一套切换逻辑。
const PlayerAirAbilityServiceScript = preload("res://Scripts/Player/PlayerAirAbilityService.gd")

# 处理地面快速双击奔跑检测。
static func detect_run_input(player: Node, move_input: float) -> void:
	if move_input != 0 and (player.is_on_floor() or player.coyote_time_active):
		var current_time: float = Time.get_unix_time_from_system()
		var move_direction: int = 1 if move_input > 0 else -1

		if Input.is_action_just_pressed("right") or Input.is_action_just_pressed("left"):
			if move_direction == player.last_move_direction:
				var time_since_last_input: float = current_time - player.last_move_input_time
				if time_since_last_input < player.quick_tap_time_window:
					player.is_run_ready = true
					player.run_direction = move_direction
			else:
				player.is_run_ready = false

			player.last_move_input_time = current_time
			player.last_move_direction = move_direction

		if player.is_run_ready and player.run_direction == move_direction:
			player.is_running = true
			if player.is_on_floor():
				player.was_running_before_coyote = true
		else:
			player.is_running = false
	else:
		player.is_running = false
		player.is_run_ready = false

	if player.is_on_floor():
		player.was_running_before_coyote = player.is_running

# 处理奔跑跳速度窗口。
static func handle_run_jump(player: Node, fixed_delta: float) -> void:
	if player.current_state == player.PlayerState.DASH or player.current_state == player.PlayerState.SUPERDASH or player.current_state == player.PlayerState.SUPERDASHSTART:
		return
	if not player.is_run_jumping:
		return

	player.run_jump_timer -= fixed_delta
	var move_input: float = Input.get_axis("left", "right")
	if move_input == 0:
		player.is_run_jumping = false
		return
	if sign(move_input) != player.run_jump_original_direction:
		player.is_run_jumping = false
		return

	if player.run_jump_timer > 0:
		player.velocity.x = player.run_jump_original_direction * (player.base_move_speed + player.run_jump_boost_speed) * player.effective_horizontal_multiplier
		return

	var target_speed: float = player.run_jump_original_direction * player.base_move_speed
	player.velocity.x = move_toward(player.velocity.x, target_speed, player.run_jump_boost_speed * fixed_delta / player.run_jump_decay_time)
	if abs(player.velocity.x) <= player.base_move_speed:
		player.is_run_jumping = false

# 进入超级冲刺状态。
static func start_super_dash(player: Node) -> void:
	player.is_super_dash_charging = false
	player.super_dash_charge_timer = 0.0
	player.super_dash_accel_timer = 0.0
	player.super_dash_input_lock_timer = player.super_dash_input_lock_time
	player.super_dash_duration_timer = 0.0
	player.is_in_special_state = true
	player.change_state(player.PlayerState.SUPERDASH)

# 处理冲刺计时结束后的状态回退。
static func handle_dash_timers(player: Node, fixed_delta: float) -> void:
	if player.current_state == player.PlayerState.DASH:
		player.dash_duration_timer += fixed_delta
		var current_dash_duration = player.black_dash_duration if player.black_dash_unlocked else player.dash_duration
		if player.dash_duration_timer >= current_dash_duration:
			player.dash_duration_timer = 0
			if player.was_gliding_before_dash:
				player.was_gliding_before_dash = false
				player.change_state(player.PlayerState.DOWN)
			elif player.is_on_floor() or player.coyote_time_active:
				var move_input = Input.get_axis("left", "right")
				if move_input == 0:
					player.change_state(player.PlayerState.IDLE)
				else:
					player.change_state(player.PlayerState.MOVE)
			else:
				if player.velocity.y < 0:
					player.change_state(player.PlayerState.JUMP)
				else:
					player.change_state(player.PlayerState.DOWN)

# 处理冲刺输入和冲刺进入条件。
static func try_dash(player: Node, dash_just_pressed: bool) -> bool:
	if dash_just_pressed and player.can_dash and player.dash_unlocked:
		player.was_gliding_before_dash = (player.current_state == player.PlayerState.GLIDE)

		if player.was_gliding_before_dash:
			player.is_gliding = false
			player.glide_timer = 0.0
			player.is_double_jump_holding = false

		if not player.is_on_floor() and not player.coyote_time_active:
			if player.has_dashed_in_air:
				return false
			player.has_dashed_in_air = true

		player.change_state(player.PlayerState.DASH)
		player.can_dash = false
		player.dash_duration_timer = 0
		var current_dash_duration = player.black_dash_duration if player.black_dash_unlocked else player.dash_duration
		player.dash_duration_timer_node.start(current_dash_duration)
		player.dash_cooldown_timer_node.start(player.dash_cooldown)
		return true
	elif dash_just_pressed and not player.dash_unlocked:
		print("冲刺能力尚未解锁！")
	return false

# 处理站立状态的派生状态切换。
static func handle_idle_state(player: Node, _delta: float, move_input: float, jump_just_pressed: bool, dash_just_pressed: bool) -> void:
	if player.sleep_timer >= player.idle_to_sleep_time:
		player.change_state(player.PlayerState.SLEEP)
		return

	if player.is_pressing_up and not player.is_pressing_down and player.look_timer >= player.idle_to_look_time:
		player.change_state(player.PlayerState.LOOKUP)
		return

	if player.is_pressing_down and not player.is_pressing_up and player.look_timer >= player.idle_to_look_time:
		player.change_state(player.PlayerState.LOOKDOWN)
		return

	if player.super_dash_unlocked and Input.is_action_pressed("super_dash") and player.current_state != player.PlayerState.DASH:
		player.is_super_dash_charging = true
		player.change_state(player.PlayerState.SUPERDASHSTART)
		return

	if not player.is_on_floor() and not player.coyote_time_active:
		if player.velocity.y < 0:
			player.change_state(player.PlayerState.JUMP)
		else:
			player.change_state(player.PlayerState.DOWN)
		return

	if try_dash(player, dash_just_pressed):
		return

	if PlayerAirAbilityServiceScript.try_jump(player, jump_just_pressed):
		return

	if move_input != 0:
		if player.is_running:
			player.change_state(player.PlayerState.RUN)
		else:
			player.change_state(player.PlayerState.MOVE)
	else:
		var target_speed = move_input * player.base_move_speed * player.effective_horizontal_multiplier
		player.velocity.x = move_toward(player.velocity.x, target_speed, player.ground_acceleration * player.base_move_speed * player.effective_horizontal_multiplier)

# 处理普通移动状态的地面逻辑。
static func handle_move_state(player: Node, _delta: float, move_input: float, jump_just_pressed: bool, dash_just_pressed: bool) -> void:
	if not player.is_on_floor() and not player.coyote_time_active:
		if player.velocity.y < 0:
			player.change_state(player.PlayerState.JUMP)
		else:
			player.change_state(player.PlayerState.DOWN)
		return

	if try_dash(player, dash_just_pressed):
		return

	if PlayerAirAbilityServiceScript.try_jump(player, jump_just_pressed):
		return

	if player.super_dash_unlocked and Input.is_action_pressed("super_dash") and player.current_state != player.PlayerState.DASH:
		player.is_super_dash_charging = true
		player.change_state(player.PlayerState.SUPERDASHSTART)
		return

	if player.current_state == player.PlayerState.RUN and player.is_on_wall():
		var wall_normal = player.get_wall_normal()
		if wall_normal.dot(Vector2(move_input, 0)) < 0:
			handle_wall_bump(player)
			return

	if move_input == 0:
		player.change_state(player.PlayerState.IDLE)
	else:
		if player.is_running:
			player.change_state(player.PlayerState.RUN)

		var target_speed = move_input * player.base_move_speed * player.effective_horizontal_multiplier
		player.velocity.x = move_toward(player.velocity.x, target_speed, player.ground_acceleration * player.base_move_speed * player.effective_horizontal_multiplier)

# 处理跑步状态的地面逻辑。
static func handle_run_state(player: Node, _delta: float, move_input: float, jump_just_pressed: bool, dash_just_pressed: bool) -> void:
	if not player.is_on_floor() and not player.coyote_time_active:
		if player.velocity.y < 0:
			player.change_state(player.PlayerState.JUMP)
		else:
			player.change_state(player.PlayerState.DOWN)
		return

	if try_dash(player, dash_just_pressed):
		return

	if PlayerAirAbilityServiceScript.try_jump(player, jump_just_pressed):
		return

	if player.super_dash_unlocked and Input.is_action_pressed("super_dash") and player.current_state != player.PlayerState.DASH:
		player.is_super_dash_charging = true
		player.change_state(player.PlayerState.SUPERDASHSTART)
		return

	if player.current_state == player.PlayerState.RUN and player.is_on_wall():
		var wall_normal = player.get_wall_normal()
		if wall_normal.dot(Vector2(move_input, 0)) < 0:
			handle_wall_bump(player)
			return

	if move_input == 0:
		player.change_state(player.PlayerState.IDLE)
	else:
		if not player.is_running:
			player.change_state(player.PlayerState.MOVE)
		else:
			var target_speed = move_input * player.run_move_speed * player.effective_horizontal_multiplier
			player.velocity.x = move_toward(player.velocity.x, target_speed, player.ground_acceleration * player.run_move_speed * player.effective_horizontal_multiplier)

# 处理基础冲刺状态的速度锁定。
static func handle_dash_state(player: Node) -> void:
	var dash_direction = 1 if player.is_facing_right else -1
	player.velocity.x = dash_direction * player.dash_speed
	player.velocity.y = 0

	if Input.is_action_pressed("jump"):
		if player.can_double_jump and not player.has_double_jumped:
			player.jump_buffer_after_dash = true
			player.jump_buffer_type = 2
		else:
			player.jump_buffer_after_dash = true
			player.jump_buffer_type = 1

	# 处理攀墙状态的受力、减速和跳跃入口。
static func handle_wallgrip_state(player: Node, fixed_delta: float, move_input: float, jump_just_pressed: bool, _jump_pressed: bool, _jump_just_released: bool, dash_just_pressed: bool) -> void:
	if try_dash(player, dash_just_pressed):
		return

	if not player.is_touching_wall or player.is_on_floor():
		player.exit_wallgrip()
		return

	var toward_wall = (move_input > 0 and player.wall_direction == 1) or (move_input < 0 and player.wall_direction == -1)
	var away_from_wall = (move_input < 0 and player.wall_direction == 1) or (move_input > 0 and player.wall_direction == -1)

	if player.is_invincible and player.current_state == player.PlayerState.HURT:
		player.exit_wallgrip()
		return

	if toward_wall:
		player.no_input_timer = 0.0
		player.hold_toward_wall_timer += fixed_delta

		if player.hold_toward_wall_timer < player.hold_toward_wall_time:
			player.velocity.y = 0
			player.current_wall_slide_speed = 0
		else:
			player.velocity.y = player.wall_slide_slow_speed * player.effective_gravity_multiplier
			player.current_wall_slide_speed = player.wall_slide_slow_speed * player.effective_gravity_multiplier
		player.velocity.x = 0
	elif away_from_wall:
		player.wall_grip_reverse_timer_node.start(player.wall_grip_reverse_buffer_time)
		player.exit_wallgrip()
		return
	else:
		player.no_input_timer += fixed_delta
		var progress = min(player.no_input_timer / player.no_input_time, 1.0)
		player.current_wall_slide_speed = lerp(player.wall_slide_slow_speed, player.wall_slide_speed, progress) * player.effective_gravity_multiplier
		player.velocity.y = player.current_wall_slide_speed
		player.velocity.x = 0

	if jump_just_pressed:
		if toward_wall:
			player.start_wall_jump()
		else:
			player.start_normal_jump_from_wall()
		return

	if PlayerAirAbilityServiceScript.try_double_jump(player, jump_just_pressed):
		return

# 处理墙跳后的过渡加速和重新附着判定。
static func handle_walljump_state(player: Node, fixed_delta: float, move_input: float, jump_just_pressed: bool, jump_pressed: bool, _jump_just_released: bool, dash_just_pressed: bool) -> void:
	if try_dash(player, dash_just_pressed):
		return

	if PlayerAirAbilityServiceScript.try_double_jump(player, jump_just_pressed):
		return

	player.wall_jump_timer += fixed_delta

	if player.wall_jump_timer < 0.1:
		player.velocity.x = player.wall_jump_h_speed * -player.wall_direction * player.effective_horizontal_multiplier
		player.velocity.y = player.wall_jump_v_speed * player.effective_vertical_multiplier
	else:
		if move_input != 0:
			var target_speed = move_input * player.base_move_speed
			player.velocity.x = move_toward(player.velocity.x, target_speed, player.air_control * player.ground_acceleration * player.base_move_speed * player.effective_acceleration_multiplier)

	if jump_pressed and player.wall_jump_hold_timer < player.wall_jump_max_hold_time:
		player.velocity.y += player.wall_jump_hold_boost
		player.wall_jump_hold_timer += fixed_delta

	player.apply_gravity(fixed_delta)

	if player.wall_jump_timer >= player.wall_jump_reattach_delay:
		player.can_reattach_to_wall = true
		if player.is_touching_wall and move_input != 0 and sign(move_input) == player.wall_direction:
			player.start_wallgrip()
		elif player.velocity.y >= 0:
			player.change_state(player.PlayerState.DOWN)

	# 处理撞墙后的反弹和相机反馈。
static func handle_wall_bump(player: Node) -> void:
	CameraShakeManager.shake("x_strong", player.phantom_camera)
	player.velocity.x = player.wall_bump_rebound_x * (-1 if player.is_facing_right else 1)
	player.velocity.y = player.wall_bump_rebound_y
	player.hurt_timer = player.hurt_stun_time
	player.is_wall_bump_stun = true

# 处理撞墙僵直期间的重力与恢复。
static func handle_wall_bump_stun(player: Node, fixed_delta: float) -> void:
	player.apply_gravity(fixed_delta)
	player.velocity.x = move_toward(player.velocity.x, 0, player.dash_inertia_decay * player.base_move_speed * fixed_delta)
	player.hurt_timer -= fixed_delta

	if player.hurt_timer <= 0:
		player.is_wall_bump_stun = false
		if player.is_on_floor():
			player.change_state(player.PlayerState.IDLE)
		else:
			player.change_state(player.PlayerState.DOWN)

# 尝试从空中直接进入攀墙状态。
static func try_enter_wallgrip_from_air(player: Node, move_input: float) -> bool:
	if player.is_on_floor() or not player.wall_grip_unlocked or not player.is_touching_wall:
		return false

	if player.current_state != player.PlayerState.JUMP and player.current_state != player.PlayerState.DOWN and player.current_state != player.PlayerState.GLIDE and player.current_state != player.PlayerState.WALLJUMP:
		return false

	if player.current_state == player.PlayerState.WALLJUMP and not player.can_reattach_to_wall:
		return false

	var toward_wall = (move_input > 0 and player.wall_direction == 1) or (move_input < 0 and player.wall_direction == -1)
	if not toward_wall:
		return false

	player.start_wallgrip()
	return player.current_state == player.PlayerState.WALLGRIP
