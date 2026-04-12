extends RefCounted
class_name PlayerVisualStateService

static func find_vignette_effect(player: Node) -> void:
	# 等待一帧确保所有节点都加载完成
	await player.get_tree().process_frame

	# 通过路径直接获取
	var vignette = player.get_node_or_null("/root/MainGameScene/VignetteEffect")
	if vignette:
		player.vignette_effect = vignette
		return

	# 或者通过遍历子节点查找
	var main_scene = player.get_tree().current_scene
	if main_scene:
		for child in main_scene.get_children():
			if child.name == "VignetteEffect" or child.is_in_group("vignette_effect"):
				player.vignette_effect = child
				break
	if not player.vignette_effect:
		print("Player: 警告：未找到VignetteEffect节点")

static func start_vignette_hurt(player: Node) -> void:
	if player.vignette_effect and player.vignette_effect.has_method("start_hurt_effect"):
		player.is_hurt_visual_active = true

		# 从VignetteEffect获取持续时间
		var duration = player.vignette_effect.hurt_darkness_duration
		player.vignette_effect.start_hurt_effect(duration)
		# 设置定时器，在受伤效果持续时间结束后处理
		player.get_tree().create_timer(duration).timeout.connect(
			func():
				# 清除即将受伤标记
				player.is_about_to_be_hurt = false
				player._on_hurt_duration_end(false)
		)

static func start_vignette_shadow_hurt(player: Node) -> void:
	if player.vignette_effect and player.vignette_effect.has_method("start_shadow_hurt_effect"):
		var duration = player.vignette_effect.hurt_shadow_darkness_duration
		player.vignette_effect.start_shadow_hurt_effect(duration)

		player.get_tree().create_timer(duration).timeout.connect(
			func():
				player._on_hurt_duration_end(true)
		)

static func on_hurt_duration_end(player: Node, _is_shadow_hurt: bool) -> void:
	if not player.vignette_effect:
		return
	if player.player_ui and player.player_ui.get_health() <= 1:
		if player.vignette_effect.has_method("transition_hurt_to_low_health"):
			var transition_time = player.vignette_effect.hurt_to_low_health_transition
			if player.vignette_effect.current_effect == "hurt":
				player.vignette_effect.transition_hurt_to_low_health(transition_time)
				player.is_low_health_effect_active = true
			else:
				trigger_low_health_effect(player)
		else:
			if player.vignette_effect.has_method("transition_to_low_health"):
				var fallback_transition_time = player.vignette_effect.hurt_to_low_health_transition
				player.vignette_effect.transition_to_low_health(fallback_transition_time)
				player.is_low_health_effect_active = true
	else:
		if player.vignette_effect.has_method("transition_to_normal"):
			var normal_transition_time = player.vignette_effect.hurt_to_normal_transition
			player.vignette_effect.transition_to_normal(normal_transition_time)

	player.is_hurt_visual_active = false

static func trigger_low_health_effect(player: Node) -> void:
	if player.is_hurt_visual_active:
		return
	if player.is_low_health_effect_active:
		return

	player.is_low_health_effect_active = true
	if player.vignette_effect and player.vignette_effect.has_method("clear_all_effects"):
		player.vignette_effect.clear_all_effects()
		await player.get_tree().process_frame

	if player.vignette_effect and player.vignette_effect.has_method("start_low_health_effect"):
		player.vignette_effect.start_low_health_effect()

static func clear_low_health_effect(player: Node) -> void:
	if not player.is_low_health_effect_active:
		return

	player.is_low_health_effect_active = false
	if player.vignette_effect and player.vignette_effect.has_method("transition_low_health_to_normal"):
		var transition_time = player.vignette_effect.low_health_to_normal_transition
		player.vignette_effect.transition_low_health_to_normal(transition_time)

static func update_low_health_effect(player: Node) -> void:
	if not player.player_ui:
		return

	var current_health = player.player_ui.get_health()
	var is_low_health = current_health <= 1
	if player.is_about_to_be_hurt or player.is_hurt_visual_active:
		return

	if is_low_health and not player.is_low_health_effect_active:
		trigger_low_health_effect(player)
	elif not is_low_health and player.is_low_health_effect_active:
		clear_low_health_effect(player)

static func interrupt_hurt_visual_effect(player: Node) -> void:
	player.is_hurt_visual_active = false
	player.hurt_visual_timer = 0
	if player.vignette_effect and player.vignette_effect.has_method("clear_all_effects"):
		player.vignette_effect.clear_all_effects()

static func interrupt_hurt_visual_only(player: Node) -> void:
	player.is_hurt_visual_active = false
	player.hurt_visual_timer = 0
	if player.vignette_effect and player.vignette_effect.has_method("clear_hurt_effect_only"):
		player.vignette_effect.clear_hurt_effect_only()
