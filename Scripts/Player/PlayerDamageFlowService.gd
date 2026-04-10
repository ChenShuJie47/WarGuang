extends RefCounted
class_name PlayerDamageFlowService

# 受伤入口过滤：死亡、冲刺无敌、常规无敌均直接忽略。
static func should_ignore_damage(player: Node) -> bool:
	if player.current_state == player.PlayerState.DIE:
		return true
	if player.current_state == player.PlayerState.DASH and player.black_dash_unlocked:
		return true
	if player.is_invincible:
		return true
	return false

# 冲刺中受伤时先强制落地到 HURT，避免状态冲突。
static func break_dash_for_damage(player: Node) -> void:
	if player.current_state != player.PlayerState.DASH:
		return
	player.dash_duration_timer = 0
	player.dash_duration_timer_node.stop()
	player.can_dash = true
	player.was_gliding_before_dash = false
	player.change_state(player.PlayerState.HURT)

# 特殊状态受伤前先回到 IDLE，并把相机偏移复位。
static func normalize_special_state_before_damage(player: Node) -> void:
	if player.current_state == player.PlayerState.SLEEP or player.current_state == player.PlayerState.LOOKUP or player.current_state == player.PlayerState.LOOKDOWN:
		player.reset_camera_position()
		player.change_state(player.PlayerState.IDLE)

# 计算受伤击退方向，外部传入击退优先于按伤害源方向推导。
static func compute_hurt_direction(player: Node, damage_source_position: Vector2, knockback_force: Vector2) -> Vector2:
	if knockback_force != Vector2.ZERO:
		return knockback_force.normalized()
	var direction: Vector2 = (player.global_position - damage_source_position).normalized()
	direction.y = -0.5
	return direction

# 执行扣血并派发反馈事件，返回新的血量。
static func apply_damage_and_emit(player: Node, damage: int, damage_type: int, knockback_force: Vector2, damage_source_position: Vector2) -> int:
	player.is_about_to_be_hurt = true
	player.player_ui.take_damage(damage)
	var new_health: int = player.player_ui.get_health()
	player.trigger_feedback_event(&"damage_taken", {
		"damage": damage,
		"damage_type": damage_type,
		"new_health": new_health,
		"knockback_force": knockback_force,
		"source_position": damage_source_position
	})
	return new_health
