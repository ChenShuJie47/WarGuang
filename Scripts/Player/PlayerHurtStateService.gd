extends RefCounted
class_name PlayerHurtStateService

# 处理 HURT 状态：含普通受伤僵直与传送伤害飞行入口。
static func handle_hurt_state(player: Node, fixed_delta: float) -> void:
	if player.warp_flight_active:
		if player.current_animation != "JUMP2":
			player.current_animation = "JUMP2"
			player.animated_sprite.play("JUMP2")
		player.PlayerWarpFlightServiceScript.update_flight(player, fixed_delta)
		return

	player.animated_sprite.modulate.a = 0.5

	player.velocity.y += player.gravity * player.effective_gravity_multiplier * fixed_delta
	player.velocity.y = min(player.velocity.y, player.effective_max_fall_speed)

	player.velocity.x = move_toward(
		player.velocity.x,
		0.0,
		player.dash_inertia_decay * player.base_move_speed * fixed_delta * player.effective_acceleration_multiplier
	)

	if player.current_animation != "HURT":
		player.current_animation = "HURT"
		player.animated_sprite.play("HURT")

	player.hurt_timer -= fixed_delta
	if player.hurt_timer > 0.0:
		return

	if player.is_warp_damage and not player.is_in_death_process:
		player.PlayerWarpFlightServiceScript.begin_flight(player)
		return

	player.is_invincible = true
	player.invincible_timer = player.hurt_invincible_time
	if player.is_on_floor():
		player.change_state(player.PlayerState.IDLE)
	else:
		player.change_state(player.PlayerState.DOWN)
