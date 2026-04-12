extends RefCounted
class_name PlayerFeedbackService

# 统一处理跑步、冲刺和 JumpBox 残影的节奏与池切换。
static func handle_afterimages(player: Node, fixed_delta: float) -> void:
	var current_fps = Engine.get_frames_per_second()
	if current_fps < 45:
		player.afterimage_spawn_rate = lerp(player.afterimage_spawn_rate, 2.0, fixed_delta * 2.0)
	elif current_fps > 55:
		player.afterimage_spawn_rate = lerp(player.afterimage_spawn_rate, 0.8, fixed_delta * 2.0)

	player.afterimage_spawn_rate = clamp(player.afterimage_spawn_rate, 0.5, 2.0)

	match player.current_state:
		player.PlayerState.DASH:
			player.afterimage_timer += fixed_delta
			var dash_type = "black_dash" if player.black_dash_unlocked else "dash"
			var dash_interval = player._get_afterimage_interval(dash_type) * player.afterimage_spawn_rate
			if player.afterimage_timer >= dash_interval:
				player.afterimage_timer = 0.0
				if player.black_dash_unlocked:
					player.create_afterimage(player.PlayerState.DASH, false, "black_dash")
				else:
					player.create_afterimage(player.PlayerState.DASH, false)
		player.PlayerState.SUPERDASH:
			player.super_dash_afterimage_timer += fixed_delta
			var super_dash_interval = player._get_afterimage_interval("super_dash") * player.afterimage_spawn_rate
			if player.super_dash_afterimage_timer >= super_dash_interval:
				player.super_dash_afterimage_timer = 0.0
				player.create_afterimage(player.PlayerState.SUPERDASH, false)
		_:
			player.afterimage_timer = 0.0

	if player.has_jumpbox_afterimage and player.current_animation == "JUMP2":
		player.jump2_afterimage_timer += fixed_delta
		var jumpbox_interval = player._get_afterimage_interval(player.jumpbox_afterimage_type) * player.afterimage_spawn_rate
		if player.jump2_afterimage_timer >= jumpbox_interval:
			player.jump2_afterimage_timer = 0.0
			player.create_afterimage(player.PlayerState.JUMP, true, player.jumpbox_afterimage_type)
	elif player.has_jumpbox_afterimage and player.current_animation != "JUMP2":
		player.has_jumpbox_afterimage = false
		player.jump2_afterimage_timer = 0.0
		player.clear_jumpbox_afterimage_pool()

static func return_afterimage(_player: Node, afterimage: Node, _type_name: String = "dash") -> void:
	if is_instance_valid(afterimage) and afterimage.has_method("return_to_pool"):
		afterimage.return_to_pool()

static func get_afterimage_type_name(player: Node, state: int, is_jumpbox: bool = false) -> String:
	match state:
		player.PlayerState.DASH:
			return "dash"
		player.PlayerState.SUPERDASH:
			return "super_dash"
		player.PlayerState.JUMP:
			return player.jumpbox_afterimage_type if is_jumpbox else "dash"
		_:
			return "dash"

static func create_afterimage(player: Node, state: int, is_jumpbox: bool = false, custom_type: String = "") -> void:
	if Engine.get_frames_per_second() < 45:
		return
	if player.afterimage_trail == null:
		player._ensure_afterimage_trail()
	if player.afterimage_trail != null:
		_create_afterimage_new(player, state, is_jumpbox, custom_type)
		player.trigger_feedback_event(&"afterimage_spawned", {
			"state": state,
			"is_jumpbox": is_jumpbox,
			"custom_type": custom_type
		})
	else:
		push_warning("[Player] 残影系统不可用，跳过残影生成")

static func _create_afterimage_new(player: Node, state: int, is_jumpbox: bool = false, custom_type: String = "") -> void:
	var type_name = custom_type if custom_type != "" else get_afterimage_type_name(player, state, is_jumpbox)
	var spawn_position = player.global_position
	if is_instance_valid(player.animated_sprite):
		spawn_position = player.animated_sprite.global_position
	else:
		push_warning("[Player] animated_sprite 节点无效，使用 Player 根节点位置")
	if not spawn_position.is_finite():
		spawn_position = player.global_position

	var current_texture = player.get_current_frame_texture()
	if not current_texture:
		push_error("[Player] 纹理为空！跳过生成")
		return

	var move_direction = Vector2.ZERO
	var player_velocity = player.get_velocity() if player.has_method("get_velocity") else Vector2.ZERO
	if player_velocity != Vector2.ZERO:
		move_direction = -player_velocity.normalized()
	else:
		move_direction = Vector2(-1 if player.is_facing_right else 1, 0)
	if not move_direction.is_finite() or move_direction.length_squared() < 0.0001:
		move_direction = Vector2(-1 if player.is_facing_right else 1, 0)

	if player.afterimage_trail != null and player.afterimage_trail.has_method("spawn"):
		var afterimage = player.afterimage_trail.spawn(
			type_name,
			spawn_position,
			current_texture,
			player.animated_sprite.flip_h,
			Vector2.ONE * 0.8 if not is_jumpbox else Vector2.ONE,
			move_direction,
			-1.0,
			player.z_index
		)
		if afterimage:
			afterimage.player_ref = player

static func clear_jumpbox_afterimage_pool(player: Node) -> void:
	player.has_jumpbox_afterimage = false

static func get_current_frame_texture(player: Node) -> Texture2D:
	if player.animated_sprite.sprite_frames != null and player.animated_sprite.animation != "":
		var frame_count = player.animated_sprite.sprite_frames.get_frame_count(player.animated_sprite.animation)
		if frame_count > 0 and player.animated_sprite.frame < frame_count:
			return player.animated_sprite.sprite_frames.get_frame_texture(
				player.animated_sprite.animation,
				player.animated_sprite.frame
			)
	return null

static func register_feedback_hook(player: Node, event_name: StringName, callback: Callable) -> void:
	if not callback.is_valid():
		return
	if not player.feedback_hooks.has(event_name):
		player.feedback_hooks[event_name] = []
	var callbacks: Array = player.feedback_hooks[event_name]
	for existing in callbacks:
		if existing == callback:
			return
	callbacks.append(callback)
	player.feedback_hooks[event_name] = callbacks

static func unregister_feedback_hook(player: Node, event_name: StringName, callback: Callable) -> void:
	if not player.feedback_hooks.has(event_name):
		return
	var callbacks: Array = player.feedback_hooks[event_name]
	callbacks = callbacks.filter(func(existing): return existing != callback)
	if callbacks.is_empty():
		player.feedback_hooks.erase(event_name)
	else:
		player.feedback_hooks[event_name] = callbacks

static func trigger_feedback_event(player: Node, event_name: StringName, payload: Dictionary = {}) -> void:
	if not player.feedback_hooks.has(event_name):
		return
	for callback in player.feedback_hooks[event_name]:
		if callback is Callable and callback.is_valid():
			callback.call(payload)
