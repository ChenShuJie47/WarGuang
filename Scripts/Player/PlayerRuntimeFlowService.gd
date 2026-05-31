extends RefCounted
class_name PlayerRuntimeFlowService

const PlayerDieStateServiceScript = preload("res://Scripts/Player/PlayerDieStateService.gd")

# 处理 _physics_process 的前置阶段（0~5）。
# 返回值：{"handled": bool, "previous_was_on_floor": bool}
static func handle_pre_input_pipeline(player: Node, fixed_delta: float) -> Dictionary:
	player.is_game_paused = player._check_game_pause_state()
	var previous_was_on_floor: bool = player.was_on_floor

	# DIE 状态独占处理。
	if player.current_state == player.PlayerState.DIE:
		PlayerRuntimeTickService.tick_hurt_visual(player, fixed_delta)
		PlayerDieStateServiceScript.handle_die_state(player, fixed_delta)
		player.move_and_slide()
		return {
			"handled": true,
			"previous_was_on_floor": previous_was_on_floor
		}

	# 通用计时。
	PlayerRuntimeTickService.tick_hurt_visual(player, fixed_delta)
	PlayerControlLockService.tick_lock_timer(player, fixed_delta)

	# Hit Stop 期间跳过后续。
	if player.is_hit_stop:
		return {
			"handled": true,
			"previous_was_on_floor": previous_was_on_floor
		}

	# JumpBox 残影状态清理。
	if player.has_jumpbox_afterimage and player.current_animation != "JUMP2":
		player.has_jumpbox_afterimage = false

	# 对话/交互状态独占处理。
	if player.is_in_dialogue or player.current_state == player.PlayerState.INTERACTIVE:
		PlayerDialogueStateService.handle_dialogue_physics(player, fixed_delta)
		player.move_and_slide()
		player.update_animation()
		return {
			"handled": true,
			"previous_was_on_floor": previous_was_on_floor
		}

	# 控制锁定独占处理。
	if PlayerControlLockService.handle_locked_physics(player, fixed_delta):
		return {
			"handled": true,
			"previous_was_on_floor": previous_was_on_floor
		}

	return {
		"handled": false,
		"previous_was_on_floor": previous_was_on_floor
	}

# 采集输入快照，并同步玩家的方向输入状态字段。
static func collect_input_snapshot(player: Node) -> Dictionary:
	var move_input: float = 0.0
	var jump_just_pressed: bool = false
	var jump_pressed: bool = false
	var jump_just_released: bool = false
	var dash_just_pressed: bool = false
	player.is_pressing_up = false
	player.is_pressing_down = false
	if not player.is_control_locked:
		if player.has_method("get_resolved_horizontal_input"):
			move_input = float(player.get_resolved_horizontal_input())
		else:
			move_input = Input.get_axis("left", "right")
		jump_just_pressed = Input.is_action_just_pressed("jump")
		jump_pressed = Input.is_action_pressed("jump")
		jump_just_released = Input.is_action_just_released("jump")
		dash_just_pressed = Input.is_action_just_pressed("dash")
		player.is_pressing_up = Input.is_action_pressed("up")
		player.is_pressing_down = Input.is_action_pressed("down")
	return {
		"move_input": move_input,
		"jump_just_pressed": jump_just_pressed,
		"jump_pressed": jump_pressed,
		"jump_just_released": jump_just_released,
		"dash_just_pressed": dash_just_pressed
	}

# 清空奔跑离地保持链路。
static func clear_airborne_run_keep_tracking(player: Node) -> void:
	player.airborne_run_keep_active = false
	player.airborne_run_keep_valid = false
	player.airborne_run_keep_direction = 0

# 启动奔跑离地保持链路。
static func start_airborne_run_keep_tracking(player: Node, direction: int) -> void:
	if direction == 0:
		clear_airborne_run_keep_tracking(player)
		return
	player.airborne_run_keep_active = true
	player.airborne_run_keep_valid = true
	player.airborne_run_keep_direction = direction

# 更新奔跑离地保持链路。
static func update_airborne_run_keep_tracking(player: Node, move_input: float) -> void:
	if not player.airborne_run_keep_active or not player.airborne_run_keep_valid:
		return
	if move_input == 0 or sign(move_input) != player.airborne_run_keep_direction:
		player.airborne_run_keep_valid = false
		return
	var keep_speed_threshold: float = maxf(player.run_jump_keep_min_horizontal_speed, 0.0)
	if player.velocity.x * player.airborne_run_keep_direction <= keep_speed_threshold:
		player.airborne_run_keep_valid = false

# 处理物理后阶段（地面状态、土狼时间、视觉与朝向）。
static func finalize_post_physics(player: Node, fixed_delta: float, move_input: float, previous_was_on_floor: bool) -> void:
	player.was_on_floor = player.is_on_floor()
	if not previous_was_on_floor and player.was_on_floor:
		player.trigger_feedback_event(&"landed", {
			"position": player.global_position,
			"velocity": player.velocity,
			"state": player.current_state
		})

	if previous_was_on_floor and not player.was_on_floor and player.velocity.y >= 0 and not player.is_jumping:
		player.coyote_time_active = true
		player.coyote_timer.start(player.coyote_time)

	# 奔跑离地连续性跟踪：仅在“奔跑离地”时启动；空中每帧验证“同向按住 + 同向非零速度”。
	if previous_was_on_floor and not player.was_on_floor:
		var leave_direction: int = sign(move_input)
		var from_running_ground: bool = player.current_state == player.PlayerState.RUN or player.is_run_jumping or player.was_running_before_coyote
		if from_running_ground and leave_direction != 0:
			start_airborne_run_keep_tracking(player, leave_direction)
		else:
			clear_airborne_run_keep_tracking(player)

	if not player.was_on_floor:
		update_airborne_run_keep_tracking(player, move_input)

	player.update_coyote_time()
	player.update_animation()
	player.handle_afterimages(fixed_delta)
	player.handle_jump2_rotation(fixed_delta)

	if move_input != 0 and player.current_state != player.PlayerState.DIE and player.current_state != player.PlayerState.HURT and player.current_state != player.PlayerState.DASH and player.current_state != player.PlayerState.BACKSTEP:
		if player.current_state == player.PlayerState.SUPERDASHSTART or player.current_state == player.PlayerState.SUPERDASH:
			pass
		elif player.current_state == player.PlayerState.WALLGRIP:
			pass
		else:
			player.is_facing_right = move_input > 0
			player.animated_sprite.flip_h = not player.is_facing_right
