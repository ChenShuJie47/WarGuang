extends RefCounted
class_name PlayerAirStateService

# 进入一段跳时重置空中能力与状态标记。
static func apply_first_jump_state(player: Node) -> void:
	player.is_jumping = true
	player.jump_count = 1
	player.has_double_jumped = false
	player.can_double_jump = true
	player.can_glide = false
	player.is_double_jump_holding = false
	player.was_gliding_before_dash = false

# 进入二段跳时启用滑翔能力并锁定二段跳标记。
static func apply_double_jump_state(player: Node, compensation_used: bool) -> void:
	player.jump_count = 2
	player.has_double_jumped = true
	player.can_double_jump = false
	player.can_glide = true
	player.is_double_jump_holding = true
	if compensation_used:
		player.compensation_jump_used = true

# 墙跳准备态复用一段跳的基础空气标记。
static func apply_wall_jump_ready_state(player: Node) -> void:
	player.is_jumping = true
	player.jump_count = 1
	player.has_double_jumped = false
	player.can_double_jump = true
	player.is_double_jump_holding = Input.is_action_pressed("jump")

# 落地时清理空中能力、JumpBox 状态和滑翔状态。
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

# 传送重置时清空所有空气相关能力状态。
static func apply_warp_reset_air_state(player: Node) -> void:
	player.is_jumping = false
	player.jump_count = 0
	player.has_double_jumped = false
	player.can_double_jump = false
	player.is_gliding = false
	player.can_glide = false
	player.is_double_jump_holding = false
	player.was_gliding_before_dash = false
