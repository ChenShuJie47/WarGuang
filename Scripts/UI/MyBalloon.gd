class_name MyDialogueBalloon
extends CanvasLayer

@export var next_action: StringName = &"dialogue_next"  # 空格键
@export var skip_action: StringName = &"ui_cancel"

var resource: DialogueResource
var temporary_game_states: Array = []
var is_waiting_for_input: bool = false
var is_blocking_input: bool = false  # 是否正在阻断输入（转场时）

var dialogue_line: DialogueLine:
	set(value):
		if value:
			dialogue_line = value
			apply_dialogue_line()
		else:
			DialogueSystem.end_dialogue()
			queue_free()
	get:
		return dialogue_line

@onready var balloon: Control = %Balloon
@onready var character_label: RichTextLabel = %CharacterLabel
@onready var dialogue_label: DialogueLabel = %DialogueLabel
@onready var responses_menu: DialogueResponsesMenu = %ResponsesMenu

# 渐黑渐显相关
var fade_manager: Node = null

func _ready() -> void:
	balloon.hide()
	# 设置层级比设置界面低
	layer = 90  # 设置界面是 100，对话框设为 90
	
	# 关键修复：气球本身设置为 IGNORE，让事件穿透
	balloon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# 关键修复：只设置非 ResponsesMenu 的子节点为 IGNORE
	_set_mouse_filter_excluding_responses(balloon, Control.MOUSE_FILTER_IGNORE)
	
	# ResponsesMenu 需要接收事件
	if responses_menu:
		responses_menu.mouse_filter = Control.MOUSE_FILTER_STOP
		responses_menu.focus_mode = Control.FOCUS_ALL
		
		# 连接效果信号
		if DialogueSystem.has_signal("effect_triggered"):
			DialogueSystem.effect_triggered.connect(_on_effect_triggered)
		
		# 手动连接 response_selected 信号
		if not responses_menu.response_selected.is_connected(_on_response_selected):
			responses_menu.response_selected.connect(_on_response_selected)
	
	# 获取 FadeManager
	fade_manager = get_node_or_null("/root/FadeManager")

## 递归设置所有子节点的 mouse_filter（排除 ResponsesMenu）
func _set_mouse_filter_excluding_responses(node: Node, filter: int):
	if node is Control and node != responses_menu:
		node.mouse_filter = filter
	for child in node.get_children():
		_set_mouse_filter_excluding_responses(child, filter)

func apply_dialogue_line() -> void:
	is_waiting_for_input = false
	
	# 转场后不立即显示对话框
	if not is_blocking_input:
		balloon.show()
	else:
		balloon.hide()
	
	# 确保正确设置焦点模式
	balloon.focus_mode = Control.FOCUS_ALL
	if responses_menu:
		responses_menu.focus_mode = Control.FOCUS_ALL
	
	# 设置选项菜单的 next_action
	if responses_menu:
		responses_menu.next_action = next_action
	
	# 延迟一帧确保节点已完全添加到场景树
	await get_tree().process_frame
	
	character_label.visible = not dialogue_line.character.is_empty()
	character_label.text = tr(dialogue_line.character, "dialogue") if character_label.visible else ""

	dialogue_label.dialogue_line = dialogue_line

	if responses_menu:
		responses_menu.hide()
		responses_menu.responses = dialogue_line.responses
		
	# 转场后不显示文字
	if not is_blocking_input:
		dialogue_label.show()
		
		if not dialogue_line.text.is_empty():
			dialogue_label.type_out()
			await dialogue_label.finished_typing

	# 关键修复：根据是否有选项创建/移除 ClickArea
	if dialogue_line.responses.size() > 0:
		# 有选项时：降低层级，移除 ClickArea（如果有）
		layer = 0
		
		var click_area = balloon.get_node_or_null("ClickArea")
		if click_area:
			click_area.queue_free()
		
		# 确保 ResponsesMenu 和它的所有子节点都能接收鼠标事件
		if responses_menu:
			responses_menu.mouse_filter = Control.MOUSE_FILTER_STOP
			_set_mouse_filter_recursive(responses_menu, Control.MOUSE_FILTER_STOP)
		
		if responses_menu:
			await get_tree().process_frame
			await get_tree().process_frame
			
			responses_menu.show()
			
			var menu_items = responses_menu.get_menu_items()
			if menu_items.size() > 0:
				menu_items[0].grab_focus()
			
	else:
		# 没有选项时：恢复高层级
		layer = 90
		
		# 关键修复：总是创建 ClickArea（用于继续对话）
		if not balloon.has_node("ClickArea"):
			var click_area = ColorRect.new()
			click_area.name = "ClickArea"
			click_area.color = Color(0, 0, 0, 0)
			click_area.mouse_filter = Control.MOUSE_FILTER_STOP
			click_area.set_anchors_preset(Control.PRESET_FULL_RECT)
			balloon.add_child(click_area)
			click_area.gui_input.connect(_on_click_area_input)
		
		if dialogue_line.time != "":
			var time = dialogue_line.text.length() * 0.02 if dialogue_line.time == "auto" else dialogue_line.time.to_float()
			await get_tree().create_timer(time).timeout
			next(dialogue_line.next_id)
		else:
			is_waiting_for_input = true

## 递归设置所有子节点的 mouse_filter
func _set_mouse_filter_recursive(node: Node, filter: int):
	if node is Control:
		node.mouse_filter = filter
	for child in node.get_children():
		_set_mouse_filter_recursive(child, filter)

## 处理点击区域输入
func _on_click_area_input(event):
	# 只有在没有选项时才处理点击（继续对话）
	if dialogue_line.responses.size() == 0 and is_waiting_for_input:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			next(dialogue_line.next_id)
			get_viewport().set_input_as_handled()

func _unhandled_input(event):
	# 如果正在阻断输入（转场中），不处理任何输入
	if is_blocking_input:
		return
	
	# 修复：检查 dialogue_line 是否为 null
	if not dialogue_line:
		return
	
	# 只在等待输入时处理空格键（没有响应选项时）
	if event.is_action_pressed(next_action) and is_waiting_for_input and dialogue_line.responses.size() == 0:
		next(dialogue_line.next_id)
		get_viewport().set_input_as_handled()
	
	# 处理选项选择 - 允许在选项显示时使用 A/D 键和空格键
	if dialogue_line.responses.size() > 0 and responses_menu and responses_menu.visible:
		# 处理 A/D 键导航（左右切换）
		if event.is_action_pressed("left") or event.is_action_pressed("ui_left"):
			_navigate_options(-1)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("right") or event.is_action_pressed("ui_right"):
			_navigate_options(1)
			get_viewport().set_input_as_handled()

func _on_response_selected(response: DialogueResponse):
	next(response.next_id)

# 关键修复：恢复气球 GUI 输入处理，但正确判断是否应该处理
func _on_balloon_gui_input(event):
	# 如果正在阻断输入（转场中），不处理任何输入
	if is_blocking_input:
		return
	
	# 修复：检查 dialogue_line 是否为 null
	if not dialogue_line:
		return
	
	# 只有在没有选项时才处理气球点击（继续对话）
	if dialogue_line.responses.size() == 0 and is_waiting_for_input:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			next(dialogue_line.next_id)
			get_viewport().set_input_as_handled()
	# 关键修复：在有选项时完全不处理，让事件自然传递给子节点
	# 不要调用 get_viewport().set_input_as_handled()

func start(dialogue_resource: DialogueResource, title: String, extra_game_states: Array = []) -> void:
	DialogueSystem.start_dialogue()
	
	temporary_game_states = extra_game_states.duplicate()
	temporary_game_states.append(self)
	resource = dialogue_resource
	
	self.dialogue_line = await resource.get_next_dialogue_line(title, temporary_game_states)

func next(next_id: String) -> void:
	if next_id == "END" or next_id.is_empty():
		self.dialogue_line = null
		return
	
	self.dialogue_line = await resource.get_next_dialogue_line(next_id, temporary_game_states)

func _on_effect_triggered(effect_name: String):
	match effect_name:
		"fade_memory":
			await _perform_fade_effect()

## 执行渐黑渐显效果（使用 FadeManager）
func _perform_fade_effect():
	if not fade_manager:
		await _perform_fade_fallback()
		return
	
	# 关键修复：阻断输入并隐藏对话框
	is_blocking_input = true
	balloon.hide()
	
	# 使用 FadeManager 实现渐黑渐显
	if fade_manager.has_method("fade_out") and fade_manager.has_method("fade_in"):
		# 渐黑
		await fade_manager.fade_out(1.0)
		# 短暂停留
		await get_tree().create_timer(0.5).timeout
		# 渐显
		await fade_manager.fade_in(1.0)
	else:
		await _perform_fade_fallback()
	
	# 恢复对话框显示但不显示文字，等待玩家点击
	balloon.show()
	is_blocking_input = false
	
	# 强制刷新当前对话行（不自动显示文字）
	self.dialogue_line = await resource.get_next_dialogue_line(dialogue_line.next_id, temporary_game_states)

## 备用渐黑渐显方案（如果 FadeManager 不存在）
func _perform_fade_fallback():
	# 阻断输入并隐藏对话框
	is_blocking_input = true
	balloon.hide()
	
	var fade_overlay = ColorRect.new()
	fade_overlay.name = "FadeOverlay"
	fade_overlay.anchor_right = 1.0
	fade_overlay.anchor_bottom = 1.0
	fade_overlay.color = Color(0, 0, 0, 0)
	add_child(fade_overlay)
	fade_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	# 渐黑（0 → 1）
	var tween = create_tween()
	tween.tween_property(fade_overlay, "color:a", 1.0, 1.0).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	
	# 短暂停留
	await get_tree().create_timer(0.5).timeout
	
	# 渐显（1 → 0）
	tween = create_tween()
	tween.tween_property(fade_overlay, "color:a", 0.0, 1.0).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	
	fade_overlay.queue_free()
	
	# 恢复对话框显示和输入
	balloon.show()
	is_blocking_input = false

## 导航选项（A/D 键切换）
func _navigate_options(direction: int):
	if not responses_menu or not responses_menu.visible:
		return
	
	var menu_items = responses_menu.get_menu_items()
	if menu_items.size() == 0:
		return
	
	# 找到当前聚焦的选项
	var current_index = -1
	for i in range(menu_items.size()):
		if menu_items[i] == get_viewport().gui_get_focus_owner():
			current_index = i
			break
	
	# 如果当前没有聚焦，聚焦第一个
	if current_index == -1:
		menu_items[0].grab_focus()
		return
	
	# 计算下一个索引（循环）
	var next_index = (current_index + direction) % menu_items.size()
	if next_index < 0:
		next_index = menu_items.size() - 1
	
	menu_items[next_index].grab_focus()
