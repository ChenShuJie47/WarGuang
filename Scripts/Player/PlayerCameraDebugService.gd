extends RefCounted
class_name PlayerCameraDebugService

# 输出受伤相关相机调试日志，并返回建议更新后的节流时间戳。
static func log_damage_state(player: Node, stage: String, damage_source_position: Vector2, damage: int, damage_type: int, knockback_force: Vector2, last_log_ms: int) -> int:
	if not player.camera_damage_debug:
		return last_log_ms
	var now_ms := Time.get_ticks_msec()
	if stage == "before_damage" and now_ms - last_log_ms < 250:
		return last_log_ms

	var camera_pos := Vector2.ZERO
	var viewport_camera_pos := Vector2.ZERO
	var viewport_camera_offset := Vector2.ZERO
	var follow_offset := Vector2.ZERO
	var controller_snapshot = {}
	if player.phantom_camera:
		camera_pos = player.phantom_camera.global_position
		if player.phantom_camera.has_method("get_follow_offset"):
			follow_offset = player.phantom_camera.get_follow_offset()
	var viewport_camera := player.get_viewport().get_camera_2d() if player.get_viewport() else null
	if viewport_camera:
		viewport_camera_pos = viewport_camera.global_position
		viewport_camera_offset = viewport_camera.offset
	if player.camera_controller and player.camera_controller.has_method("get_debug_snapshot"):
		controller_snapshot = player.camera_controller.get_debug_snapshot()
	var room_name := RoomManager.current_room if RoomManager else ""
	print("[CameraDamageDebug] stage=", stage,
		" player_pos=", player.global_position,
		" cam_pos=", camera_pos,
		" vcam_pos=", viewport_camera_pos,
		" vcam_offset=", viewport_camera_offset,
		" follow_offset=", follow_offset,
		" room=", room_name,
		" state=", player.current_state,
		" anim=", player.current_animation,
		" type=", damage_type,
		" src=", damage_source_position)
	if stage == "after_damage" and PlayerDamageService.is_warp_damage_type(damage_type):
		var checkpoint_pos := Global.get_last_checkpoint_position()
		var checkpoint_room := PlayerDamageService.resolve_room_for_position(checkpoint_pos, room_name)
		print("[CameraDamageDebug][warp_target] checkpoint_pos=", checkpoint_pos,
			" checkpoint_room=", checkpoint_room,
			" save_pos=", Global.get_save_point_position())
	if not camera_pos.is_finite():
		print("[CameraDamageDebug][invalid_camera] controller=", controller_snapshot, " kb=", knockback_force, " damage=", damage)
	elif viewport_camera and (not viewport_camera_pos.is_finite() or not viewport_camera_offset.is_finite()):
		print("[CameraDamageDebug][invalid_viewport_camera] controller=", controller_snapshot, " kb=", knockback_force, " damage=", damage)
	return now_ms

# 输出 JumpBox 相关相机调试日志。
static func log_jumpbox_state(player: Node, stage: String, trigger_grade: String, jumpbox_position: Vector2) -> void:
	if not player.camera_damage_debug:
		return
	var camera_pos := Vector2.ZERO
	var camera_offset := Vector2.ZERO
	var follow_offset := Vector2.ZERO
	var controller_snapshot = {}
	if player.phantom_camera:
		camera_pos = player.phantom_camera.global_position
		if player.phantom_camera.has_method("get_follow_offset"):
			follow_offset = player.phantom_camera.get_follow_offset()
	var viewport_camera := player.get_viewport().get_camera_2d() if player.get_viewport() else null
	if viewport_camera:
		camera_offset = viewport_camera.offset
	if player.camera_controller and player.camera_controller.has_method("get_debug_snapshot"):
		controller_snapshot = player.camera_controller.get_debug_snapshot()
	print("[CameraJumpBoxDebug] stage=", stage,
		" grade=", trigger_grade,
		" jumpbox_pos=", jumpbox_position,
		" player_pos=", player.global_position,
		" cam_pos=", camera_pos,
		" cam_offset=", camera_offset,
		" follow_offset=", follow_offset,
		" state=", player.current_state,
		" anim=", player.current_animation,
		" vel=", player.velocity,
		" controller=", controller_snapshot)
