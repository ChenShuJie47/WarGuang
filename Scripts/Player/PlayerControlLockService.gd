extends RefCounted
class_name PlayerControlLockService

# 每帧更新控制锁定计时；Door 自动走位激活时不在此处倒计时。
static func tick_lock_timer(player: Node, fixed_delta: float) -> void:
	if not player.is_control_locked:
		return
	if player.door_autowalk_active:
		return
	player.control_lock_timer -= fixed_delta
	if player.control_lock_timer <= 0.0:
		unlock_control(player)

# 处理锁定状态下的物理分支。返回 true 表示已处理本帧锁定逻辑。
static func handle_locked_physics(player: Node, fixed_delta: float) -> bool:
	if not player.is_control_locked:
		return false
	if player.door_autowalk_active:
		PlayerDoorTraversalService.update_autowalk(player, fixed_delta)
	else:
		player.apply_gravity(fixed_delta)
		PlayerPixelStabilityService.apply_test_velocity_snap(player, 0.0, true)
		player.move_and_slide()
	player.update_animation()
	return true

# 锁定输入控制。
static func lock_control(player: Node, duration: float, lock_type: String = "general") -> void:
	player.is_control_locked = true
	player.control_lock_timer = duration
	player.set_process_input(false)
	print("玩家控制锁定: 类型=", lock_type, " 持续时间=", duration, "秒")

# 解除输入控制。
static func unlock_control(player: Node) -> void:
	player.is_control_locked = false
	player.control_lock_timer = 0.0
	player.set_process_input(true)
