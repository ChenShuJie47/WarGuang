extends RefCounted
class_name PlayerObserveStateService

# 处理向上观察状态。
static func handle_lookup_state(player: Node, _delta: float, move_input: float, jump_just_pressed: bool, dash_just_pressed: bool) -> void:
	# 任何移动、跳跃、冲刺输入都会打断向上看状态
	if move_input != 0 or jump_just_pressed or dash_just_pressed:
		player.reset_camera_position()
		player.change_state(player.PlayerState.IDLE)
		return

	# 松开上键也会退出
	if not player.is_pressing_up:
		player.reset_camera_position()
		player.change_state(player.PlayerState.IDLE)
		return

	# 受伤或死亡也会打断
	if player.is_invincible or player.is_dying:
		player.reset_camera_position()
		player.change_state(player.PlayerState.IDLE)
		return

	# 向上看状态下保持静止，并触发观察偏移目标。
	player.velocity.x = move_toward(
		player.velocity.x,
		0.0,
		player.ground_deceleration * player.base_move_speed * player.effective_acceleration_multiplier
	)
	player.PlayerCameraBridgeServiceScript.apply_lookup_observe_offset(player)

# 处理向下观察状态。
static func handle_lookdown_state(player: Node, _delta: float, move_input: float, jump_just_pressed: bool, dash_just_pressed: bool) -> void:
	# 任何移动、跳跃、冲刺输入都会打断向下看状态
	if move_input != 0 or jump_just_pressed or dash_just_pressed:
		player.reset_camera_position()
		player.change_state(player.PlayerState.IDLE)
		return

	# 松开下键也会退出
	if not player.is_pressing_down:
		player.reset_camera_position()
		player.change_state(player.PlayerState.IDLE)
		return

	# 受伤或死亡也会打断
	if player.is_invincible or player.is_dying:
		player.reset_camera_position()
		player.change_state(player.PlayerState.IDLE)
		return

	# 向下看状态下保持静止，并触发观察偏移目标。
	player.velocity.x = move_toward(
		player.velocity.x,
		0.0,
		player.ground_deceleration * player.base_move_speed * player.effective_acceleration_multiplier
	)
	player.PlayerCameraBridgeServiceScript.apply_lookdown_observe_offset(player)
