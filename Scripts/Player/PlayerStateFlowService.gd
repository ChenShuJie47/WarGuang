extends RefCounted
class_name PlayerStateFlowService

const PlayerMovementServiceScript = preload("res://Scripts/Player/PlayerMovementService.gd")
const PlayerAirMotionServiceScript = preload("res://Scripts/Player/PlayerAirMotionService.gd")
const PlayerGlideStateServiceScript = preload("res://Scripts/Player/PlayerGlideStateService.gd")
const PlayerHurtStateServiceScript = preload("res://Scripts/Player/PlayerHurtStateService.gd")
const PlayerDieStateServiceScript = preload("res://Scripts/Player/PlayerDieStateService.gd")
const PlayerSleepStateServiceScript = preload("res://Scripts/Player/PlayerSleepStateService.gd")
const PlayerObserveStateServiceScript = preload("res://Scripts/Player/PlayerObserveStateService.gd")

# 统一空中转墙附着入口，避免 JUMP/DOWN/GLIDE/WALLJUMP 判定分散。
static func handle_state(player: Node, fixed_delta: float, move_input: float, jump_just_pressed: bool, jump_pressed: bool, jump_just_released: bool, dash_just_pressed: bool) -> void:
	if _try_enter_wallgrip_from_air(player, move_input):
		return

	if player.wall_grip_reverse_timer_node.time_left > 0 and jump_just_pressed:
		player.start_normal_jump_from_wall()
		player.wall_grip_reverse_timer_node.stop()
		return

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
			handle_super_dash_state(player, fixed_delta, jump_just_pressed, dash_just_pressed)
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

static func _try_enter_wallgrip_from_air(player: Node, move_input: float) -> bool:
	return PlayerMovementServiceScript.try_enter_wallgrip_from_air(player, move_input)

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

	if player.is_touching_wall and player.wall_grip_unlocked and move_input != 0 and sign(move_input) == player.wall_direction:
		player.start_wallgrip()
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

	if player.is_touching_wall and player.wall_grip_unlocked and move_input != 0 and sign(move_input) == player.wall_direction:
		player.start_wallgrip()
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

static func handle_super_dash_state(player: Node, fixed_delta: float, jump_just_pressed: bool, dash_just_pressed: bool) -> void:
	player.super_dash_duration_timer += fixed_delta
	if player.super_dash_duration_timer >= player.super_dash_max_duration:
		player.is_in_special_state = false
		player.is_jumping = false
		player.jump_count = 0
		player.has_double_jumped = false
		player.can_double_jump = true
		player.can_glide = false
		player.change_state(player.PlayerState.DOWN)
		return

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
	if player.super_dash_afterimage_timer >= player._get_afterimage_interval("super_dash"):
		player.super_dash_afterimage_timer = 0
		player.create_afterimage(player.PlayerState.SUPERDASH)

	if player.is_on_wall() or player.is_on_ceiling():
		CameraShakeManager.shake("x_strong", player.phantom_camera)
		player.is_in_special_state = false
		player.has_double_jumped = false
		player.can_double_jump = true
		player.change_state(player.PlayerState.DOWN)
		return

	if player.super_dash_input_lock_timer <= 0:
		if jump_just_pressed:
			player.is_in_special_state = false
			player.is_jumping = false
			player.jump_count = 0
			player.has_double_jumped = false
			player.can_double_jump = true
			player.can_glide = false
			player.change_state(player.PlayerState.JUMP)
			return
		if dash_just_pressed:
			player.is_in_special_state = false
			player.is_jumping = false
			player.jump_count = 0
			player.has_double_jumped = false
			player.can_double_jump = true
			player.can_glide = false
			if not player.is_on_floor() and not player.coyote_time_active:
				player.has_dashed_in_air = true
			player.change_state(player.PlayerState.DASH)
			return

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
