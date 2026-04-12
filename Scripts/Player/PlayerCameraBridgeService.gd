extends RefCounted
class_name PlayerCameraBridgeService

const OBSERVE_RESTORE_SETTLE_MAX_TIME: float = 0.24
const OBSERVE_RESTORE_SETTLE_EPSILON: float = 1.0

# 相机桥接门面：收敛 Player 对 PlayerCameraController 的透传调用。
static func reset_camera_position(player: Node) -> void:
	_set_observe_target(player, Vector2.ZERO)

# 应用向上观察偏移：使用 Tween 的过渡曲线族 + 缓动方向组合。
static func apply_lookup_observe_offset(player: Node) -> void:
	_set_observe_target(player, Vector2(0, -player.lookup_camera_offset))

# 应用向下观察偏移：使用 Tween 的过渡曲线族 + 缓动方向组合。
static func apply_lookdown_observe_offset(player: Node) -> void:
	_set_observe_target(player, Vector2(0, player.lookdown_camera_offset))

static func tick_observe_offset(player: Node, fixed_delta: float) -> void:
	if not player.phantom_camera:
		return
	if fixed_delta <= 0.0:
		return
	if _tick_restore_settle_phase(player, fixed_delta):
		return
	_ensure_observe_dead_zone_mode(player)
	var target_offset: Vector2 = player.camera_observe_target_offset
	var total_distance: float = maxf(player.camera_observe_profile_distance, 0.0)
	if total_distance <= 0.01:
		_set_follow_offset(player.phantom_camera, target_offset)
		player.camera_observe_current_speed = 0.0
		if player.camera_observe_reset_phase and not player.camera_observe_zero_finalize_done:
			_finalize_observe_reset(player)
			player.camera_observe_zero_finalize_done = true
		return

	player.camera_observe_profile_elapsed += fixed_delta
	var elapsed: float = player.camera_observe_profile_elapsed
	var accel_time: float = maxf(player.camera_observe_profile_accel_time, 0.0001)
	var acceleration: float = maxf(player.camera_observe_profile_acceleration, 0.0)
	var max_speed: float = maxf(player.camera_observe_profile_max_speed, 1.0)
	var displacement: float = _compute_profile_displacement(elapsed, total_distance, accel_time, max_speed, acceleration)

	if elapsed < accel_time:
		player.camera_observe_current_speed = minf(max_speed, acceleration * elapsed)
	else:
		player.camera_observe_current_speed = max_speed

	var profile_offset: Vector2 = player.camera_observe_profile_start_offset + player.camera_observe_profile_direction * displacement
	_set_follow_offset(player.phantom_camera, profile_offset)

	if displacement >= total_distance - 0.01:
		_set_follow_offset(player.phantom_camera, target_offset)
		player.camera_observe_current_speed = 0.0
		if player.camera_observe_reset_phase and not player.camera_observe_zero_finalize_done:
			_finalize_observe_reset(player)
			player.camera_observe_zero_finalize_done = true

static func _set_observe_target(player: Node, target_offset: Vector2) -> void:
	if not player.phantom_camera:
		return
	var previous_target: Vector2 = player.camera_observe_target_offset
	if previous_target.is_zero_approx() and not target_offset.is_zero_approx():
		_capture_observe_baseline(player)
		player.camera_observe_restore_wait_dead_zone = false
		player.camera_observe_restore_wait_timer = 0.0

	var effective_target: Vector2 = _resolve_effective_observe_target(player, target_offset)
	if previous_target.is_equal_approx(effective_target):
		return

	player.camera_observe_target_offset = effective_target
	player.camera_observe_reset_phase = target_offset.is_zero_approx()
	player.camera_observe_profile_elapsed = 0.0
	player.camera_observe_current_speed = 0.0
	player.camera_observe_zero_finalize_done = false
	if not target_offset.is_zero_approx():
		# 观察以进入时基准 follow_offset 为起点，保证回零可回到观察前镜头位置。
		player.camera_observe_profile_start_offset = player.camera_observe_baseline_offset if player.camera_observe_baseline_valid else _get_follow_offset(player.phantom_camera)
		_set_follow_offset(player.phantom_camera, player.camera_observe_profile_start_offset)
	else:
		player.camera_observe_profile_start_offset = _get_follow_offset(player.phantom_camera)

	var start_offset: Vector2 = player.camera_observe_profile_start_offset
	var delta_vec: Vector2 = effective_target - start_offset
	var distance: float = delta_vec.length()
	player.camera_observe_profile_distance = distance
	player.camera_observe_profile_direction = delta_vec.normalized() if distance > 0.0001 else Vector2.ZERO
	if distance <= 0.01:
		player.camera_observe_profile_max_speed = 0.0
		player.camera_observe_profile_acceleration = 0.0
		player.camera_observe_profile_accel_time = 0.0
		_set_follow_offset(player.phantom_camera, effective_target)
		if player.camera_observe_reset_phase and not player.camera_observe_zero_finalize_done:
			_finalize_observe_reset(player)
			player.camera_observe_zero_finalize_done = true
		return

	var total_time: float = maxf(player.camera_offset_transition_duration, 0.001)
	var accel_ratio: float = clampf(player.camera_offset_accel_ratio, 0.05, 0.95)
	var accel_time: float = maxf(total_time * accel_ratio, 0.001)
	var max_speed: float = distance / maxf(total_time - accel_time * 0.5, 0.001)
	var acceleration: float = max_speed / accel_time

	player.camera_observe_profile_max_speed = max_speed
	player.camera_observe_profile_acceleration = acceleration
	player.camera_observe_profile_accel_time = accel_time
	if player.camera_observe_reset_phase and not previous_target.is_zero_approx():
		# 回零段立即进入匀速段，避免在边界释放按键时出现明显滞后感。
		player.camera_observe_profile_elapsed = accel_time
		player.camera_observe_current_speed = maxf(max_speed, 120.0)

static func _resolve_effective_observe_target(player: Node, requested_offset: Vector2) -> Vector2:
	if requested_offset.is_zero_approx():
		if player.camera_observe_baseline_valid:
			return player.camera_observe_baseline_offset
		return Vector2.ZERO
	var baseline: Vector2 = player.camera_observe_baseline_offset if player.camera_observe_baseline_valid else _get_follow_offset(player.phantom_camera)
	return baseline + requested_offset

static func _compute_profile_displacement(elapsed: float, distance: float, accel_time: float, max_speed: float, acceleration: float) -> float:
	if distance <= 0.0:
		return 0.0
	if elapsed <= 0.0:
		return 0.0
	if elapsed <= accel_time:
		return minf(distance, 0.5 * acceleration * elapsed * elapsed)
	var accel_distance: float = 0.5 * acceleration * accel_time * accel_time
	var cruise_time: float = elapsed - accel_time
	return minf(distance, accel_distance + max_speed * cruise_time)

static func clear_observe_offset_runtime(player: Node) -> void:
	if not player:
		return
	player.camera_observe_target_offset = Vector2.ZERO
	player.camera_observe_current_speed = 0.0
	player.camera_observe_profile_max_speed = 0.0
	player.camera_observe_profile_acceleration = 0.0
	player.camera_observe_profile_accel_time = 0.0
	player.camera_observe_profile_elapsed = 0.0
	player.camera_observe_profile_start_offset = Vector2.ZERO
	player.camera_observe_profile_distance = 0.0
	player.camera_observe_profile_direction = Vector2.ZERO
	player.camera_observe_zero_finalize_done = true
	player.camera_observe_reset_phase = false
	player.camera_observe_baseline_offset = Vector2.ZERO
	player.camera_observe_baseline_valid = false
	player.camera_observe_baseline_center = Vector2.ZERO
	player.camera_observe_baseline_center_valid = false
	player.camera_observe_restore_wait_dead_zone = false
	player.camera_observe_restore_wait_timer = 0.0
	_restore_observe_dead_zone(player)

static func _ensure_observe_dead_zone_mode(player: Node) -> void:
	if not player.phantom_camera:
		return
	if player.camera_observe_target_offset.is_zero_approx():
		return
	if player.camera_observe_dead_zone_active:
		return
	if player.camera_controller and (
		player.camera_controller.warp_camera_catchup_active
		or player.camera_controller.warp_camera_waiting_for_player_teleport
		or player.camera_controller.door_camera_catchup_active
	):
		return
	player.camera_observe_dead_zone_backup = Vector2(player.phantom_camera.dead_zone_width, player.phantom_camera.dead_zone_height)
	player.camera_observe_dead_zone_active = true
	# 观察偏移只作用于纵向，保留水平 dead zone，避免水平镜头回位漂移。
	player.phantom_camera.dead_zone_width = player.camera_observe_dead_zone_backup.x
	player.phantom_camera.dead_zone_height = 0.0

static func _restore_observe_dead_zone(player: Node) -> void:
	if not player.phantom_camera:
		return
	if not player.camera_observe_dead_zone_active:
		return
	player.phantom_camera.dead_zone_width = player.camera_observe_dead_zone_backup.x
	player.phantom_camera.dead_zone_height = player.camera_observe_dead_zone_backup.y
	player.camera_observe_dead_zone_active = false

static func _finalize_observe_reset(player: Node) -> void:
	player.camera_observe_reset_phase = false
	player.camera_observe_baseline_valid = false
	player.camera_observe_baseline_offset = Vector2.ZERO
	if player.camera_observe_baseline_center_valid:
		player.camera_observe_restore_wait_dead_zone = true
		player.camera_observe_restore_wait_timer = 0.0
		return
	_restore_observe_dead_zone(player)

static func _capture_observe_baseline(player: Node) -> void:
	if not player:
		return
	player.camera_observe_baseline_offset = _get_follow_offset(player.phantom_camera)
	player.camera_observe_baseline_valid = true
	var center: Vector2 = _get_camera_center(player)
	if center.is_finite():
		player.camera_observe_baseline_center = center
		player.camera_observe_baseline_center_valid = true
	else:
		player.camera_observe_baseline_center = Vector2.ZERO
		player.camera_observe_baseline_center_valid = false

static func _tick_restore_settle_phase(player: Node, fixed_delta: float) -> bool:
	if not player.camera_observe_restore_wait_dead_zone:
		return false
	player.camera_observe_restore_wait_timer += fixed_delta
	var center: Vector2 = _get_camera_center(player)
	var settled: bool = center.is_finite() and player.camera_observe_baseline_center_valid and center.distance_to(player.camera_observe_baseline_center) <= OBSERVE_RESTORE_SETTLE_EPSILON
	var timeout: bool = player.camera_observe_restore_wait_timer >= OBSERVE_RESTORE_SETTLE_MAX_TIME
	if settled or timeout:
		player.camera_observe_restore_wait_dead_zone = false
		player.camera_observe_restore_wait_timer = 0.0
		player.camera_observe_baseline_center_valid = false
		player.camera_observe_baseline_center = Vector2.ZERO
		_restore_observe_dead_zone(player)
		return false
	# 等待阶段保持当前 follow_offset，不做新的观察轨迹推进。
	return true

static func _get_camera_center(player: Node) -> Vector2:
	if not player:
		return Vector2.ZERO
	if player.get_viewport():
		var camera: Camera2D = player.get_viewport().get_camera_2d()
		if camera and camera.global_position.is_finite():
			return camera.global_position
	if player.phantom_camera and player.phantom_camera.global_position.is_finite():
		return player.phantom_camera.global_position
	return Vector2.ZERO

static func _get_follow_offset(phantom_camera: Node) -> Vector2:
	if phantom_camera and phantom_camera.has_method("get_follow_offset"):
		var value = phantom_camera.get_follow_offset()
		if value is Vector2:
			return value
	if phantom_camera:
		return phantom_camera.follow_offset
	return Vector2.ZERO

static func _set_follow_offset(phantom_camera: Node, value: Vector2) -> void:
	if not phantom_camera:
		return
	if phantom_camera.has_method("set_follow_offset"):
		phantom_camera.set_follow_offset(value)
	else:
		phantom_camera.follow_offset = value

static func start_camera_transition_guard(player: Node, duration: float = 0.18, max_duration: float = 1.0) -> void:
	if player.camera_controller and player.camera_controller.has_method("start_camera_transition_guard"):
		player.camera_controller.start_camera_transition_guard(duration, max_duration)

static func update_camera_transition_guard(player: Node, fixed_delta: float) -> void:
	if player.camera_controller and player.camera_controller.has_method("physics_process"):
		player.camera_controller.physics_process(fixed_delta)

static func sync_camera_after_room_teleport(player: Node) -> void:
	if player.camera_controller and player.camera_controller.has_method("sync_camera_after_room_teleport"):
		player.camera_controller.sync_camera_after_room_teleport()

static func sync_camera_to_player_center(player: Node, immediate: bool = false) -> void:
	if not player.camera_controller:
		return
	if immediate and player.camera_controller.has_method("sync_camera_to_player_center_immediate"):
		player.camera_controller.sync_camera_to_player_center_immediate()
		return
	if player.camera_controller.has_method("sync_camera_to_player_center"):
		player.camera_controller.sync_camera_to_player_center()

static func sync_phantom_camera_after_teleport(player: Node) -> void:
	sync_camera_after_room_teleport(player)

static func force_sync_camera_position_after_teleport(player: Node) -> void:
	if player.camera_controller and player.camera_controller.has_method("force_sync_camera_position_after_teleport"):
		await player.camera_controller.force_sync_camera_position_after_teleport()

static func start_door_camera_catchup_after_teleport(player: Node, catchup_duration: float = 0.20, unlock_duration: float = 0.32) -> void:
	if player.camera_controller and player.camera_controller.has_method("start_door_teleport_camera_catchup"):
		player.camera_controller.start_door_teleport_camera_catchup(catchup_duration, unlock_duration)
