extends RefCounted
class_name PlayerAbilityService

static func can_be_interrupted(player: Node) -> bool:
	return player.current_state != player.PlayerState.DASH and player.current_state != player.PlayerState.HURT and player.current_state != player.PlayerState.DIE

static func get_ability_status(player: Node) -> Dictionary:
	return {
		"dash": player.dash_unlocked,
		"double_jump": player.double_jump_unlocked,
		"glide": player.glide_unlocked,
		"black_dash": player.black_dash_unlocked,
		"wall_grip": player.wall_grip_unlocked
	}

static func set_abilities_from_save(player: Node, abilities: Dictionary) -> void:
	player.dash_unlocked = abilities.get("dash", false)
	player.double_jump_unlocked = abilities.get("double_jump", false)
	player.glide_unlocked = abilities.get("glide", false)
	player.black_dash_unlocked = abilities.get("black_dash", false)
	player.wall_grip_unlocked = abilities.get("wall_grip", false)

static func enter_sleep_state(player: Node) -> void:
	player.velocity = Vector2.ZERO
	player.change_state(player.PlayerState.SLEEP)

static func exit_sleep_state(player: Node) -> void:
	if player.current_state == player.PlayerState.SLEEP:
		player.change_state(player.PlayerState.IDLE)

static func is_sleeping(player: Node) -> bool:
	return player.current_state == player.PlayerState.SLEEP

static func set_player_control(player: Node, enabled: bool) -> void:
	player.set_process_input(enabled)

static func teleport_to(player: Node, target_position: Vector2) -> void:
	player.global_position = target_position
	player.velocity = Vector2.ZERO

static func refresh_air_dash(player: Node) -> void:
	player.has_dashed_in_air = false

static func refresh_jump(player: Node) -> void:
	player.jump_count = 0

static func refresh_dash(player: Node) -> void:
	player.can_dash = true
	player.has_dashed_in_air = false

static func update_effective_multipliers(player: Node) -> void:
	player.effective_horizontal_multiplier = player.env_horizontal_multiplier
	player.effective_vertical_multiplier = player.env_vertical_multiplier
	player.effective_gravity_multiplier = player.env_gravity_multiplier
	player.effective_max_fall_multiplier = player.env_max_fall_multiplier
	player.effective_acceleration_multiplier = player.env_acceleration_multiplier
	player.effective_max_fall_speed = player.max_fall_speed * player.effective_max_fall_multiplier

static func set_environment_multipliers(player: Node, horizontal: float, vertical: float, p_gravity: float, max_fall: float, acceleration: float) -> void:
	player.env_horizontal_multiplier = horizontal
	player.env_vertical_multiplier = vertical
	player.env_gravity_multiplier = p_gravity
	player.env_max_fall_multiplier = max_fall
	player.env_acceleration_multiplier = acceleration