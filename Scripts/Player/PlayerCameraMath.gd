class_name PlayerCameraMath
extends RefCounted

static func clamp_camera_center_by_limits(target_center: Vector2, pcam: Node, camera: Camera2D, viewport_size: Vector2, camera_limit_disabled: int) -> Vector2:
	if pcam == null:
		return target_center

	var limit_left: float = float(int(pcam.get("limit_left")))
	var limit_top: float = float(int(pcam.get("limit_top")))
	var limit_right: float = float(int(pcam.get("limit_right")))
	var limit_bottom: float = float(int(pcam.get("limit_bottom")))

	if limit_left <= -camera_limit_disabled + 1 and limit_right >= camera_limit_disabled - 1 and limit_top <= -camera_limit_disabled + 1 and limit_bottom >= camera_limit_disabled - 1:
		return target_center

	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return target_center

	var zoom: Vector2 = Vector2.ONE
	if camera:
		zoom = camera.zoom
	elif pcam.has_method("get_zoom"):
		zoom = pcam.get_zoom()

	var half_w: float = viewport_size.x * 0.5 / zoom.x
	var half_h: float = viewport_size.y * 0.5 / zoom.y

	var min_x: float = limit_left + half_w
	var max_x: float = limit_right - half_w
	var min_y: float = limit_top + half_h
	var max_y: float = limit_bottom - half_h

	# 当房间可视范围小于屏幕时，锁到中点，避免 clamp 反转导致抖动
	if min_x > max_x:
		min_x = (limit_left + limit_right) * 0.5
		max_x = min_x
	if min_y > max_y:
		min_y = (limit_top + limit_bottom) * 0.5
		max_y = min_y

	return Vector2(clampf(target_center.x, min_x, max_x), clampf(target_center.y, min_y, max_y))
