extends RefCounted
class_name PlayerFeedbackService

static func handle_afterimages(player: Node, fixed_delta: float) -> void:
	var current_fps = Engine.get_frames_per_second()
	if current_fps < 45:
		player.afterimage_spawn_rate = lerp(player.afterimage_spawn_rate, 2.0, fixed_delta * 2.0)
	elif current_fps > 55:
		player.afterimage_spawn_rate = lerp(player.afterimage_spawn_rate, 0.8, fixed_delta * 2.0)

	player.afterimage_spawn_rate = clamp(player.afterimage_spawn_rate, 0.5, 2.0)

	match player.current_state:
		player.PlayerState.DASH:
			player.afterimage_timer += fixed_delta
			var dash_type = "black_dash" if player.black_dash_unlocked else "dash"
			var dash_interval = player._get_afterimage_interval(dash_type) * player.afterimage_spawn_rate
			if player.afterimage_timer >= dash_interval:
				player.afterimage_timer = 0.0
				if player.black_dash_unlocked:
					player.create_afterimage(player.PlayerState.DASH, false, "black_dash")
				else:
					player.create_afterimage(player.PlayerState.DASH, false)
		player.PlayerState.SUPERDASH:
			player.super_dash_afterimage_timer += fixed_delta
			var super_dash_interval = player._get_afterimage_interval("super_dash") * player.afterimage_spawn_rate
			if player.super_dash_afterimage_timer >= super_dash_interval:
				player.super_dash_afterimage_timer = 0.0
				player.create_afterimage(player.PlayerState.SUPERDASH, false)
		_:
			player.afterimage_timer = 0.0

	if player.has_jumpbox_afterimage and player.current_animation == "JUMP2":
		player.jump2_afterimage_timer += fixed_delta
		var jumpbox_interval = player._get_afterimage_interval(player.jumpbox_afterimage_type) * player.afterimage_spawn_rate
		if player.jump2_afterimage_timer >= jumpbox_interval:
			player.jump2_afterimage_timer = 0.0
			player.create_afterimage(player.PlayerState.JUMP, true, player.jumpbox_afterimage_type)
	elif player.has_jumpbox_afterimage and player.current_animation != "JUMP2":
		player.has_jumpbox_afterimage = false
		player.jump2_afterimage_timer = 0.0
		player.clear_jumpbox_afterimage_pool()
