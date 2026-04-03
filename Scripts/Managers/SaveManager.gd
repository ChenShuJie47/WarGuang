extends Node

const SAVE_PATH = "user://saves/"

func save_game(slot_index: int, data: Dictionary):
	var file_path = SAVE_PATH + "save_" + str(slot_index) + ".dat"
	var tmp_path = file_path + ".tmp"
	
	var dir = DirAccess.open("user://")
	if not dir.dir_exists(SAVE_PATH):
		dir.make_dir(SAVE_PATH)
	
	# 先序列化为 JSON
	var json_string = JSON.stringify(data)

	# 写入到 tmp，成功后再替换最终文件（降低半写入风险）
	DirAccess.remove_absolute(tmp_path) # best effort
	var tmp_file = FileAccess.open(tmp_path, FileAccess.WRITE)
	if not tmp_file:
		print("存档失败(无法写 tmp)：", tmp_path)
		return false
	
	tmp_file.store_string(json_string)
	tmp_file.close()
	
	# 基础校验：tmp 中的内容至少是可解析 JSON（使用内存中的 json_string）
	var json := JSON.new()
	if json.parse(json_string) != OK:
		print("存档失败(JSON 序列化不可解析)：", file_path)
		DirAccess.remove_absolute(tmp_path) # best effort
		return false
	
	# 替换最终文件
	DirAccess.remove_absolute(file_path) # best effort
	var rename_err = DirAccess.rename_absolute(tmp_path, file_path)
	if rename_err != OK:
		# 回退方案：如果 rename 失败，就直接写最终文件，然后删除 tmp
		var final_file = FileAccess.open(file_path, FileAccess.WRITE)
		if not final_file:
			print("存档失败(无法替换最终文件)：", file_path, " rename_err=", rename_err)
			return false
		final_file.store_string(json_string)
		final_file.close()
		DirAccess.remove_absolute(tmp_path) # best effort
	
	if not FileAccess.file_exists(file_path):
		print("存档失败(最终文件不存在)：", file_path)
		return false
	
	print("存档成功：", file_path)
	
	# 修复：存档成功后显示"存档已更新"提示
	call_deferred("_show_save_notification")
	
	return true

func _show_save_notification():
	var player_ui = get_tree().get_first_node_in_group("player_ui")
	if player_ui and player_ui.has_method("show_save_label"):
		player_ui.show_save_label()

func load_game(slot_index: int) -> Dictionary:
	var file_path = SAVE_PATH + "save_" + str(slot_index) + ".dat"
	
	if not FileAccess.file_exists(file_path):
		return {}
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		if parse_result == OK and typeof(json.data) == TYPE_DICTIONARY:
			return json.data as Dictionary
		else:
			print("JSON解析失败: ", json_string)
			return {}
	else:
		print("读取存档失败: ", file_path)
		return {}

func delete_save(slot_index: int) -> bool:
	var file_path = SAVE_PATH + "save_" + str(slot_index) + ".dat"
	var tmp_path = file_path + ".tmp"
	if not FileAccess.file_exists(file_path):
		# 如果最终文件不存在但 tmp 还在，也算“未彻底删除”
		if FileAccess.file_exists(tmp_path):
			DirAccess.remove_absolute(tmp_path)
		return !FileAccess.file_exists(tmp_path)

	DirAccess.remove_absolute(file_path)
	DirAccess.remove_absolute(tmp_path) # best effort

	# 关键：以“删除后是否仍存在”作为成功判定
	if FileAccess.file_exists(file_path) or FileAccess.file_exists(tmp_path):
		print("删除存档失败(文件仍存在): ", file_path, " tmp=", tmp_path)
		return false

	print("删除存档成功: ", file_path)
	return true

func save_exists(slot_index: int) -> bool:
	var file_path = SAVE_PATH + "save_" + str(slot_index) + ".dat"
	return FileAccess.file_exists(file_path)

func get_save_info(slot_index: int) -> Dictionary:
	var data = load_game(slot_index)
	if data.is_empty():
		return {"exists": false}
	
	return {
		"exists": true,
		"player_max_health": data.get("player_max_health", 3),
		"player_coins": data.get("player_coins", 0),
		"timestamp": data.get("timestamp", "")
	}
