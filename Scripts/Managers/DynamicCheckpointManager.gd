extends Node
# 自动加载的单例

var current_checkpoint_id: int = -1
var current_checkpoint_room: String = ""
var checkpoints: Dictionary = {}  # checkpoint_id -> position
var checkpoint_rooms: Dictionary = {}  # checkpoint_id -> room_id

func _ready():
	add_to_group("dynamic_checkpoint_manager")
	await get_tree().process_frame

## 注册检查点
func register_checkpoint(checkpoint_id: int, position: Vector2, room_id: String):
	# 检查 ID 是否重复
	if checkpoints.has(checkpoint_id):
		var old_room: String = checkpoint_rooms.get(checkpoint_id, "未知")
		var old_pos: Vector2 = checkpoints.get(checkpoint_id, Vector2.ZERO)
		
		# 处理“重复注册但内容一致”的情况：
		# 进入存档/切回同一房间时，检查点可能会被再次注册，而动态检查点应该表现为幂等。
		# 如果房间与位置都相同，则不报警，避免刷屏。
		if old_room == room_id and old_pos.distance_to(position) < 0.001:
			return
		
		print("警告：检查点 ID 重复：", checkpoint_id,
			  "，旧房间:", old_room,
			  "，新房间:", room_id,
			  "（旧位置:", old_pos, "，新位置:", position, "）")
	
	checkpoints[checkpoint_id] = position
	checkpoint_rooms[checkpoint_id] = room_id

## 设置当前检查点（移除优先级参数）
func set_current_checkpoint(id: int, current_room: String):
	# 检查检查点是否属于当前房间
	var checkpoint_room = checkpoint_rooms.get(id, "")
	
	if checkpoint_room != "" and checkpoint_room != current_room:
		print("错误：尝试激活不属于当前房间的检查点")
		print("  检查点 ID:", id, "所属房间:", checkpoint_room, "当前房间:", current_room)
		return
	
	# 关键修复：无条件更新当前检查点并通知 Global
	current_checkpoint_id = id
	current_checkpoint_room = checkpoint_room
	
	# 立即通知 Global 更新最后检查点
	Global.set_dynamic_checkpoint(checkpoints.get(id, Vector2.ZERO))

## 获取当前检查点位置（检查房间归属）
func get_current_checkpoint_position(check_room: String = "") -> Vector2:
	if current_checkpoint_id == -1:
		print("无动态检查点，返回默认位置")
		return Vector2.ZERO
	
	# 检查当前检查点是否属于指定房间
	if check_room != "":
		var checkpoint_room = checkpoint_rooms.get(current_checkpoint_id, "")
		if checkpoint_room != "" and checkpoint_room != check_room:
			print("当前检查点", current_checkpoint_id, "属于房间", checkpoint_room, 
				  "，请求房间为", check_room, "，返回默认位置")
			return Vector2.ZERO
	
	return checkpoints.get(current_checkpoint_id, Vector2.ZERO)

## 新增：房间切换时清除动态检查点记录
func on_room_changed(new_room_id: String):
	# 关键修复：总是清除当前激活的检查点
	if current_checkpoint_id != -1:
		print("清除动态检查点激活：ID=", current_checkpoint_id, 
			  "新房间:", new_room_id)
		
		current_checkpoint_id = -1
		current_checkpoint_room = ""
		
		# 同时清除 Global 的动态检查点记录
		Global.clear_dynamic_checkpoints()

## 玩家死亡时清除所有动态检查点记录
func clear_all_checkpoints_on_death():
	# 重置当前激活的检查点
	current_checkpoint_id = -1
	current_checkpoint_room = ""
	
	# 同时清除 Global 的动态检查点记录
	Global.clear_dynamic_checkpoints()
