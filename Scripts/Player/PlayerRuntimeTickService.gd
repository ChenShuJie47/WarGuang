extends RefCounted
class_name PlayerRuntimeTickService

# 更新受伤视觉计时器。
static func tick_hurt_visual(player: Node, fixed_delta: float) -> void:
	if not player.is_hurt_visual_active:
		return
	player.hurt_visual_timer -= fixed_delta
	if player.hurt_visual_timer <= 0.0:
		player.is_hurt_visual_active = false

# 更新无敌计时器与透明度恢复。
static func tick_invincible(player: Node, fixed_delta: float) -> void:
	if not player.is_invincible:
		return
	player.invincible_timer -= fixed_delta
	if player.invincible_timer <= 0.0:
		player.is_invincible = false
		player.animated_sprite.modulate.a = 1.0
