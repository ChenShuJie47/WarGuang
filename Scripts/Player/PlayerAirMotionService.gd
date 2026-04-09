extends RefCounted
class_name PlayerAirMotionService

const NO_INPUT_DECEL_MULTIPLIER_JUMP: float = 1.8
const NO_INPUT_DECEL_MULTIPLIER_DOWN: float = 2.8

static func apply_air_horizontal_motion(player: Node, move_input: float) -> void:
	if player.is_run_jumping or player.is_gliding or player.is_jump2_boost_active:
		return

	if move_input != 0:
		var target_speed = move_input * player.jump_move_speed * player.effective_horizontal_multiplier
		player.velocity.x = move_toward(player.velocity.x, target_speed, player.air_control * player.ground_acceleration * player.jump_move_speed * player.effective_horizontal_multiplier)
		return

	# 空中无输入时按状态快速衰减，避免“空中持续滑行”。
	var layer_multiplier = NO_INPUT_DECEL_MULTIPLIER_JUMP
	if player.current_state == player.PlayerState.DOWN:
		layer_multiplier = NO_INPUT_DECEL_MULTIPLIER_DOWN
	var air_no_input_decel = player.air_control * player.ground_deceleration * player.jump_move_speed * player.effective_acceleration_multiplier * layer_multiplier
	player.velocity.x = move_toward(player.velocity.x, 0, air_no_input_decel)
