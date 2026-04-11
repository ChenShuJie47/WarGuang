extends RefCounted
class_name PlayerAnimationService

# 统一玩家动画更新入口。
static func update_animation(player: Node) -> void:
	if player.is_in_death_process:
		if player.current_animation != "DIE":
			player.current_animation = "DIE"
			player.animated_sprite.play("DIE")
		return

	if player.current_animation != "JUMP2" and player.is_jumpbox_triggered:
		player.clear_jumpbox_effect()

	var target_animation_val: String = ""
	match player.current_state:
		player.PlayerState.IDLE:
			target_animation_val = "IDLE"
		player.PlayerState.MOVE:
			target_animation_val = "MOVE"
		player.PlayerState.RUN:
			target_animation_val = "RUN"
		player.PlayerState.JUMP:
			if player.has_double_jumped:
				if player.is_jumpbox_triggered or player.is_double_jump_holding:
					target_animation_val = "JUMP2"
				else:
					target_animation_val = "JUMP1"
			else:
				target_animation_val = "JUMP1"
		player.PlayerState.DOWN:
			if player.has_double_jumped:
				if player.is_jumpbox_triggered or player.is_double_jump_holding:
					target_animation_val = "JUMP2"
				else:
					target_animation_val = "DOWN"
			else:
				target_animation_val = "DOWN"
		player.PlayerState.DASH:
			if player.black_dash_unlocked:
				target_animation_val = "BLACKDASH"
			else:
				target_animation_val = "DASH"
		player.PlayerState.GLIDE:
			target_animation_val = "GLIDE"
		player.PlayerState.HURT:
			if player.warp_flight_active:
				target_animation_val = "JUMP2"
			else:
				target_animation_val = "HURT"
		player.PlayerState.DIE:
			target_animation_val = "DIE"
		player.PlayerState.SLEEP:
			target_animation_val = "SLEEP"
		player.PlayerState.LOOKUP:
			target_animation_val = "LOOKUP"
		player.PlayerState.LOOKDOWN:
			target_animation_val = "LOOKDOWN"
		player.PlayerState.INTERACTIVE:
			target_animation_val = "INTERACTIVE"
		player.PlayerState.WALLGRIP:
			target_animation_val = "WALLGRIP"
		player.PlayerState.WALLJUMP:
			target_animation_val = "WALLJUMP"
		player.PlayerState.SUPERDASHSTART:
			target_animation_val = "SUPERDASHSTART"
		player.PlayerState.SUPERDASH:
			target_animation_val = "SUPERDASH"

	if target_animation_val != player.current_animation and target_animation_val != "":
		if player.current_animation == "JUMP2" and player.is_jumpbox_triggered:
			player.clear_jumpbox_effect()
		player.current_animation = target_animation_val
		player.animated_sprite.play(target_animation_val)

	if player.is_invincible and player.current_state != player.PlayerState.HURT and player.current_state != player.PlayerState.DIE and not player.is_respawn_invincible:
		player.animated_sprite.modulate.a = 0.5
	elif player.current_state != player.PlayerState.HURT and player.current_state != player.PlayerState.DIE:
		player.animated_sprite.modulate.a = 1.0
