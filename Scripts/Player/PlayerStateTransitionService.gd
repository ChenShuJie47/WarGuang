extends RefCounted
class_name PlayerStateTransitionService

# 处理状态退出时的副作用。
static func apply_exit_state(player: Node, from_state: int) -> void:
	match from_state:
		player.PlayerState.DASH:
			if player.is_facing_right:
				player.velocity.x = player.dash_inertia_speed * player.effective_horizontal_multiplier
			else:
				player.velocity.x = -player.dash_inertia_speed * player.effective_horizontal_multiplier
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
