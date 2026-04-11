extends RefCounted
class_name PlayerSleepStateService

# 处理交互状态：保持水平静止，仅允许重力。
static func handle_interactive_state(player: Node, fixed_delta: float) -> void:
	player.velocity.x = 0.0
	if not player.is_on_floor():
		player.apply_gravity(fixed_delta)

# 处理睡眠状态。
static func handle_sleep_state(player: Node, fixed_delta: float, move_input: float, jump_just_pressed: bool, dash_just_pressed: bool) -> void:
	# 任何输入都会打断睡眠状态
	if (move_input != 0 or jump_just_pressed or dash_just_pressed or
		player.is_pressing_up or player.is_pressing_down):
		player.change_state(player.PlayerState.IDLE)
		return

	# 受伤或死亡也会打断
	if player.is_invincible or player.is_dying:
		player.change_state(player.PlayerState.IDLE)
		return

	if not player.is_on_floor():
		player.velocity.y += player.gravity * fixed_delta
		player.velocity.y = min(player.velocity.y, player.max_fall_speed)
	else:
		player.velocity.y = 0.0

	player.velocity.x = move_toward(
		player.velocity.x,
		0.0,
		player.ground_deceleration * player.base_move_speed * player.effective_acceleration_multiplier
	)
