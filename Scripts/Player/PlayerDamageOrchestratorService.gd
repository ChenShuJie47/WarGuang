extends RefCounted
class_name PlayerDamageOrchestratorService

const DAMAGE_NORMAL := 0
const DAMAGE_SHADOW := 1
const DAMAGE_WARP_NORMAL := 2
const DAMAGE_WARP_SHADOW := 3

# 兼容旧入口：int 类型伤害来源转换为枚举整型并复用主流程。
static func take_damage(player: Node, damage_source_position: Vector2, damage: int = 1, damage_type: int = 0, knockback_force: Vector2 = Vector2.ZERO) -> void:
	var mapped_damage_type: int = DAMAGE_NORMAL
	match damage_type:
		0:
			mapped_damage_type = DAMAGE_NORMAL
		1:
			mapped_damage_type = DAMAGE_SHADOW
		2:
			mapped_damage_type = DAMAGE_WARP_NORMAL
		3:
			mapped_damage_type = DAMAGE_WARP_SHADOW
	take_damage_with_type(player, damage_source_position, damage, mapped_damage_type, knockback_force)

# 主受伤编排入口。
static func take_damage_with_type(player: Node, damage_source_position: Vector2, damage: int = 1, damage_type: int = DAMAGE_NORMAL, knockback_force: Vector2 = Vector2.ZERO) -> void:
	if player.PlayerDamageFlowServiceScript.should_ignore_damage(player):
		return

	if player.camera_damage_debug:
		player._debug_camera_damage_state("before_damage", damage_source_position, damage, damage_type, knockback_force)

	player.PlayerDamageFlowServiceScript.break_dash_for_damage(player)
	player.PlayerDamageFlowServiceScript.normalize_special_state_before_damage(player)

	player.hurt_direction = player.PlayerDamageFlowServiceScript.compute_hurt_direction(player, damage_source_position, knockback_force)
	player.velocity = player.hurt_direction * player.hurt_knockback_speed

	var new_health: int = int(player.PlayerDamageFlowServiceScript.apply_damage_and_emit(
		player,
		damage,
		int(damage_type),
		knockback_force,
		damage_source_position
	))

	if new_health <= 0 and not player.is_in_death_process:
		player.is_in_death_process = true
		player.change_state(player.PlayerState.DIE)
		player.start_die_slow_motion()
		return

	player.PlayerDamageStateServiceScript.apply_nonlethal_damage_state(player, int(damage_type), new_health)
	player.change_state(player.PlayerState.HURT)
	player.PlayerDamageStateServiceScript.play_hurt_visual(player, int(damage_type))

	if new_health <= 0 and not player.is_in_death_process:
		player.is_in_death_process = true
	elif player.PlayerDamageStateServiceScript.should_start_warp_timer(int(damage_type)):
		player.PlayerWarpFlowServiceScript.begin_warp_damage_flow(player)

	if player.camera_damage_debug:
		player._debug_camera_damage_state("after_damage", damage_source_position, damage, damage_type, knockback_force)

# 传送后状态重置。
static func reset_after_warp(player: Node) -> void:
	player.velocity = Vector2.ZERO
	player.PlayerAirStateServiceScript.apply_warp_reset_air_state(player)
	player.has_dashed_in_air = false
	player.can_dash = true
	player.PlayerWarpResetServiceScript.reset_warp_runtime_state(player)
	player.is_run_jumping = false
	player.is_wall_bump_stun = false
	player.is_jump2_boost_active = false
