extends RefCounted
class_name PlayerStateTransitionService

# 处理状态退出时的副作用。
static func apply_exit_state(player: Node, from_state: int) -> void:
	match from_state:
		player.PlayerState.DASH:
			var dash_dir: int = player.dash_locked_direction
			if dash_dir == 0:
				dash_dir = 1 if player.is_facing_right else -1
			player.velocity.x = player.dash_inertia_speed * player.effective_horizontal_multiplier * dash_dir
			player.dash_locked_direction = dash_dir
			player.can_reattach_to_wall = true

		player.PlayerState.JUMP:
			if player.is_jump_interrupt_decaying:
				player.is_jump_interrupt_decaying = false
				player.jump_interrupt_decay_timer = 0.0

		player.PlayerState.WALLGRIP:
			player.hold_toward_wall_timer = 0.0
			player.no_input_timer = 0.0
			player.current_wall_slide_speed = 0.0

		player.PlayerState.WALLJUMP:
			player.can_reattach_to_wall = true

		player.PlayerState.LOOKUP, player.PlayerState.LOOKDOWN:
			player.reset_camera_position()

		player.PlayerState.SLEEP:
			player.sleep_timer = 0.0

# 处理状态进入时的副作用。
static func apply_enter_state(player: Node, to_state: int, from_state: int) -> void:
	match to_state:
		player.PlayerState.DOWN:
			player.down_state_entry_time = 0.0

		player.PlayerState.SLEEP:
			player.sleep_timer = 0.0

		player.PlayerState.DIE:
			# 若之前进入过传送伤害追镜，死亡时强制恢复到正常跟随与 dead zone。
			if player.camera_controller \
				and player.camera_controller.has_method("has_pending_warp_camera_hold") \
				and player.camera_controller.has_pending_warp_camera_hold() \
				and player.camera_controller.has_method("notify_warp_player_teleported"):
				player.camera_controller.notify_warp_player_teleported()
			if player.camera_controller and player.camera_controller.has_method("begin_death_camera_freeze"):
				player.camera_controller.begin_death_camera_freeze()
			player.die_timer = player.die_animation_time
			player.is_invincible = true
			player.animated_sprite.rotation_degrees = 0
			player.jump2_rotation = 0
			player.animated_sprite.modulate.a = 0.5

		player.PlayerState.HURT:
			player.is_invincible = true
			player.invincible_timer = player.hurt_invincible_time
			player.animated_sprite.rotation_degrees = 0
			player.jump2_rotation = 0
			player.animated_sprite.modulate.a = 0.5

		player.PlayerState.DASH:
			if player.dash_locked_direction == 0:
				player.dash_locked_direction = 1 if player.is_facing_right else -1
			if from_state == int(player.PlayerState.WALLJUMP):
				player.can_reattach_to_wall = false

		player.PlayerState.WALLGRIP:
			player.hold_toward_wall_timer = 0.0
			player.no_input_timer = 0.0
			player.current_wall_slide_speed = 0.0
			player.has_double_jumped = false
			player.can_double_jump = true
			player.has_dashed_in_air = false
			player.can_dash = true
			player.current_animation = "WALLGRIP"
			player.animated_sprite.play("WALLGRIP")

static func change_state(player: Node, new_state: int) -> void:
	if player.current_state == new_state:
		return
	apply_exit_state(player, int(player.current_state))
	if new_state == player.PlayerState.DIE:
		player.is_in_death_process = true
	var previous_state = player.current_state
	apply_enter_state(player, int(new_state), int(player.current_state))
	player.current_state = new_state
	player.trigger_feedback_event(&"state_changed", {
		"from": previous_state,
		"to": new_state
	})
