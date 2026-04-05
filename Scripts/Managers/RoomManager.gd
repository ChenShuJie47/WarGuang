extends Node

const CAMERA_LIMIT_DISABLED: int = 10000000  # 禁用相机限制时使用的极大边界值（与 PhantomCamera2D 默认值一致）

# 在变量声明部分添加
var global_canvas_modulate: CanvasModulate = null

## 房间数据
var rooms: Dictionary = {}
var current_room: String = ""
var player_ref: Node = null

## 颜色状态管理
var room_original_colors: Dictionary = {}  # 房间ID -> 原始颜色（检查器中设置的颜色）
var is_low_health_active: bool = false     # 低血量效果是否激活
var low_health_color: Color = Color.WHITE  # 低血量效果颜色（由Player设置）

## 注册房间
func register_room(room_id: String, room_node: Node, room_data: Dictionary):
	# 确保从房间节点获取正确的颜色
	var room_color = Color.WHITE
	if room_node.has_method("get_room_color"):
		room_color = room_node.get_room_color()
	elif room_node.has_property("room_color"):
		room_color = room_node.room_color
	
	rooms[room_id] = {
		"node": room_node,
		"bounds": room_data.get("bounds", Rect2()),
		"bgm": room_data.get("bgm", ""),
		"adjacent": room_data.get("adjacent", []),
		"color": room_color
	}

# RoomManager.gd - 修改 set_global_canvas_modulate 函数
func set_global_canvas_modulate(canvas: CanvasModulate):
	global_canvas_modulate = canvas

func load_room(room_id: String):
	if not rooms.has(room_id):
		push_error("房间不存在：" + room_id)
		return
	
	notify_dynamic_checkpoint_manager_room_change(room_id)
	notify_vignette_effect_room_change()
	unload_distant_rooms(room_id)
	
	# 关键新增：清理被摧毁的石墙（切换房间时删除实例）
	cleanup_destroyed_walls()
	
	current_room = room_id
	
	if global_canvas_modulate:
		var room_data = rooms[room_id]
		var target_color = room_data.get("color", Color.WHITE)
		global_canvas_modulate.color = target_color
	else:
		print("RoomManager: 错误：未找到全局 CanvasModulate")
	
	switch_room_bgm(room_id)
	update_camera_limits()

## 清理被摧毁的石墙（切换房间时调用）
func cleanup_destroyed_walls():
	# 获取当前场景中所有 DestructibleWall 节点
	var walls = get_tree().get_nodes_in_group("destructible_wall")
	for wall in walls:
		if wall.has_method("cleanup_destroyed_walls"):
			wall.cleanup_destroyed_walls()

## 通知 VignetteEffect 房间切换
func notify_vignette_effect_room_change():
	var vignette_nodes = get_tree().get_nodes_in_group("vignette_effect")
	for vignette in vignette_nodes:
		if vignette.has_method("on_room_changed"):
			vignette.on_room_changed()

## 通知DynamicCheckpointManager房间切换
func notify_dynamic_checkpoint_manager_room_change(new_room_id: String):
	if DynamicCheckpointManager.has_method("on_room_changed"):
		DynamicCheckpointManager.on_room_changed(new_room_id)

## 玩家进入房间
func player_entered_room(room_id: String):
	if room_id == current_room:
		return
	load_room(room_id)

## 卸载远处（非相邻）房间
func unload_distant_rooms(current_room_id: String):
	if not rooms.has(current_room_id):
		return
	
	var current_room_data = rooms[current_room_id]
	var rooms_to_keep = [current_room_id] + current_room_data.adjacent
	
	for room_id in rooms:
		var room_data = rooms[room_id]
		if room_id in rooms_to_keep:
			room_data.node.set_room_active(true)
		else:
			room_data.node.set_room_active(false)

## 新增：添加相邻房间（双向）
func add_adjacent_room(room_a: String, room_b: String):
	if not rooms.has(room_a) or not rooms.has(room_b):
		return
	
	var room_data_a = rooms[room_a]
	var room_data_b = rooms[room_b]
	
	if not room_b in room_data_a.adjacent:
		room_data_a.adjacent.append(room_b)
	
	if not room_a in room_data_b.adjacent:
		room_data_b.adjacent.append(room_a)

## 新增：自动计算所有房间的相邻关系
func auto_calculate_room_connections():
	var door_pairs = DoorManager.get_all_paired_doors()
	
	if door_pairs.is_empty():
		print("警告：没有找到任何配对的门")
		return
	
	for pair in door_pairs:
		var door_a = pair.door_a
		var door_b = pair.door_b

		var room_a_id = door_a.get_room_id()
		var room_b_id = door_b.get_room_id()
		
		if room_a_id == "" or room_b_id == "":
			push_warning("  ⚠ 跳过：有一个门的房间 ID 为空")
			continue
		
		if room_a_id == room_b_id:
			push_warning("  ⚠ 警告：两个门在同一个房间 ", room_a_id)
			continue
		
		add_adjacent_room(room_a_id, room_b_id)

## 获取当前房间CanvasModulate
func get_current_canvas_modulate() -> CanvasModulate:
	if current_room != "" and rooms.has(current_room):
		var room_node = rooms[current_room].node
		if room_node.has_method("get_canvas_modulate"):
			return room_node.get_canvas_modulate()
	return null

## 切换房间 BGM（使用交叉淡入淡出）
func switch_room_bgm(room_id: String):
	if not rooms.has(room_id):
		return
	
	var room_data = rooms[room_id]
	var bgm_name = room_data.bgm
	
	if bgm_name and bgm_name != "":
		if not AudioManager.is_playing_event_bgm():
			AudioManager.crossfade_bgm(bgm_name, 1.0)
		else:
			print("事件 BGM 播放中，不切换")

## 更新相机限制框
func update_camera_limits():
	if not rooms.has(current_room) or not player_ref:
		return
	
	var room_data = rooms[current_room]
	var camera_limits = room_data.node.get_camera_limits()
	
	var player_camera = player_ref.get_node_or_null("PhantomCamera2D")
	if player_camera:
		if camera_limits.has_area():
			# 只更新限制边界，不修改相机位置
			player_camera.limit_left = camera_limits.position.x
			player_camera.limit_top = camera_limits.position.y
			player_camera.limit_right = camera_limits.end.x
			player_camera.limit_bottom = camera_limits.end.y
		else:
			# 重置为默认的极大限制范围（相当于禁用限制）
			player_camera.limit_left = -CAMERA_LIMIT_DISABLED
			player_camera.limit_top = -CAMERA_LIMIT_DISABLED
			player_camera.limit_right = CAMERA_LIMIT_DISABLED
			player_camera.limit_bottom = CAMERA_LIMIT_DISABLED

## 设置玩家引用
func set_player(player: Node):
	player_ref = player

## 获取当前房间数据
func get_current_room_data():
	return rooms.get(current_room, null)
