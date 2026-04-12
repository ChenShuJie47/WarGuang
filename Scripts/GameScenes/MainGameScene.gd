# MainGameScene.gd
extends Node2D

signal boot_visual_ready

var _boot_visual_ready: bool = false

@onready var room_container = $RoomContainer
@onready var player = $Player

func _ready():
	_cleanup_runtime_camera_viewfinder_overlays()
	if RoomManager and RoomManager.has_method("reset_runtime_state"):
		RoomManager.reset_runtime_state()

	# 初始化房间系统
	initialize_room_system()
	
	# 设置玩家引用
	RoomManager.set_player(player)
	if Global.current_save_slot >= 0:
		_preposition_player_and_camera_for_save()
	
	# 确保 CanvasModulate 节点正确引用
	var global_canvas = $GlobalCanvasModulate
	if global_canvas:
		# 直接设置 RoomManager 的全局 CanvasModulate 引用
		RoomManager.global_canvas_modulate = global_canvas
		# 初始化颜色为当前房间的颜色（如果已经加载了房间）
		var current_room_data = RoomManager.get_current_room_data()
		if current_room_data:
			global_canvas.color = current_room_data.get("color", Color.WHITE)
	else:
		print("MainGameScene: 错误：未找到 GlobalCanvasModulate")
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	RoomManager.auto_calculate_room_connections()
	
	# 如果是从存档加载，设置玩家位置和状态
	if Global.current_save_slot >= 0:
		await _load_from_save()
	else:
		await get_tree().process_frame
		RoomManager.load_room("Room1")
	
	# 连接玩家死亡信号
	var player_ui = get_tree().get_first_node_in_group("player_ui")
	if player_ui:
		player_ui.player_died.connect(_on_player_died)

	_boot_visual_ready = true
	boot_visual_ready.emit()

func _exit_tree() -> void:
	_cleanup_runtime_camera_viewfinder_overlays()
	if Engine.has_singleton("PhantomCameraManager"):
		var manager = Engine.get_singleton("PhantomCameraManager")
		if manager and manager.has_method("scene_changed"):
			manager.scene_changed()

func _cleanup_runtime_camera_viewfinder_overlays() -> void:
	var root := get_tree().root
	if root == null:
		return
	for child in root.get_children():
		if child is CanvasLayer:
			for grand in child.get_children():
				if grand is Control and grand.name == "ViewfinderPanel":
					child.queue_free()
					break

func wait_until_boot_visual_ready() -> void:
	if _boot_visual_ready:
		return
	await boot_visual_ready

func initialize_room_system():
	# 自动注册所有房间
	for room_node in room_container.get_children():
		if room_node.has_method("get_room_data"):
			var room_data = room_node.get_room_data()
			
			# 关键修改：不传递颜色数据，RoomManager会从CanvasModulate节点获取
			RoomManager.register_room(room_data.id, room_node, room_data)

## 从存档加载
func _load_from_save():
	# 设置玩家位置
	var the_player = get_tree().get_first_node_in_group("player")
	if the_player:
		# 复用死亡重生同款：先切到存档房间再做黑屏居中，避免边界回拉暴露。
		await get_tree().process_frame
		var target_room_id := Global.last_save_room
		if target_room_id == "":
			target_room_id = "Room1"
		if the_player.has_method("sync_room_and_camera_for_respawn"):
			await the_player.sync_room_and_camera_for_respawn(target_room_id, true)
			await get_tree().process_frame
			if the_player.has_method("sync_camera_to_player_center"):
				the_player.sync_camera_to_player_center(true)
		else:
			RoomManager.load_room(target_room_id)
			RoomManager.update_camera_limits()
			_snap_camera_to_player_immediately(the_player)
		await get_tree().physics_frame
		
		# 使用传送伤害的禁用时间，也是存档进入游戏开始时的禁用时间
		the_player.lock_control(the_player.warp_control_lock_time, "warp_damage")
		
		# 设置玩家为睡眠状态
		the_player.enter_sleep_state()
	# 设置玩家UI状态
	var player_ui = get_tree().get_first_node_in_group("player_ui")
	if player_ui:
		player_ui.set_max_health(Global.player_max_health)
		player_ui.set_health(Global.player_current_health)

func _snap_camera_to_player_immediately(the_player: Node) -> void:
	if the_player == null:
		return
	var player_pos: Vector2 = the_player.global_position
	var follow_offset := Vector2.ZERO
	var phantom_camera = the_player.get_node_or_null("PhantomCamera2D")
	if phantom_camera and phantom_camera.has_method("get_follow_offset"):
		follow_offset = phantom_camera.get_follow_offset()
	var target_camera_pos: Vector2 = player_pos + follow_offset
	target_camera_pos = _clamp_camera_target_by_limits(target_camera_pos, phantom_camera)
	var main_camera = get_node_or_null("Camera2D")
	if main_camera:
		main_camera.global_position = target_camera_pos
		if main_camera.has_method("reset_smoothing"):
			main_camera.reset_smoothing()
		if main_camera.has_method("reset_physics_interpolation"):
			main_camera.reset_physics_interpolation()
	if phantom_camera:
		phantom_camera.global_position = target_camera_pos
		if phantom_camera.has_method("teleport_position"):
			phantom_camera.teleport_position()

func _clamp_camera_target_by_limits(target_pos: Vector2, phantom_camera: Node) -> Vector2:
	if phantom_camera == null:
		return target_pos
	var clamped_pos = target_pos
	if phantom_camera.has_method("get"):
		var limit_left = int(phantom_camera.get("limit_left"))
		var limit_top = int(phantom_camera.get("limit_top"))
		var limit_right = int(phantom_camera.get("limit_right"))
		var limit_bottom = int(phantom_camera.get("limit_bottom"))
		clamped_pos.x = clampf(clamped_pos.x, float(limit_left), float(limit_right))
		clamped_pos.y = clampf(clamped_pos.y, float(limit_top), float(limit_bottom))
	return clamped_pos

func _preposition_player_and_camera_for_save() -> void:
	if player == null:
		return
	player.global_position = Global.get_save_point_position()
	# 房间加载与相机同步交给 _load_from_save，保持单路径，避免双重同步竞争。

func _on_player_died():
	# 关键修复：死亡时清除动态检查点记录
	if DynamicCheckpointManager.has_method("clear_all_checkpoints_on_death"):
		DynamicCheckpointManager.clear_all_checkpoints_on_death()
