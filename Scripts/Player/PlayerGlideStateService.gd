extends RefCounted
class_name PlayerGlideStateService

# 处理滑翔状态：直接水平加速 + 起始滞空 + 线性下落倍率过渡。
static func handle_state(player: Node, fixed_delta: float, move_input: float, jump_pressed: bool, dash_just_pressed: bool) -> void:
	# 冲刺检测（最高优先级，可打断滑翔）
	if player.try_dash(dash_just_pressed):
		return

	# 松开跳跃键时退出滑翔
	if not jump_pressed:
		player.exit_glide()
		return

	# 落地时退出滑翔
	if player.is_on_floor():
		player.exit_glide()
		return

	player.glide_timer += fixed_delta

	# 根据输入方向更新滑翔方向
	if move_input != 0:
		player.glide_direction = 1 if move_input > 0 else -1
		player.is_facing_right = player.glide_direction > 0

	# 水平移动：按下输入时直接使用设定加速度，不再做过渡。
	var target_horizontal_speed: float = player.glide_direction * player.glide_target_h_speed * player.effective_horizontal_multiplier
	if move_input != 0:
		var glide_accel: float = player.glide_horizontal_acceleration * player.effective_horizontal_multiplier * fixed_delta
		player.velocity.x = move_toward(player.velocity.x, target_horizontal_speed, glide_accel)
	else:
		var glide_release: float = player.glide_release_deceleration * player.effective_horizontal_multiplier * fixed_delta
		player.velocity.x = move_toward(player.velocity.x, 0.0, glide_release)

	# 垂直下落：先滞空，再线性增加下落倍率。
	var current_max_fall: float = 0.0
	if player.glide_timer > player.glide_hover_time:
		var fall_elapsed: float = player.glide_timer - player.glide_hover_time
		var fall_progress: float = min(fall_elapsed / maxf(player.glide_fall_accel_time, 0.001), 1.0)
		current_max_fall = player.max_fall_speed * lerp(0.0, player.glide_max_fall_multiplier, fall_progress)
	player.velocity.y = min(player.velocity.y, current_max_fall * player.effective_max_fall_multiplier)
