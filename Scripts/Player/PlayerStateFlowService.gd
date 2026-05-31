extends RefCounted
class_name PlayerStateFlowService

const PlayerMovementServiceScript = preload("res://Scripts/Player/PlayerMovementService.gd")
const PlayerAirAbilityServiceScript = preload("res://Scripts/Player/PlayerAirAbilityService.gd")
const PlayerAirMotionServiceScript = preload("res://Scripts/Player/PlayerAirMotionService.gd")
const PlayerGlideStateServiceScript = preload("res://Scripts/Player/PlayerGlideStateService.gd")
const PlayerHurtStateServiceScript = preload("res://Scripts/Player/PlayerHurtStateService.gd")
const PlayerDieStateServiceScript = preload("res://Scripts/Player/PlayerDieStateService.gd")
const PlayerSleepStateServiceScript = preload("res://Scripts/Player/PlayerSleepStateService.gd")
const PlayerObserveStateServiceScript = preload("res://Scripts/Player/PlayerObserveStateService.gd")

# 统一空中转墙附着入口，避免 JUMP/DOWN/GLIDE/WALLJUMP 判定分散。
static func handle_state(player: Node, fixed_delta: float, move_input: float, jump_just_pressed: bool, jump_pressed: bool, jump_just_released: bool, dash_just_pressed: bool) -> void:
	match player.current_state:
		player.PlayerState.IDLE:
			handle_idle_state(player, fixed_delta, move_input, jump_just_pressed, dash_just_pressed)
		player.PlayerState.MOVE:
			handle_move_state(player, fixed_delta, move_input, jump_just_pressed, dash_just_pressed)
		player.PlayerState.RUN:
			handle_run_state(player, fixed_delta, move_input, jump_just_pressed, dash_just_pressed)
		player.PlayerState.JUMP:
			handle_jump_state(player, fixed_delta, move_input, jump_just_pressed, jump_pressed, jump_just_released, dash_just_pressed)
		player.PlayerState.GLIDE:
			handle_glide_state(player, fixed_delta, move_input, jump_pressed, dash_just_pressed)
		player.PlayerState.DOWN:
			handle_down_state(player, fixed_delta, move_input, jump_just_pressed, jump_pressed, jump_just_released, dash_just_pressed)
		player.PlayerState.DASH:
			handle_dash_state(player)
		player.PlayerState.SUPERDASHSTART:
			handle_super_dash_start_state(player, fixed_delta)
		player.PlayerState.SUPERDASH:
			handle_super_dash_state(player, fixed_delta, move_input, jump_just_pressed, dash_just_pressed)
		player.PlayerState.BACKSTEP:
			handle_backstep_state(player, fixed_delta, move_input)
		player.PlayerState.HURT:
			handle_hurt_state(player, fixed_delta)
		player.PlayerState.DIE:
			handle_die_state(player, fixed_delta)
		player.PlayerState.SLEEP:
			handle_sleep_state(player, fixed_delta, move_input, jump_just_pressed, dash_just_pressed)
		player.PlayerState.LOOKUP:
			handle_lookup_state(player, fixed_delta, move_input, jump_just_pressed, dash_just_pressed)
		player.PlayerState.LOOKDOWN:
			handle_lookdown_state(player, fixed_delta, move_input, jump_just_pressed, dash_just_pressed)
		player.PlayerState.INTERACTIVE:
			handle_interactive_state(player, fixed_delta)
		player.PlayerState.WALLGRIP:
			handle_wallgrip_state(player, fixed_delta, move_input, jump_just_pressed, jump_pressed, jump_just_released, dash_just_pressed)
		player.PlayerState.WALLJUMP:
			handle_walljump_state(player, fixed_delta, move_input, jump_just_pressed, jump_pressed, jump_just_released, dash_just_pressed)

static func handle_idle_state(player: Node, _delta: float, move_input: float, jump_just_pressed: bool, dash_just_pressed: bool) -> void:
	PlayerMovementServiceScript.handle_idle_state(player, _delta, move_input, jump_just_pressed, dash_just_pressed)

static func handle_move_state(player: Node, _delta: float, move_input: float, jump_just_pressed: bool, dash_just_pressed: bool) -> void:
	PlayerMovementServiceScript.handle_move_state(player, _delta, move_input, jump_just_pressed, dash_just_pressed)

static func handle_run_state(player: Node, _delta: float, move_input: float, jump_just_pressed: bool, dash_just_pressed: bool) -> void:
	PlayerMovementServiceScript.handle_run_state(player, _delta, move_input, jump_just_pressed, dash_just_pressed)

static func handle_jump_state(player: Node, fixed_delta: float, move_input: float, jump_just_pressed: bool, jump_pressed: bool, jump_just_released: bool, dash_just_pressed: bool) -> void:
	if player.is_on_floor():
		player.handle_landing()
		return

	if jump_just_released and player.is_double_jump_holding and not player.is_jumpbox_triggered:
		player.is_double_jump_holding = false

	if player.is_jumpbox_continuous_jump and player.jump2_interrupt_enabled and jump_just_pressed:
		player.start_jump_interrupt()
		return

	if PlayerAirAbilityServiceScript.try_wall_jump_from_escape_buffer(player, jump_just_pressed):
		return

	if PlayerMovementServiceScript.try_start_wallgrip_from_air(player, move_input, jump_just_pressed):
		return

	if player.try_dash(dash_just_pressed):
		return

	if player.try_double_jump(jump_just_pressed):
		return

	if player.can_glide and not player.is_gliding and jump_just_pressed and not player.is_double_jump_holding and player.glide_unlocked:
		player.start_glide()
		return

	if jump_pressed and player.jump_hold_timer < player.max_jump_hold_time:
		player.velocity.y += player.jump_hold_boost
		player.jump_hold_timer += fixed_delta

	PlayerAirMotionServiceScript.apply_air_horizontal_motion(player, move_input)

	if player.velocity.y >= 0 and not player.is_gliding:
		player.change_state(player.PlayerState.DOWN)

static func handle_down_state(player: Node, fixed_delta: float, move_input: float, jump_just_pressed: bool, jump_pressed: bool, jump_just_released: bool, dash_just_pressed: bool) -> void:
	if player.is_on_floor():
		player.handle_landing()
		return

	if jump_just_released and player.is_double_jump_holding and not player.is_jumpbox_triggered:
		player.is_double_jump_holding = false

	if player.is_jumpbox_continuous_jump and player.jump2_interrupt_enabled and jump_just_pressed:
		player.start_jump_interrupt()
		return

	if PlayerAirAbilityServiceScript.try_wall_jump_from_escape_buffer(player, jump_just_pressed):
		return

	if PlayerMovementServiceScript.try_start_wallgrip_from_air(player, move_input, jump_just_pressed):
		return

	if player.try_dash(dash_just_pressed):
		return

	if player.has_double_jumped and jump_just_released and not player.is_jumpbox_triggered:
		player.is_double_jump_holding = false

	if player.try_double_jump(jump_just_pressed):
		return

	if player.can_glide and not player.is_gliding and jump_just_pressed and not player.is_double_jump_holding and player.glide_unlocked:
		player.start_glide()
		return

	if jump_pressed and player.jump_hold_timer < player.max_jump_hold_time and player.has_double_jumped:
		player.velocity.y += player.jump_hold_boost
		player.jump_hold_timer += fixed_delta

	PlayerAirMotionServiceScript.apply_air_horizontal_motion(player, move_input)

static func handle_glide_state(player: Node, fixed_delta: float, move_input: float, jump_pressed: bool, dash_just_pressed: bool) -> void:
	PlayerGlideStateServiceScript.handle_state(player, fixed_delta, move_input, jump_pressed, dash_just_pressed)

static func handle_dash_state(player: Node) -> void:
	PlayerMovementServiceScript.handle_dash_state(player)

static func handle_super_dash_start_state(player: Node, fixed_delta: float) -> void:
	var super_dash_pressed: bool = Input.is_action_pressed("super_dash")
	player.is_in_special_state = true

	if player.super_dash_charge_timer >= player.super_dash_charge_time:
		if not super_dash_pressed:
			PlayerMovementServiceScript.start_super_dash(player)
			return
	else:
		if not super_dash_pressed:
			player.is_super_dash_charging = false
			player.super_dash_charge_timer = 0.0
			player.is_in_special_state = false
			player.change_state(player.PlayerState.IDLE)
			return

	player.super_dash_charge_timer += fixed_delta
	player.velocity.x = move_toward(player.velocity.x, 0, player.ground_deceleration * player.base_move_speed * player.effective_acceleration_multiplier)
	player.apply_gravity(fixed_delta)

static func handle_super_dash_state(player: Node, fixed_delta: float, move_input: float, jump_just_pressed: bool, dash_just_pressed: bool) -> void:
	if player.super_dash_deceleration_timer > 0.0:
		if PlayerMovementServiceScript.try_start_wallgrip_from_air(player, move_input):
			player.super_dash_deceleration_timer = 0.0
			player.is_in_special_state = false
			player.super_dash_input_lock_timer = 0.0
			player.super_dash_afterimage_timer = player.super_dash_afterimage_start_delay
			return

		if jump_just_pressed:
			if player.try_double_jump(true):
				player.super_dash_deceleration_timer = 0.0
				player.super_dash_deceleration_afterimage_timer = 0.0
				return
			if player.try_jump(true):
				player.super_dash_deceleration_timer = 0.0
				player.super_dash_deceleration_afterimage_timer = 0.0
				return

		if dash_just_pressed:
			if move_input != 0:
				player.is_facing_right = move_input > 0
				player.animated_sprite.flip_h = not player.is_facing_right
			if player.try_dash(true):
				player.super_dash_deceleration_timer = 0.0
				player.is_in_special_state = false
				player.super_dash_input_lock_timer = 0.0
				player.super_dash_afterimage_timer = player.super_dash_afterimage_start_delay
			return

		var deceleration_time: float = maxf(player.super_dash_deceleration_time, 0.01)
		player.super_dash_deceleration_timer += fixed_delta
		var deceleration_ratio: float = clampf(player.super_dash_deceleration_timer / deceleration_time, 0.0, 1.0)
		var deceleration_speed: float = player.super_dash_speed * (1.0 - pow(deceleration_ratio, 1.8))
		var deceleration_direction: Vector2 = Vector2(1 if player.is_facing_right else -1, -1).normalized()
		player.velocity = deceleration_direction * deceleration_speed * player.effective_horizontal_multiplier
		if player.super_dash_deceleration_timer >= deceleration_time or deceleration_speed <= 1.0:
			player.super_dash_deceleration_timer = 0.0
			player.super_dash_deceleration_afterimage_timer = 0.0
			if player.is_on_floor():
				var resolved_input: float = player.get_resolved_horizontal_input() if player.has_method("get_resolved_horizontal_input") else Input.get_axis("left", "right")
				if resolved_input == 0:
					player.change_state(player.PlayerState.IDLE)
				else:
					player.change_state(player.PlayerState.MOVE)
				return
			player.change_state(player.PlayerState.DOWN)
		return

	if jump_just_pressed or player.super_dash_duration_timer >= player.super_dash_max_duration:
		player.super_dash_deceleration_timer = 0.0001
		player.is_in_special_state = false
		player.super_dash_input_lock_timer = 0.0
		player.super_dash_afterimage_timer = player.super_dash_afterimage_start_delay
		return

	player.super_dash_duration_timer += fixed_delta

	if player.super_dash_input_lock_timer > 0:
		player.super_dash_input_lock_timer -= fixed_delta

	if player.super_dash_accel_timer < player.super_dash_accel_time:
		player.super_dash_accel_timer += fixed_delta
		var progress: float = player.super_dash_accel_timer / player.super_dash_accel_time
		var current_speed: float = lerp(0.0, player.super_dash_speed, progress)
		var dash_direction: Vector2 = Vector2(1 if player.is_facing_right else -1, -1).normalized()
		player.velocity = dash_direction * current_speed * player.effective_horizontal_multiplier
	else:
		var dash_direction: Vector2 = Vector2(1 if player.is_facing_right else -1, -1).normalized()
		player.velocity = dash_direction * player.super_dash_speed * player.effective_horizontal_multiplier

	player.super_dash_afterimage_timer += fixed_delta
	if player.super_dash_afterimage_timer >= player.super_dash_afterimage_start_delay:
		var super_dash_interval: float = player._get_afterimage_interval("super_dash")
		if player.super_dash_afterimage_timer - player.super_dash_afterimage_start_delay >= super_dash_interval:
			player.super_dash_afterimage_timer = player.super_dash_afterimage_start_delay
			player.create_afterimage(player.PlayerState.SUPERDASH)

	if player.is_on_wall() or player.is_on_ceiling():
		CameraShakeManager.shake("x_strong", player.phantom_camera)
		player.is_in_special_state = false
		player.has_double_jumped = false
		player.can_double_jump = true
		player.change_state(player.PlayerState.DOWN)
		return

	if player.super_dash_input_lock_timer <= 0:
		if dash_just_pressed:
			if move_input != 0:
				player.is_facing_right = move_input > 0
				player.animated_sprite.flip_h = not player.is_facing_right
			if player.try_dash(true):
				player.is_in_special_state = false
				return

static func handle_backstep_state(player: Node, fixed_delta: float, move_input: float) -> void:
	PlayerMovementServiceScript.handle_backstep_state(player, fixed_delta, move_input)

static func handle_hurt_state(player: Node, fixed_delta: float) -> void:
	PlayerHurtStateServiceScript.handle_hurt_state(player, fixed_delta)

static func handle_die_state(player: Node, fixed_delta: float) -> void:
	PlayerDieStateServiceScript.handle_die_state(player, fixed_delta)

static func handle_sleep_state(player: Node, fixed_delta: float, move_input: float, jump_just_pressed: bool, dash_just_pressed: bool) -> void:
	PlayerSleepStateServiceScript.handle_sleep_state(player, fixed_delta, move_input, jump_just_pressed, dash_just_pressed)

static func handle_lookup_state(player: Node, fixed_delta: float, move_input: float, jump_just_pressed: bool, dash_just_pressed: bool) -> void:
	PlayerObserveStateServiceScript.handle_lookup_state(player, fixed_delta, move_input, jump_just_pressed, dash_just_pressed)

static func handle_lookdown_state(player: Node, fixed_delta: float, move_input: float, jump_just_pressed: bool, dash_just_pressed: bool) -> void:
	PlayerObserveStateServiceScript.handle_lookdown_state(player, fixed_delta, move_input, jump_just_pressed, dash_just_pressed)

static func handle_interactive_state(player: Node, fixed_delta: float) -> void:
	PlayerSleepStateServiceScript.handle_interactive_state(player, fixed_delta)

static func handle_wallgrip_state(player: Node, fixed_delta: float, move_input: float, jump_just_pressed: bool, jump_pressed: bool, jump_just_released: bool, dash_just_pressed: bool) -> void:
	PlayerMovementServiceScript.handle_wallgrip_state(player, fixed_delta, move_input, jump_just_pressed, jump_pressed, jump_just_released, dash_just_pressed)

static func handle_walljump_state(player: Node, fixed_delta: float, move_input: float, jump_just_pressed: bool, jump_pressed: bool, jump_just_released: bool, dash_just_pressed: bool) -> void:
	PlayerMovementServiceScript.handle_walljump_state(player, fixed_delta, move_input, jump_just_pressed, jump_pressed, jump_just_released, dash_just_pressed)
