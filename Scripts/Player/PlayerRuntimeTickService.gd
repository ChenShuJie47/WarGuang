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

## 更新离墙后的墙跳意图缓冲。
static func tick_wall_jump_escape_buffer(player: Node, fixed_delta: float) -> void:
	if player.wall_jump_escape_buffer_timer <= 0.0:
		return
	if player.is_on_floor():
		player.wall_jump_escape_buffer_timer = 0.0
		player.wall_grip_direction = 0
		return
	player.wall_jump_escape_buffer_timer = maxf(player.wall_jump_escape_buffer_timer - fixed_delta, 0.0)

# 更新攀墙起跳后的地面抑制计时器。
## 已移除：攀墙起跳后贴地抑制计时器逻辑，不再需要计时器更新
