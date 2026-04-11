extends RefCounted
class_name PlayerRuntimeFlowService

# 处理 _physics_process 的前置阶段（0~5）。
# 返回值：{"handled": bool, "previous_was_on_floor": bool}
static func handle_pre_input_pipeline(player: Node, fixed_delta: float) -> Dictionary:
	player.is_game_paused = player._check_game_pause_state()
	var previous_was_on_floor: bool = player.was_on_floor

	# DIE 状态独占处理。
	if player.current_state == player.PlayerState.DIE:
		PlayerRuntimeTickService.tick_hurt_visual(player, fixed_delta)
		player.handle_die_state(fixed_delta)
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
	var move_input: float = Input.get_axis("left", "right")
	var jump_just_pressed: bool = Input.is_action_just_pressed("jump")
	var jump_pressed: bool = Input.is_action_pressed("jump")
	var jump_just_released: bool = Input.is_action_just_released("jump")
	var dash_just_pressed: bool = Input.is_action_just_pressed("dash")
	player.is_pressing_up = Input.is_action_pressed("up")
	player.is_pressing_down = Input.is_action_pressed("down")
	return {
		"move_input": move_input,
		"jump_just_pressed": jump_just_pressed,
		"jump_pressed": jump_pressed,
		"jump_just_released": jump_just_released,
		"dash_just_pressed": dash_just_pressed
	}

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

	player.update_coyote_time()
	player.update_animation()
	player.handle_afterimages(fixed_delta)
	player.handle_jump2_rotation(fixed_delta)

	if move_input != 0 and player.current_state != player.PlayerState.DIE and player.current_state != player.PlayerState.HURT:
		if player.current_state == player.PlayerState.SUPERDASHSTART or player.current_state == player.PlayerState.SUPERDASH:
			pass
		else:
			player.is_facing_right = move_input > 0
			player.animated_sprite.flip_h = not player.is_facing_right
