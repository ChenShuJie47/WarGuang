class_name PlayerCameraController
extends Node

const CAMERA_LIMIT_DISABLED: int = 10000000
const CAMERA_TELEPORT_DEBUG: bool = false
const PlayerCameraMathUtil = preload("res://Scripts/Player/PlayerCameraMath.gd")

var player: Player = null
var phantom_camera: Node = null
var camera_transition_guard_timer: float = 0.0
var camera_transition_guard_active: bool = false
var camera_transition_dead_zone_backup: Vector2 = Vector2(0.125, 0.1)
var camera_transition_guard_elapsed: float = 0.0
var camera_transition_guard_min_duration: float = 0.12
var camera_transition_axis_lock_backup: int = 0
var setup_completed: bool = false

func setup(player_ref: Player) -> void:
	player = player_ref
	phantom_camera = player.get_node_or_null("PhantomCamera2D")
	if phantom_camera:
		if phantom_camera.follow_target == null:
			phantom_camera.follow_target = player
		camera_transition_dead_zone_backup = Vector2(phantom_camera.dead_zone_width, phantom_camera.dead_zone_height)
	setup_completed = true

func physics_process(fixed_delta: float) -> void:
	if not setup_completed:
		return
	if not is_instance_valid(player) or not is_instance_valid(phantom_camera):
		return
	if not player.is_inside_tree() or not phantom_camera.is_inside_tree():
		return
	_update_camera_transition_guard(fixed_delta)

func reset_camera_position() -> void:
	if not player or not phantom_camera:
		return
	var tween = player.create_tween()
	tween.set_trans(player.camera_offset_transition_type)
	tween.set_ease(player.camera_offset_ease_type)
	tween.tween_property(phantom_camera, "follow_offset", Vector2.ZERO, player.camera_offset_transition_duration)

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
		if phantom_camera.has_method("teleport_position"):
			phantom_camera.teleport_position()
	if CAMERA_TELEPORT_DEBUG:
		print("[CameraGuard] lock end elapsed=", camera_transition_guard_elapsed, " timeout_left=", camera_transition_guard_timer)

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

	phantom_camera.global_position = clamped_center
	if phantom_camera.has_method("teleport_position"):
		phantom_camera.teleport_position()

	if camera:
		camera.global_position = clamped_center
		if camera.has_method("reset_smoothing"):
			camera.reset_smoothing()
		if camera.has_method("reset_physics_interpolation"):
			camera.reset_physics_interpolation()

	if CAMERA_TELEPORT_DEBUG:
		print("[CameraTeleportSync] desired=", desired_center, " clamped=", clamped_center)

	start_camera_transition_guard(0.10, 0.65)

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

func _clamp_camera_center_by_limits(target_center: Vector2, pcam: Node, camera: Camera2D) -> Vector2:
	return PlayerCameraMathUtil.clamp_camera_center_by_limits(
		target_center,
		pcam,
		camera,
		player.get_viewport_rect().size,
		CAMERA_LIMIT_DISABLED
	)

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
