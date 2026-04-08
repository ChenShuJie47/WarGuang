extends RefCounted
class_name PlayerAirStateService

static func apply_first_jump_state(player: Node) -> void:
	player.is_jumping = true
	player.jump_count = 1
	player.has_double_jumped = false
	player.can_double_jump = true
	player.can_glide = false
	player.is_double_jump_holding = false
	player.was_gliding_before_dash = false

static func apply_double_jump_state(player: Node, compensation_used: bool) -> void:
	player.jump_count = 2
	player.has_double_jumped = true
	player.can_double_jump = false
	player.can_glide = true
	player.is_double_jump_holding = true
	if compensation_used:
		player.compensation_jump_used = true

static func apply_wall_jump_ready_state(player: Node) -> void:
	player.is_jumping = true
	player.jump_count = 1
	player.has_double_jumped = false
	player.can_double_jump = true
	player.is_double_jump_holding = Input.is_action_pressed("jump")

static func apply_landing_state(player: Node) -> void:
	player.is_jumping = false
	player.jump_count = 0
	player.is_gliding = false
	player.has_double_jumped = false
	player.can_double_jump = false
	player.is_double_jump_holding = false
	player.jumpbox_force_applied = false
	player.is_jumpbox_continuous_jump = false
	player.is_jump_interrupt_decaying = false
	player.can_glide = false
	player.was_gliding_before_dash = false

static func apply_warp_reset_air_state(player: Node) -> void:
	player.is_jumping = false
	player.jump_count = 0
	player.has_double_jumped = false
	player.can_double_jump = false
	player.is_gliding = false
	player.can_glide = false
	player.is_double_jump_holding = false
	player.was_gliding_before_dash = false
