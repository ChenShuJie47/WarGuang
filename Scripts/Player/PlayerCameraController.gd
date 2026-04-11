class_name PlayerCameraController
extends Node

# 相机限制在传送后会临时放开到极大范围，避免被边界夹回。
const CAMERA_LIMIT_DISABLED: int = 10000000
# 调试开关，用于追踪传送或抖动后的相机同步问题。
const CAMERA_TELEPORT_DEBUG: bool = false
# 复用玩家相机数学工具，统一处理中心点与边界裁剪。
const PlayerCameraMathUtil = preload("res://Scripts/Player/PlayerCameraMath.gd")
const DEFAULT_WARP_CAMERA_HOLD_TIMEOUT: float = 6.0

# 当前绑定的玩家节点。
var player: Player = null
# 当前绑定的 PhantomCamera 节点。
var phantom_camera: Node = null
# 传送后相机轴锁的临时保持计时器。
var camera_transition_guard_timer: float = 0.0
# 标记是否正在等待相机过渡恢复。
var camera_transition_guard_active: bool = false
# 传送前的 dead zone 备份值，用于恢复普通跟随范围。
var camera_transition_dead_zone_backup: Vector2 = Vector2(0.125, 0.1)
# 传送守卫已经持续了多久。
var camera_transition_guard_elapsed: float = 0.0
# 相机守卫至少保持的最短时间。
var camera_transition_guard_min_duration: float = 0.12
# 记录传送前的轴锁状态，结束后恢复。
var camera_transition_axis_lock_backup: int = 0
# 标记是否已经完成依赖注入。
var setup_completed: bool = false
# 相机异常日志节流时间戳，避免一帧内刷屏。
var invalid_camera_debug_last_log_ms: int = -1000000
# 传送伤害临时追镜是否生效。
var warp_camera_catchup_active: bool = false
# 传送伤害追镜前 dead zone 备份。
var warp_camera_dead_zone_backup: Vector2 = Vector2.ZERO
var warp_camera_follow_target_backup: Node = null
var warp_camera_anchor: Node2D = null
var warp_camera_waiting_for_player_teleport: bool = false
var warp_camera_wait_timeout: float = 0.0
@export var warp_camera_hold_timeout: float = DEFAULT_WARP_CAMERA_HOLD_TIMEOUT
# Door 传送测试追镜是否生效。
var door_camera_catchup_active: bool = false
# Door 追镜前 dead zone 备份。
var door_camera_dead_zone_backup: Vector2 = Vector2.ZERO
# Door 追镜期间临时解限前的 Phantom 限制备份。
var door_limits_backup := {
	"left": -CAMERA_LIMIT_DISABLED,
	"top": -CAMERA_LIMIT_DISABLED,
	"right": CAMERA_LIMIT_DISABLED,
	"bottom": CAMERA_LIMIT_DISABLED
}

# 初始化相机控制器的绑定对象。
func setup(player_ref: Player) -> void:
	player = player_ref
	phantom_camera = player.get_node_or_null("PhantomCamera2D")
	if phantom_camera:
		if phantom_camera.follow_target == null:
			phantom_camera.follow_target = player
		camera_transition_dead_zone_backup = Vector2(phantom_camera.dead_zone_width, phantom_camera.dead_zone_height)
	setup_completed = true

# 每帧检查传送守卫是否应该结束。
func physics_process(fixed_delta: float) -> void:
	if not setup_completed:
		return
	if not is_instance_valid(player) or not is_instance_valid(phantom_camera):
		return
	if not player.is_inside_tree() or not phantom_camera.is_inside_tree():
		return
	_ensure_valid_follow_target()
	var camera := player.get_viewport().get_camera_2d()
	if (camera and (not camera.global_position.is_finite() or not camera.offset.is_finite())) or not phantom_camera.global_position.is_finite():
		_recover_from_invalid_camera_position()
	if warp_camera_waiting_for_player_teleport:
		warp_camera_wait_timeout -= fixed_delta
		if warp_camera_wait_timeout <= 0.0:
			_release_warp_camera_hold(true)
	_update_camera_transition_guard(fixed_delta)

# 将相机 follow_offset 平滑回零。
func reset_camera_position() -> void:
	if not player or not phantom_camera:
		return
	var tween = player.create_tween()
	tween.set_trans(player.camera_offset_transition_type)
	tween.set_ease(player.camera_offset_ease_type)
	tween.tween_property(phantom_camera, "follow_offset", Vector2.ZERO, player.camera_offset_transition_duration)

# 开启传送后的临时守卫，避免相机立刻回落到错误 dead zone。
func start_camera_transition_guard(duration: float = 0.18, max_duration: float = 1.0) -> void:
	if not phantom_camera:
		return
	camera_transition_axis_lock_backup = int(phantom_camera.follow_axis_lock)
	phantom_camera.follow_axis_lock = PhantomCamera2D.FollowLockAxis.XY
	camera_transition_guard_active = true
	camera_transition_guard_elapsed = 0.0
	camera_transition_guard_min_duration = maxf(duration, 0.01)
	camera_transition_guard_timer = maxf(max_duration, camera_transition_guard_min_duration)
	if CAMERA_TELEPORT_DEBUG:
		print("[CameraGuard] lock begin min=", camera_transition_guard_min_duration, " max=", camera_transition_guard_timer)

# 处理传送后相机轴锁恢复与回位时机。
func _update_camera_transition_guard(fixed_delta: float) -> void:
	if not camera_transition_guard_active:
		return
	camera_transition_guard_elapsed += fixed_delta
	camera_transition_guard_timer -= fixed_delta
	if camera_transition_guard_elapsed < camera_transition_guard_min_duration:
		return

	if camera_transition_guard_timer > 0.0 and not _is_player_inside_normal_camera_dead_zone():
		return
	camera_transition_guard_active = false
	if phantom_camera:
		phantom_camera.follow_axis_lock = camera_transition_axis_lock_backup
		_safe_teleport_phantom_camera()
	if CAMERA_TELEPORT_DEBUG:
		print("[CameraGuard] lock end elapsed=", camera_transition_guard_elapsed, " timeout_left=", camera_transition_guard_timer)

# 同步房间传送后的相机最终位置。
func sync_camera_after_room_teleport() -> void:
	if not setup_completed:
		return
	if not player or not phantom_camera:
		return
	if not player.is_inside_tree() or not phantom_camera.is_inside_tree():
		return
	if phantom_camera.follow_target == null:
		phantom_camera.follow_target = player

	var camera := player.get_viewport().get_camera_2d()
	if CameraShakeManager and CameraShakeManager.has_method("stop_shake"):
		CameraShakeManager.stop_shake(phantom_camera)
	if camera:
		camera.offset = Vector2.ZERO

	var desired_center: Vector2 = player.global_position + phantom_camera.follow_offset
	var clamped_center := _clamp_camera_center_by_limits(desired_center, phantom_camera, camera)
	if not clamped_center.is_finite():
		clamped_center = desired_center if desired_center.is_finite() else player.global_position

	phantom_camera.global_position = clamped_center
	_safe_teleport_phantom_camera()

	if camera:
		camera.global_position = clamped_center
		if camera.has_method("reset_smoothing"):
			camera.reset_smoothing()
		if camera.has_method("reset_physics_interpolation"):
			camera.reset_physics_interpolation()

	if CAMERA_TELEPORT_DEBUG:
		print("[CameraTeleportSync] desired=", desired_center, " clamped=", clamped_center)

	start_camera_transition_guard(0.10, 0.65)

# 在极端情况下强制把 Camera2D 放到目标位置。
func force_sync_camera_position_after_teleport() -> void:
	if not setup_completed:
		return
	if not player or not phantom_camera:
		return
	if not player.is_inside_tree() or not phantom_camera.is_inside_tree():
		return
	var camera = player.get_viewport().get_camera_2d()
	if not camera:
		return

	var desired_position = player.global_position + phantom_camera.follow_offset
	var original_left = camera.limit_left
	var original_top = camera.limit_top
	var original_right = camera.limit_right
	var original_bottom = camera.limit_bottom

	if CAMERA_TELEPORT_DEBUG:
		print("DEBUG: 传送后强制同步相机 - 玩家位置:", player.global_position, " 期望相机位置:", desired_position, " 限制:", original_left, ",", original_top, ",", original_right, ",", original_bottom)

	camera.limit_left = -CAMERA_LIMIT_DISABLED
	camera.limit_top = -CAMERA_LIMIT_DISABLED
	camera.limit_right = CAMERA_LIMIT_DISABLED
	camera.limit_bottom = CAMERA_LIMIT_DISABLED
	camera.global_position = desired_position
	await player.get_tree().process_frame
	camera.limit_left = original_left
	camera.limit_top = original_top
	camera.limit_right = original_right
	camera.limit_bottom = original_bottom

	if CAMERA_TELEPORT_DEBUG:
		print("DEBUG: 相机位置设置后:", camera.global_position)

# 传送伤害后使用快速追镜，而不是瞬移相机。
func start_warp_damage_camera_catchup(duration: float = 0.22) -> void:
	start_warp_damage_camera_catchup_to_position(player.global_position, duration)

func start_warp_damage_camera_catchup_to_position(target_position: Vector2, duration: float = 0.22) -> void:
	if not setup_completed:
		return
	if not is_instance_valid(player) or not is_instance_valid(phantom_camera):
		return
	if warp_camera_catchup_active:
		return
	var camera := player.get_viewport().get_camera_2d()
	if camera == null:
		return
	if not _ensure_warp_camera_anchor():
		return
	warp_camera_catchup_active = true
	warp_camera_waiting_for_player_teleport = false
	warp_camera_wait_timeout = 0.0
	warp_camera_follow_target_backup = phantom_camera.follow_target
	warp_camera_dead_zone_backup = Vector2(phantom_camera.dead_zone_width, phantom_camera.dead_zone_height)
	# 临时接管相机，使用有效锚点避免 PhantomCamera follow_target 为空。
	phantom_camera.follow_target = warp_camera_anchor
	phantom_camera.dead_zone_width = 0.02
	phantom_camera.dead_zone_height = 0.02
	var start_center: Vector2 = camera.global_position
	if not start_center.is_finite():
		start_center = phantom_camera.global_position if phantom_camera.global_position.is_finite() else player.global_position
	var end_center: Vector2 = target_position + phantom_camera.follow_offset
	if not end_center.is_finite():
		end_center = target_position if target_position.is_finite() else start_center
	warp_camera_anchor.global_position = start_center
	var tween := player.create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_method(Callable(self, "_set_warp_camera_center"), start_center, end_center, maxf(duration, 0.05))
	start_camera_transition_guard(0.06, maxf(duration + 0.25, 0.3))
	tween.finished.connect(func():
		if not is_instance_valid(phantom_camera):
			warp_camera_catchup_active = false
			warp_camera_waiting_for_player_teleport = false
			return
		phantom_camera.dead_zone_width = warp_camera_dead_zone_backup.x
		phantom_camera.dead_zone_height = warp_camera_dead_zone_backup.y
		# 追镜到目标后先保持在目标，不要在玩家真正传送前回弹到玩家当前位置。
		if is_instance_valid(warp_camera_anchor):
			phantom_camera.follow_target = warp_camera_anchor
		warp_camera_waiting_for_player_teleport = true
		warp_camera_wait_timeout = maxf(warp_camera_hold_timeout, 0.5)
		warp_camera_catchup_active = false
	)

# 玩家实际完成传送后调用，恢复正常跟随。
func notify_warp_player_teleported() -> void:
	_release_warp_camera_hold(true)

func _set_warp_camera_center(center: Vector2) -> void:
	if not is_instance_valid(player) or not is_instance_valid(phantom_camera):
		return
	if not center.is_finite():
		return
	if is_instance_valid(warp_camera_anchor):
		warp_camera_anchor.global_position = center
	phantom_camera.global_position = center
	var camera := player.get_viewport().get_camera_2d()
	if camera:
		camera.global_position = center

func is_warp_camera_catchup_active() -> bool:
	return warp_camera_catchup_active

func _safe_teleport_phantom_camera() -> void:
	if not is_instance_valid(phantom_camera):
		return
	if phantom_camera.follow_target == null and is_instance_valid(player):
		phantom_camera.follow_target = player
	if phantom_camera.follow_target == null:
		return
	if phantom_camera.has_method("teleport_position"):
		phantom_camera.teleport_position()

func _release_warp_camera_hold(follow_player: bool) -> void:
	warp_camera_waiting_for_player_teleport = false
	warp_camera_wait_timeout = 0.0
	if not is_instance_valid(phantom_camera):
		return
	phantom_camera.dead_zone_width = warp_camera_dead_zone_backup.x
	phantom_camera.dead_zone_height = warp_camera_dead_zone_backup.y
	if follow_player and is_instance_valid(player):
		phantom_camera.follow_target = player
		_safe_teleport_phantom_camera()
	elif is_instance_valid(warp_camera_follow_target_backup):
		phantom_camera.follow_target = warp_camera_follow_target_backup

func _ensure_warp_camera_anchor() -> bool:
	if is_instance_valid(warp_camera_anchor):
		return true
	if not is_instance_valid(player):
		return false
	var parent_node := player.get_parent()
	if parent_node == null:
		return false
	warp_camera_anchor = Node2D.new()
	warp_camera_anchor.name = "WarpCameraAnchor"
	parent_node.add_child(warp_camera_anchor)
	return true

func _ensure_valid_follow_target() -> void:
	if not is_instance_valid(phantom_camera):
		return
	if (warp_camera_catchup_active or warp_camera_waiting_for_player_teleport) and is_instance_valid(warp_camera_anchor):
		if phantom_camera.follow_target != warp_camera_anchor:
			phantom_camera.follow_target = warp_camera_anchor
		return
	if phantom_camera.follow_target == null or not is_instance_valid(phantom_camera.follow_target):
		if is_instance_valid(player):
			phantom_camera.follow_target = player

# Door 传送测试路径：短时解限 + 快速追镜 + 自动恢复目标房间限制。
func start_door_teleport_camera_catchup(catchup_duration: float = 0.20, unlock_duration: float = 0.32) -> void:
	if not setup_completed:
		return
	if not is_instance_valid(player) or not is_instance_valid(phantom_camera):
		return
	if door_camera_catchup_active:
		return
	
	door_camera_catchup_active = true
	door_camera_dead_zone_backup = Vector2(phantom_camera.dead_zone_width, phantom_camera.dead_zone_height)
	door_limits_backup.left = int(phantom_camera.get("limit_left"))
	door_limits_backup.top = int(phantom_camera.get("limit_top"))
	door_limits_backup.right = int(phantom_camera.get("limit_right"))
	door_limits_backup.bottom = int(phantom_camera.get("limit_bottom"))
	
	phantom_camera.dead_zone_width = 0.02
	phantom_camera.dead_zone_height = 0.02
	phantom_camera.set("limit_left", -CAMERA_LIMIT_DISABLED)
	phantom_camera.set("limit_top", -CAMERA_LIMIT_DISABLED)
	phantom_camera.set("limit_right", CAMERA_LIMIT_DISABLED)
	phantom_camera.set("limit_bottom", CAMERA_LIMIT_DISABLED)
	
	var camera := player.get_viewport().get_camera_2d()
	var camera_limits_backup := {
		"left": 0,
		"top": 0,
		"right": 0,
		"bottom": 0
	}
	if camera:
		camera_limits_backup.left = camera.limit_left
		camera_limits_backup.top = camera.limit_top
		camera_limits_backup.right = camera.limit_right
		camera_limits_backup.bottom = camera.limit_bottom
		camera.limit_left = -CAMERA_LIMIT_DISABLED
		camera.limit_top = -CAMERA_LIMIT_DISABLED
		camera.limit_right = CAMERA_LIMIT_DISABLED
		camera.limit_bottom = CAMERA_LIMIT_DISABLED
	
	start_camera_transition_guard(0.06, maxf(catchup_duration + unlock_duration, 0.35))
	
	var dead_zone_timer := player.get_tree().create_timer(maxf(catchup_duration, 0.05))
	dead_zone_timer.timeout.connect(func():
		if not is_instance_valid(phantom_camera):
			return
		phantom_camera.dead_zone_width = door_camera_dead_zone_backup.x
		phantom_camera.dead_zone_height = door_camera_dead_zone_backup.y
	)
	
	var restore_timer := player.get_tree().create_timer(maxf(unlock_duration, catchup_duration))
	restore_timer.timeout.connect(func():
		if not is_instance_valid(phantom_camera):
			door_camera_catchup_active = false
			return
		phantom_camera.set("limit_left", int(door_limits_backup.left))
		phantom_camera.set("limit_top", int(door_limits_backup.top))
		phantom_camera.set("limit_right", int(door_limits_backup.right))
		phantom_camera.set("limit_bottom", int(door_limits_backup.bottom))
		if camera and is_instance_valid(camera):
			camera.limit_left = int(camera_limits_backup.left)
			camera.limit_top = int(camera_limits_backup.top)
			camera.limit_right = int(camera_limits_backup.right)
			camera.limit_bottom = int(camera_limits_backup.bottom)
		door_camera_catchup_active = false
	
	)

# 返回当前相机守卫和跟随状态的调试快照。
func get_debug_snapshot() -> Dictionary:
	return {
		"setup_completed": setup_completed,
		"guard_active": camera_transition_guard_active,
		"guard_elapsed": camera_transition_guard_elapsed,
		"guard_remaining": camera_transition_guard_timer,
		"axis_lock": camera_transition_axis_lock_backup,
		"player_inside_tree": is_instance_valid(player) and player.is_inside_tree() if player else false,
		"camera_inside_tree": is_instance_valid(phantom_camera) and phantom_camera.is_inside_tree() if phantom_camera else false,
		"camera_pos": phantom_camera.global_position if phantom_camera else Vector2.ZERO,
		"follow_offset": phantom_camera.get_follow_offset() if phantom_camera and phantom_camera.has_method("get_follow_offset") else Vector2.ZERO
	}

# 通过限制范围把目标中心点夹回可用区域。
func _clamp_camera_center_by_limits(target_center: Vector2, pcam: Node, camera: Camera2D) -> Vector2:
	return PlayerCameraMathUtil.clamp_camera_center_by_limits(
		target_center,
		pcam,
		camera,
		player.get_viewport_rect().size,
		CAMERA_LIMIT_DISABLED
	)

# 判断玩家是否已经回到正常 dead zone 内，允许守卫结束。
func _is_player_inside_normal_camera_dead_zone() -> bool:
	if not phantom_camera or not player:
		return true
	var camera := player.get_viewport().get_camera_2d()
	if camera == null:
		return true

	var target_world: Vector2 = player.global_position + phantom_camera.follow_offset
	var camera_center: Vector2 = camera.global_position
	var viewport_size: Vector2 = player.get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return true

	var zoom: Vector2 = camera.zoom
	if not target_world.is_finite() or not camera_center.is_finite() or not zoom.is_finite():
		return true
	if is_zero_approx(zoom.x) or is_zero_approx(zoom.y):
		return true
	var half_dead_w: float = viewport_size.x * camera_transition_dead_zone_backup.x * 0.5 / zoom.x
	var half_dead_h: float = viewport_size.y * camera_transition_dead_zone_backup.y * 0.5 / zoom.y
	var half_view_w: float = viewport_size.x * 0.5 / zoom.x
	var half_view_h: float = viewport_size.y * 0.5 / zoom.y

	var limit_left: float = float(int(phantom_camera.get("limit_left")))
	var limit_top: float = float(int(phantom_camera.get("limit_top")))
	var limit_right: float = float(int(phantom_camera.get("limit_right")))
	var limit_bottom: float = float(int(phantom_camera.get("limit_bottom")))

	if limit_left <= -CAMERA_LIMIT_DISABLED + 1 and limit_right >= CAMERA_LIMIT_DISABLED - 1 and limit_top <= -CAMERA_LIMIT_DISABLED + 1 and limit_bottom >= CAMERA_LIMIT_DISABLED - 1:
		return true

	var inside_x: bool = absf(target_world.x - camera_center.x) <= half_dead_w
	var inside_y: bool = absf(target_world.y - camera_center.y) <= half_dead_h

	var free_min_x: float = limit_left + half_view_w + half_dead_w
	var free_max_x: float = limit_right - half_view_w - half_dead_w
	var free_min_y: float = limit_top + half_view_h + half_dead_h
	var free_max_y: float = limit_bottom - half_view_h - half_dead_h
	if free_min_x > free_max_x:
		inside_x = true
	if free_min_y > free_max_y:
		inside_y = true

	if CAMERA_TELEPORT_DEBUG:
		print("[CameraGuard] target=", target_world, " cam=", camera_center, " dead=", half_dead_w, ",", half_dead_h, " freeX=", free_min_x, "..", free_max_x, " freeY=", free_min_y, "..", free_max_y, " inside=", inside_x and inside_y)

	return inside_x and inside_y

# 当相机坐标出现 NaN/Inf 时，立即重置到玩家附近并刷新相机同步。
func _recover_from_invalid_camera_position() -> void:
	if not is_instance_valid(player) or not is_instance_valid(phantom_camera):
		return
	var camera := player.get_viewport().get_camera_2d()
	var camera_before := camera.global_position if camera else Vector2.ZERO
	var offset_before := camera.offset if camera else Vector2.ZERO
	var pcam_before: Vector2 = phantom_camera.global_position
	var now_ms := Time.get_ticks_msec()
	if player.camera_damage_debug and now_ms - invalid_camera_debug_last_log_ms >= 250:
		invalid_camera_debug_last_log_ms = now_ms
		var room_name := RoomManager.current_room if RoomManager else ""
		print("[CameraInvalidRecover] room=", room_name,
			" player_pos=", player.global_position,
			" pcam_before=", pcam_before,
			" cam_before=", camera_before,
			" cam_offset_before=", offset_before,
			" state=", player.current_state,
			" anim=", player.current_animation,
			" warp=", player.is_warp_damage)
	var safe_center: Vector2 = player.global_position + phantom_camera.follow_offset
	if not phantom_camera.follow_offset.is_finite():
		phantom_camera.follow_offset = Vector2.ZERO
		safe_center = player.global_position
	if not safe_center.is_finite():
		safe_center = player.global_position if player.global_position.is_finite() else Vector2.ZERO
	phantom_camera.global_position = safe_center
	if phantom_camera.has_method("teleport_position"):
		phantom_camera.teleport_position()
	if camera:
		if not camera.offset.is_finite():
			camera.offset = Vector2.ZERO
		camera.global_position = safe_center
		if camera.has_method("reset_smoothing"):
			camera.reset_smoothing()
		if camera.has_method("reset_physics_interpolation"):
			camera.reset_physics_interpolation()
	if CameraShakeManager and CameraShakeManager.has_method("stop_shake"):
		CameraShakeManager.stop_shake(phantom_camera)
	start_camera_transition_guard(0.10, 0.65)
