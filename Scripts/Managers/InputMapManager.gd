# InputMapManager.gd
extends Node

## 输入映射管理器（自动加载单例）
const INPUT_MAP_PATH = "user://input_map.json"

## 默认动作映射：动作名 -> 显示名
var default_actions = {
	"left": "向左",      # 对应左方向键
	"right": "向右",     # 对应右方向键
	"up": "向上",        # 对应上方向键
	"down": "向下",      # 对应下方向键
	"jump": "跳跃",          # 对应跳跃键
	"dash": "冲刺",          # 对应冲刺键
	"super_dash": "超级冲刺", # 对应超级冲刺键
	"interactive": "交互",      # 对应交互键
	"dialogue_next": "继续对话" # 对应对话继续键
}

## 当前正在重新映射的动作
var current_remapping_action: String = ""
## 是否正在等待输入
var is_waiting_for_input: bool = false

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_custom_input_map()

## 获取动作显示名
func get_action_display_name(action: String) -> String:
	return default_actions.get(action, action)

## 保存输入映射
func save_custom_input_map():
	var data = {}
	for action in default_actions.keys():
		var events = []
		for event in InputMap.action_get_events(action):
			if event is InputEventKey:
				events.append(_event_to_dict(event))
		data[action] = events
	
	var file = FileAccess.open(INPUT_MAP_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()

## 加载输入映射
func load_custom_input_map():
	if not FileAccess.file_exists(INPUT_MAP_PATH):
		return
	
	var file = FileAccess.open(INPUT_MAP_PATH, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		var json = JSON.new()
		if json.parse(json_string) == OK:
			var data = json.data
			for action in data.keys():
				if InputMap.has_action(action):
					_clear_action_keyboard_events(action)
					for event_dict in data[action]:
						var event = _dict_to_event(event_dict)
						if event:
							InputMap.action_add_event(action, event)

## 清除动作的键盘事件
func _clear_action_keyboard_events(action: String):
	var events = InputMap.action_get_events(action)
	for event in events:
		if event is InputEventKey:
			InputMap.action_erase_event(action, event)

## 开始重新映射
func start_remap_action(action: String):
	if is_waiting_for_input:
		return
	
	current_remapping_action = action
	is_waiting_for_input = true

## 取消重新映射
func cancel_remap():
	current_remapping_action = ""
	is_waiting_for_input = false

## 切换到新的映射动作
func switch_remap_action(new_action: String):
	if is_waiting_for_input:
		current_remapping_action = new_action
		return true
	return false

## 处理重新映射输入
func handle_remap_input(event: InputEvent) -> bool:
	if not is_waiting_for_input or current_remapping_action == "":
		return false
	
	if not event.is_pressed() or event.is_echo():
		return false
	
	if not event is InputEventKey:
		return false
	
	# ESC取消
	if event.keycode == KEY_ESCAPE:
		cancel_remap()
		return true
	
	# 查找冲突
	var conflict_action = _find_keyboard_conflict(event, current_remapping_action)
	
	if conflict_action != "":
		# 交换按键
		_swap_keyboard_actions(current_remapping_action, conflict_action, event)
	else:
		# 直接映射
		_remap_action_key(current_remapping_action, event)
	
	# 完成映射
	current_remapping_action = ""
	is_waiting_for_input = false
	
	return true

## 查找键盘冲突
func _find_keyboard_conflict(event: InputEventKey, exclude_action: String) -> String:
	# 获取两种可能的键码
	var target_keycode = event.keycode
	var target_physical_keycode = event.physical_keycode
	
	# 遍历所有动作
	for action in default_actions.keys():
		if action == exclude_action:
			continue
		
		# 遍历该动作的所有事件
		for existing_event in InputMap.action_get_events(action):
			if existing_event is InputEventKey:
				# 关键修复：同时检查两种键码
				var is_same_keycode = (existing_event.keycode != 0 and 
									   existing_event.keycode == target_keycode)
				var is_same_physical = (existing_event.physical_keycode != 0 and 
										existing_event.physical_keycode == target_physical_keycode)
				
				# 如果任一键码匹配，即为冲突
				if is_same_keycode or is_same_physical:
					return action
	
	return ""

## 判断两个按键事件是否相同
func _is_same_key_event(event1: InputEventKey, event2: InputEventKey) -> bool:
	# 比较两种键码
	if event1.keycode != 0 and event1.keycode == event2.keycode:
		return true
	if event1.physical_keycode != 0 and event1.physical_keycode == event2.physical_keycode:
		return true
	return false

## 获取动作的主要键盘事件（第一个键盘按键）
func _get_main_keyboard_event(action: String) -> InputEventKey:
	var events = InputMap.action_get_events(action)
	for event in events:
		if event is InputEventKey:
			return event
	return null

## 交换按键
func _swap_keyboard_actions(action1: String, action2: String, new_key_event: InputEventKey):
	# 获取两个动作的当前主要键盘事件
	var action1_current = _get_main_keyboard_event(action1)
	var action2_current = _get_main_keyboard_event(action2)
	
	# 关键：如果action2没有键盘按键，直接映射
	if not action2_current:
		_remap_action_key(action1, new_key_event)
		return
	
	# 清除两个动作的所有键盘按键
	_clear_action_keyboard_events(action1)
	_clear_action_keyboard_events(action2)
	
	# 正确交换逻辑：
	InputMap.action_add_event(action1, new_key_event)
	InputMap.action_add_event(action2, action1_current)
	
	# 保存
	save_custom_input_map()

## 重新映射按键（添加检查）
func _remap_action_key(action: String, new_key_event: InputEventKey):
	# 检查是否已经有相同按键
	var current_events = InputMap.action_get_events(action)
	for event in current_events:
		if event is InputEventKey and _is_same_key_event(event, new_key_event):
			return
	
	# 清除所有键盘按键
	_clear_action_keyboard_events(action)
	
	# 添加新按键
	InputMap.action_add_event(action, new_key_event)
	save_custom_input_map()

## 获取按键显示文本
func get_action_key_display(action: String) -> String:
	if not InputMap.has_action(action):
		return "未设置"
	
	var events = InputMap.action_get_events(action)
	for event in events:
		if event is InputEventKey:
			return event.as_text()
	
	return "未设置"

## 重置到默认
func reset_to_default() -> bool:
	if FileAccess.file_exists(INPUT_MAP_PATH):
		DirAccess.remove_absolute(INPUT_MAP_PATH)
	
	InputMap.load_from_project_settings()
	return true

## 检查是否正在重新映射
func is_remapping() -> bool:
	return is_waiting_for_input

## 事件转字典
func _event_to_dict(event: InputEventKey) -> Dictionary:
	return {
		"class": "InputEventKey",
		"keycode": event.keycode,
		"physical_keycode": event.physical_keycode,
		"shift": event.shift_pressed,
		"ctrl": event.ctrl_pressed,
		"alt": event.alt_pressed,
		"meta": event.meta_pressed
	}

## 字典转事件
func _dict_to_event(dict: Dictionary) -> InputEventKey:
	if dict.get("class") != "InputEventKey":
		return null
	
	var event = InputEventKey.new()
	event.keycode = dict.get("keycode", 0)
	event.physical_keycode = dict.get("physical_keycode", 0)
	event.shift_pressed = dict.get("shift", false)
	event.ctrl_pressed = dict.get("ctrl", false)
	event.alt_pressed = dict.get("alt", false)
	event.meta_pressed = dict.get("meta", false)
	
	return event
