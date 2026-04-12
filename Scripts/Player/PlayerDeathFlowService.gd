extends RefCounted
class_name PlayerDeathFlowService

# 外部死亡触发入口。
static func on_player_died(player: Node) -> void:
	if player.current_state == player.PlayerState.DIE or player.is_in_death_process:
		return
	player.is_in_death_process = true
	player.lock_control(999)
	player._start_async_death_process()

# 异步死亡流程：Hit Stop -> 慢动作 -> 正式死亡流程。
static func start_async_death_process(player: Node) -> void:
	player._trigger_tier2_hit_stop_with_fallback(player.DEFAULT_HURT_HIT_STOP_DURATION, player.DEFAULT_HURT_HIT_STOP_INTENSITY)
	await player.get_tree().create_timer(0.2).timeout

	if not player.is_in_death_process:
		return

	player.change_state(player.PlayerState.DIE)
	TimerControlManager.slow_motion("medium")

	await player.get_tree().create_timer(player.slowly_die_time).timeout
	if not player.is_in_death_process:
		return

	await player.start_death_process()

# 正式死亡流程：淡出、传送、重置、淡入、恢复控制。
static func start_death_process(player: Node) -> void:
	if not player.is_in_death_process:
		return

	AudioManager.stop_bgm(1.0)
	await player.get_tree().create_timer(player.die_animation_time).timeout

	if player.is_low_health_effect_active:
		player._clear_low_health_effect()

	await FadeManager.fade_out(player.fade_transition_time / 2)
	player.global_position = Global.get_save_point_position()
	player.reset_player_for_respawn()
	# 黑屏期内先同步复活点房间与相机限制，再完成居中归位。
	await PlayerRoomTransitionService.sync_room_and_camera_for_respawn(player, "", true)
	# 额外等待一帧并再次居中，防止限制异步刷新覆盖首帧对齐。
	await player.get_tree().process_frame
	PlayerRoomTransitionService.sync_camera_to_player_center(player, true)
	await FadeManager.fade_in(player.fade_transition_time / 2)

	player.get_tree().create_timer(0.5).timeout.connect(func():
		if RoomManager.current_room != "":
			RoomManager.switch_room_bgm(RoomManager.current_room)
	)

	player.lock_control(player.respawn_invincible_time)
	await player.get_tree().create_timer(player.respawn_invincible_time).timeout
	player.set_process_input(true)
	if player.current_state == player.PlayerState.SLEEP:
		player.change_state(player.PlayerState.IDLE)
	player.is_in_death_process = false

# 重生重置流程。
static func reset_player_for_respawn(player: Node) -> void:
	Engine.time_scale = 1.0

	player.is_in_death_process = false
	player.is_dying = false
	player.die_timer = 0.0
	player.current_animation = ""
	player.velocity = Vector2.ZERO

	player.is_jumping = false
	player.jump_count = 0
	player.has_double_jumped = false
	player.can_double_jump = false
	player.is_gliding = false
	player.can_glide = false
	player.is_double_jump_holding = false
	player.was_gliding_before_dash = false
	player.has_dashed_in_air = false
	player.can_dash = true

	player.PlayerWarpResetServiceScript.reset_warp_runtime_state(player)
	player.is_about_to_be_hurt = false

	player.is_respawn_invincible = true
	player.is_invincible = true
	player.animated_sprite.modulate.a = 1.0
	if player.point_light:
		player.point_light.energy = 1.0

	if player.is_low_health_effect_active:
		player._clear_low_health_effect()

	player.change_state(player.PlayerState.SLEEP)
	if player.player_ui:
		player.player_ui.set_health(Global.player_max_health)

	player.get_tree().create_timer(player.respawn_invincible_time).timeout.connect(func():
		player.is_invincible = false
		player.is_respawn_invincible = false
		player.animated_sprite.modulate.a = 1.0
	)
