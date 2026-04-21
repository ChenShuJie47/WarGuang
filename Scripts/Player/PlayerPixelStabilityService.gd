extends RefCounted
class_name PlayerPixelStabilityService

# 可回撤测试：在像素风配置下，抑制低速亚像素速度引起的边界抖动。
# 默认由 Player 导出开关关闭，不影响现有手感。
static func apply_test_velocity_snap(player: Node, move_input: float = 0.0, is_locked_branch: bool = false) -> void:
	if not player.pixel_stability_test_enabled:
		return
	if player.pixel_stability_skip_when_warp_flight and player.warp_flight_active:
		return
	if player.pixel_stability_skip_when_locked and is_locked_branch:
		return
	if player.pixel_stability_only_on_floor and not player.is_on_floor():
		return
	if player.pixel_stability_only_when_no_input and absf(move_input) > 0.01:
		return

	if absf(player.velocity.x) < player.pixel_stability_min_x_speed:
		player.velocity.x = 0.0
	if player.pixel_stability_snap_vertical and absf(player.velocity.y) < player.pixel_stability_min_y_speed:
		player.velocity.y = 0.0
