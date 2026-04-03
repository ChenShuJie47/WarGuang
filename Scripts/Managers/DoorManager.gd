# DoorManager.gd
extends Node

## 存储所有注册的门，按door_id分组
var doors_by_id: Dictionary = {}  # door_id -> Array[Door]

# 注册门
func register_door(door: Node):
	if door.door_id == "":
		push_error("严重错误：门的 door_id 为空！路径：" + str(door.get_path()))
		door.set_process(false)
		door.set_physics_process(false)
		return
	
	if not doors_by_id.has(door.door_id):
		doors_by_id[door.door_id] = []
	
	doors_by_id[door.door_id].append(door)
	
	# 检查数量
	var door_count = doors_by_id[door.door_id].size()
	if door_count > 2:
		push_error("严重错误：door_id='" + door.door_id + "'的门数量超过 2 个（当前：" + str(door_count) + "个）！已禁用该 ID 的传送功能")
		print("  当前门列表:")
		for i in range(door_count):
			var d = doors_by_id[door.door_id][i]
			if is_instance_valid(d):
				print("    [", i, "] ", str(d.get_path()), " (世界坐标:", d.global_position, ")")
		disable_door_id(door.door_id)
	else:
		# 不输出警告，减少噪音
		pass

## 禁用一个 door_id 的所有门
func disable_door_id(door_id: String):
	if doors_by_id.has(door_id):
		# 创建副本避免在迭代时修改
		var door_list = doors_by_id[door_id].duplicate()
		
		for door in door_list:
			# 检查实例是否有效
			if is_instance_valid(door):
				if door.has_method("disable_teleport"):
					door.disable_teleport()

## 注销一个门（当门被销毁时调用）
func unregister_door(door: Node):
	if door.door_id == "":
		return
	
	if not doors_by_id.has(door.door_id):
		return
	
	var door_list = doors_by_id[door.door_id]
	var index = door_list.find(door)
	if index != -1:
		door_list.remove_at(index)
		# 如果列表为空，删除这个 key
		if door_list.size() == 0:
			doors_by_id.erase(door.door_id)

## 检查并报告重复或孤立的门
func check_door_pairings():
	var has_errors = false
	
	for door_id in doors_by_id:
		var door_list = doors_by_id[door_id]
		var door_count = door_list.size()
		
		if door_count == 1:
			print("⚠ 警告：door_id='", door_id, "' 只有一个门：", str(door_list[0].get_path()))
			has_errors = true
		elif door_count == 2:
			if is_instance_valid(door_list[0]) and is_instance_valid(door_list[1]):
				pass
		else:
			print("⚠ 警告：door_id='", door_id, "' 的门数量超过 2 个（当前：", door_count, " 个）")
			for i in range(door_list.size()):
				print("  [", i, "] ", str(door_list[i].get_path()))
			has_errors = true
	
	if not has_errors:
		print("✓ 所有门都已正确配对")

func find_other_door(current_door: Node) -> Node:
	var door_id = current_door.door_id
	if door_id == "":
		return null
	
	var door_list = doors_by_id.get(door_id, [])
	
	# 清理无效实例
	door_list = door_list.filter(func(door): return is_instance_valid(door))
	doors_by_id[door_id] = door_list
	
	if door_list.size() != 2:
		return null
	
	for door in door_list:
		if door != current_door and is_instance_valid(door):
			return door
	
	return null

## 获取门的配对状态
func get_door_status(door_id: String) -> Dictionary:
	var door_list = doors_by_id.get(door_id, [])
	return {
		"count": door_list.size(),
		"valid": door_list.size() == 2
	}

## 禁用特定 ID 的门的传送功能
func disable_door_teleport(door_id: String):
	if not doors_by_id.has(door_id):
		return
	
	var door_list = doors_by_id[door_id]
	for door in door_list:
		if is_instance_valid(door) and door.has_method("disable_teleport"):
			door.disable_teleport()

## 清理所有门注册（用于从标题重新进入游戏时）
func clear_all_doors():
	doors_by_id.clear()

## 清理无效的门实例
func cleanup_invalid_doors():
	for door_id in doors_by_id:
		var door_list = doors_by_id[door_id]
		# 过滤掉无效实例
		var valid_doors = door_list.filter(func(d): return is_instance_valid(d))
		doors_by_id[door_id] = valid_doors

## 获取所有已配对的门（用于自动计算房间连接）
func get_all_paired_doors() -> Array:
	var paired_doors = []
	
	for door_id in doors_by_id:
		var doors = doors_by_id[door_id]
		if doors.size() == 2:
			var door_a = doors[0]
			var door_b = doors[1]
			
			# 确保两个门实例都有效
			if is_instance_valid(door_a) and is_instance_valid(door_b):
				paired_doors.append({
					"door_id": door_id,
					"door_a": door_a,
					"door_b": door_b
				})
	
	return paired_doors
