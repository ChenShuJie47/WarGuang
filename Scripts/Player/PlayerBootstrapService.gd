extends RefCounted
class_name PlayerBootstrapService

static func initialize_on_ready(player: Node) -> void:
	if not player.is_in_group("player"):
		player.add_to_group("player")

	player.dash_unlocked = Global.unlocked_abilities.get("dash", false)
	player.double_jump_unlocked = Global.unlocked_abilities.get("double_jump", false)
	player.glide_unlocked = Global.unlocked_abilities.get("glide", false)
	player.black_dash_unlocked = Global.unlocked_abilities.get("black_dash", false)
	player.wall_grip_unlocked = Global.unlocked_abilities.get("wall_grip", false)
	player.super_dash_unlocked = Global.unlocked_abilities.get("super_dash", false)

	if player.camera_controller and player.camera_controller.has_method("setup"):
		player.camera_controller.call_deferred("setup", player)
	if player.fx_controller and player.fx_controller.has_method("setup"):
		player.fx_controller.call_deferred("setup", player)

	player.find_vignette_effect()
	initialize_timers(player)
	initialize_wall_detection(player)
	player.call_deferred("initialize_player_ui")
	initialize_afterimage_pool(player)

	DialogueSystem.dialogue_started.connect(player._on_dialogue_started)
	DialogueSystem.dialogue_ended.connect(player._on_dialogue_ended)

	if RoomManager.has_method("set_low_health_effect"):
		print("Player: 已连接RoomManager颜色管理")

	_connect_ability_unlock_signals(player)

static func initialize_timers(player: Node) -> void:
	player.coyote_timer = Timer.new()
	player.coyote_timer.name = "CoyoteTimer"
	player.coyote_timer.one_shot = true
	player.timers.add_child(player.coyote_timer)
	player.coyote_timer.timeout.connect(player._on_coyote_timeout)

	player.jump_buffer_timer = Timer.new()
	player.jump_buffer_timer.name = "JumpBufferTimer"
	player.jump_buffer_timer.one_shot = true
	player.timers.add_child(player.jump_buffer_timer)
	player.jump_buffer_timer.timeout.connect(player._on_jump_buffer_timeout)

	player.dash_duration_timer_node = Timer.new()
	player.dash_duration_timer_node.name = "DashDurationTimer"
	player.dash_duration_timer_node.one_shot = true
	player.timers.add_child(player.dash_duration_timer_node)
	player.dash_duration_timer_node.timeout.connect(player._on_dash_duration_timeout)

	player.dash_cooldown_timer_node = Timer.new()
	player.dash_cooldown_timer_node.name = "DashCooldownTimer"
	player.dash_cooldown_timer_node.one_shot = true
	player.timers.add_child(player.dash_cooldown_timer_node)
	player.dash_cooldown_timer_node.timeout.connect(player._on_dash_cooldown_timeout)

	player.wall_grip_reverse_timer_node = Timer.new()
	player.wall_grip_reverse_timer_node.name = "WallGripReverseTimer"
	player.wall_grip_reverse_timer_node.one_shot = true
	player.timers.add_child(player.wall_grip_reverse_timer_node)
	player.wall_grip_reverse_timer_node.timeout.connect(player._on_wall_grip_reverse_timeout)

static func initialize_player_ui(player: Node) -> void:
	var ui_nodes = player.get_tree().get_nodes_in_group("player_ui")
	if ui_nodes.size() > 0:
		player.player_ui = ui_nodes[0]
	if player.player_ui:
		if player.player_ui.has_signal("player_died"):
			if player.player_ui.player_died.is_connected(player._on_player_died):
				player.player_ui.player_died.disconnect(player._on_player_died)
			player.player_ui.player_died.connect(player._on_player_died)
		else:
			print("警告: PlayerUI没有player_died信号")
	else:
		print("=== PlayerUI查找失败 ===")

static func initialize_afterimage_pool(player: Node) -> void:
	_ensure_afterimage_trail(player)
	if player.afterimage_trail == null:
		push_error("[Player] 未找到本地 AfterimageTrail")

static func _ensure_afterimage_trail(player: Node) -> void:
	if is_instance_valid(player.afterimage_trail):
		return
	player.afterimage_trail = player.get_node_or_null("AfterimageTrail")
	if player.afterimage_trail == null:
		var trail_script = load("res://Scripts/Components/AfterimageTrail.gd")
		player.afterimage_trail = trail_script.new()
		player.afterimage_trail.name = "AfterimageTrail"
		player.add_child(player.afterimage_trail)
	_sync_afterimage_trail_config_defaults(player)

static func _sync_afterimage_trail_config_defaults(player: Node) -> void:
	if player.afterimage_trail == null:
		return

static func get_afterimage_interval(player: Node, type_name: String) -> float:
	if player.afterimage_trail != null and player.afterimage_trail.has_method("get_interval"):
		return player.afterimage_trail.get_interval(type_name)
	return 0.05

static func initialize_wall_detection(player: Node) -> void:
	if player.left_wall_ray and player.right_wall_ray:
		player.left_wall_ray.enabled = true
		player.right_wall_ray.enabled = true
		player.left_wall_ray.collision_mask = 1 << 2
		player.right_wall_ray.collision_mask = 1 << 2

static func _connect_ability_unlock_signals(player: Node) -> void:
	if not (EventBus and EventBus.instance):
		return
	if EventBus.instance.dash_unlocked.is_connected(player._on_dash_unlocked):
		EventBus.instance.dash_unlocked.disconnect(player._on_dash_unlocked)
	EventBus.instance.dash_unlocked.connect(player._on_dash_unlocked)

	if EventBus.instance.double_jump_unlocked.is_connected(player._on_double_jump_unlocked):
		EventBus.instance.double_jump_unlocked.disconnect(player._on_double_jump_unlocked)
	EventBus.instance.double_jump_unlocked.connect(player._on_double_jump_unlocked)

	if EventBus.instance.glide_unlocked.is_connected(player._on_glide_unlocked):
		EventBus.instance.glide_unlocked.disconnect(player._on_glide_unlocked)
	EventBus.instance.glide_unlocked.connect(player._on_glide_unlocked)

	if EventBus.instance.black_dash_unlocked.is_connected(player._on_black_dash_unlocked):
		EventBus.instance.black_dash_unlocked.disconnect(player._on_black_dash_unlocked)
	EventBus.instance.black_dash_unlocked.connect(player._on_black_dash_unlocked)

	if EventBus.instance.super_dash_unlocked.is_connected(player._on_super_dash_unlocked):
		EventBus.instance.super_dash_unlocked.disconnect(player._on_super_dash_unlocked)
	EventBus.instance.super_dash_unlocked.connect(player._on_super_dash_unlocked)

	if EventBus.instance.wall_grip_unlocked.is_connected(player._on_wall_grip_unlocked):
		EventBus.instance.wall_grip_unlocked.disconnect(player._on_wall_grip_unlocked)
	EventBus.instance.wall_grip_unlocked.connect(player._on_wall_grip_unlocked)