extends RefCounted
class_name PlayerDieStateService

# 处理 DIE 状态：死亡流程触发、减速、淡化与灯光衰减。
static func handle_die_state(player: Node, fixed_delta: float) -> void:
	if not player.is_in_death_process:
		player.start_death_process()

	if player.player_ui and player.player_ui.get_health() <= 1 and not player.is_low_health_effect_active and not player.is_hurt_visual_active:
		player._trigger_low_health_effect()

	player.velocity.y += player.gravity * player.effective_gravity_multiplier * fixed_delta
	player.velocity.y = min(player.velocity.y, player.effective_max_fall_speed)

	if abs(player.velocity.x) > 0.0:
		player.velocity.x = move_toward(
			player.velocity.x,
			0.0,
			player.dash_inertia_decay * player.base_move_speed * fixed_delta * player.effective_acceleration_multiplier
		)

	player.die_timer -= fixed_delta

	if player.animated_sprite.animation != "DIE":
		player.animated_sprite.play("DIE")

	if player.die_timer > 0.0:
		var progress: float = player.die_timer / player.die_animation_time
		player.animated_sprite.modulate.a = 0.5 * progress
		if player.point_light:
			player.point_light.energy = 1.0 * progress
		return

	player.animated_sprite.modulate.a = 0.0
	if player.point_light:
		player.point_light.energy = 0.0
