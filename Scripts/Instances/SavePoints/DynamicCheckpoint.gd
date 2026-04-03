# DynamicCheckpoint.gd - 简化版本（移除优先级）
extends Area2D
## 检查点唯一 ID
@export var checkpoint_id: int = 0  
## 所属房间 ID（必须填写）
@export var belongs_to_room: String = ""  

func _ready():
	# 检查必填字段
	if checkpoint_id == 0:
		print("错误：检查点必须设置 checkpoint_id（不能为 0）")
	
	if belongs_to_room == "":
		# 尝试自动获取所属房间
		determine_belongs_to_room()
		if belongs_to_room == "":
			print("严重错误：检查点", checkpoint_id, "无法确定所属房间，请手动设置 belongs_to_room")
	
	connect("body_entered", _on_body_entered)
	
	# 注册到 DynamicCheckpointManager（移除优先级参数）
	DynamicCheckpointManager.register_checkpoint(checkpoint_id, global_position, belongs_to_room)

## 确定检查点所属房间
func determine_belongs_to_room():
	if belongs_to_room != "":
		return  # 已经设置了
	
	# 向上查找房间节点
	var parent = get_parent()
	var depth = 0
	while parent and depth < 10:  # 防止无限循环
		if parent.has_method("get_room_data"):
			var room_data = parent.get_room_data()
			belongs_to_room = room_data["id"]
			print("自动确定检查点", checkpoint_id, "所属房间:", belongs_to_room)
			return
		parent = parent.get_parent()
		depth += 1
	print("警告：无法自动确定检查点", checkpoint_id, "的所属房间")

func _on_body_entered(body):
	if body.is_in_group("player"):
		# 获取当前房间 ID
		var current_room = RoomManager.current_room
		
		# 检查检查点是否属于当前房间
		if belongs_to_room != "" and belongs_to_room != current_room:
			print("检查点", checkpoint_id, "属于房间", belongs_to_room, 
				  "，当前房间为", current_room, "，忽略激活")
			return
		
		# 通知 DynamicCheckpointManager 激活检查点（移除优先级参数）
		DynamicCheckpointManager.set_current_checkpoint(checkpoint_id, current_room)
