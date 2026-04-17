extends CanvasLayer  # 修复：改为 CanvasLayer

## 删除确认对话框场景（在 Inspector 中拖拽 DeleteConfirmDialog.tscn）
@export var delete_confirm_scene: PackedScene

class SaveData:
	var exists: bool = false
	var player_max_health: int = 3
	var coins: int = 0
	var last_save_room: String = "Room1"
	var play_time_seconds: int = 0
	var timestamp: String = ""

var save_slots = []  ## 存档槽数据数组，存储每个槽位的存档信息
var delete_button_connections = []  ## 删除按钮连接状态数组，记录每个删除按钮是否已连接信号
var is_dialog_open: bool = false  ## 删除确认对话框是否打开状态

var _scene_input_locked: bool = true

@export_category("SaveSlot 交互反馈")
@export var slot_hover_offset_y: float = 8.0
@export var slot_hover_duration: float = 0.08
@export var slot_hover_outline_width: int = 2
@export var slot_hover_outline_color: Color = Color(1, 1, 1, 1)

@export_category("SaveSlot 填充纹理按区域映射")
## 按房间ID配置填充纹理，点击数组右侧 + 新增元素，元素类型选 SaveSlotRoomTextureBinding，再拖拽纹理。
@export var room_filled_texture_bindings: Array[SaveSlotRoomTextureBinding] = []

@onready var ui_transition_animator: UITransitionAnimator = $UITransitionAnimator

@onready var save_slot_buttons = [
	$SaveSlot1,
	$SaveSlot2, 
	$SaveSlot3
]

@onready var play_time_labels = [
	$SaveSlot1/PlayTimeLabel,
	$SaveSlot2/PlayTimeLabel,
	$SaveSlot3/PlayTimeLabel
]

var _slot_base_positions: Array[Vector2] = []
var _slot_empty_base_positions: Array[Vector2] = []
var _slot_filled_base_positions: Array[Vector2] = []
var _slot_tweens: Array[Tween] = []
var _slot_outlines: Array[Panel] = []
## 房间ID到纹理的运行时查询表
var _room_texture_lookup: Dictionary = {}

## 初始化存档选择场景
func _ready():
	delete_button_connections.resize(3)
	for i in range(3):
		delete_button_connections[i] = false
	
	_load_save_data()
	_rebuild_room_texture_lookup()
	_cache_slot_transforms()
	_connect_signals()
	_update_slot_display()
	_set_scene_input_locked(true)
	if ui_transition_animator:
		ui_transition_animator.reset_state()
	
	$BackButton.pressed.connect(_on_back_button_pressed)
	if not ui_transition_animator:
		FadeManager.fade_in(FadeManager.ui_overlay_fast_fade_duration)
		_set_scene_input_locked(false)
	else:
		if FadeManager and FadeManager.has_method("get_black_alpha") and FadeManager.get_black_alpha() <= 0.01:
			call_deferred("_on_scene_transition_enter_begin")
	
	await get_tree().create_timer(0.1).timeout
	
	## 修改：调用LightingManager的统一函数
	LightingManager.setup_ui_breathing_effect(self)

## 加载存档数据
## 读取所有存档槽的数据
func _load_save_data():
	save_slots = []
	for i in range(3):
		var save_data = SaveData.new()
		var save_info = SaveManager.get_save_info(i)
		save_data.exists = save_info.get("exists", false)
		if save_data.exists:
			save_data.player_max_health = save_info.get("player_max_health", 3)
			save_data.coins = save_info.get("player_coins", 0)
			save_data.last_save_room = save_info.get("last_save_room", "Room1")
			save_data.play_time_seconds = int(save_info.get("play_time_seconds", 0))
			save_data.timestamp = save_info.get("timestamp", "")
		save_slots.append(save_data)

## 缓存存档槽基准位置
func _cache_slot_transforms() -> void:
	_slot_base_positions.clear()
	_slot_empty_base_positions.clear()
	_slot_filled_base_positions.clear()
	_slot_tweens.clear()
	_slot_outlines.clear()
	for slot_button in save_slot_buttons:
		_slot_base_positions.append(slot_button.position)
		_slot_empty_base_positions.append(slot_button.get_node("EmptySlot").position)
		_slot_filled_base_positions.append(slot_button.get_node("FilledSlot").position)
		_slot_tweens.append(null)
		_slot_outlines.append(_ensure_slot_outline(slot_button))

## 确保 SaveSlot 拥有可复用的白色描边面板
func _ensure_slot_outline(slot_button: TextureButton) -> Panel:
	var outline: Panel = slot_button.get_node_or_null("HoverOutline") as Panel
	if outline == null:
		outline = Panel.new()
		outline.name = "HoverOutline"
		slot_button.add_child(outline)

	outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outline.focus_mode = Control.FOCUS_NONE
	outline.z_index = 20
	outline.layout_mode = 0
	outline.anchor_left = 0.0
	outline.anchor_top = 0.0
	outline.anchor_right = 1.0
	outline.anchor_bottom = 1.0
	outline.offset_left = 0.0
	outline.offset_top = 0.0
	outline.offset_right = 0.0
	outline.offset_bottom = 0.0

	var border_style := StyleBoxFlat.new()
	border_style.bg_color = Color(1, 1, 1, 0.0)
	border_style.border_color = slot_hover_outline_color
	border_style.border_width_left = slot_hover_outline_width
	border_style.border_width_top = slot_hover_outline_width
	border_style.border_width_right = slot_hover_outline_width
	border_style.border_width_bottom = slot_hover_outline_width
	outline.add_theme_stylebox_override("panel", border_style)
	outline.modulate = Color(1, 1, 1, 0.0)
	return outline

## 连接信号
## 连接存档槽相关信号
func _connect_signals():
	for i in range(3):
		var slot_button = save_slot_buttons[i]
		
		if slot_button.pressed.is_connected(_on_save_slot_pressed):
			slot_button.pressed.disconnect(_on_save_slot_pressed)
		
		slot_button.pressed.connect(_on_save_slot_pressed.bind(i))
		if slot_button.mouse_entered.is_connected(_on_save_slot_mouse_entered):
			slot_button.mouse_entered.disconnect(_on_save_slot_mouse_entered)
		if slot_button.mouse_exited.is_connected(_on_save_slot_mouse_exited):
			slot_button.mouse_exited.disconnect(_on_save_slot_mouse_exited)
		slot_button.mouse_entered.connect(_on_save_slot_mouse_entered.bind(i))
		slot_button.mouse_exited.connect(_on_save_slot_mouse_exited.bind(i))
		
		if not delete_button_connections[i]:
			var delete_button = slot_button.get_node("DeleteButton")
			
			if delete_button.pressed.is_connected(_on_delete_button_pressed):
				delete_button.pressed.disconnect(_on_delete_button_pressed)
			
			delete_button.pressed.connect(_on_delete_button_pressed.bind(i))
			delete_button_connections[i] = true

## 更新存档槽显示
## 刷新存档槽显示
func _update_slot_display():
	for i in range(3):
		var slot_button = save_slot_buttons[i]
		var save_data = save_slots[i]
		var filled_slot: Sprite2D = slot_button.get_node("FilledSlot")
		var play_time_label: Label = play_time_labels[i]
		
		slot_button.get_node("EmptySlot").visible = !save_data.exists
		filled_slot.visible = save_data.exists
		slot_button.get_node("DeleteButton").visible = save_data.exists
		if save_data.exists:
			filled_slot.texture = _resolve_filled_texture(i, save_data.last_save_room, filled_slot.texture)
			play_time_label.text = _format_play_time(save_data.play_time_seconds)
			play_time_label.visible = true
		else:
			play_time_label.visible = false

## 处理存档槽按钮按下
## 处理存档槽按下
func _on_save_slot_pressed(slot_index: int):
	if _scene_input_locked:
		return
	AudioManager.play_sfx("button_click")
	
	if is_dialog_open:
		return

	_set_scene_input_locked(true)
	if ui_transition_animator:
		await ui_transition_animator.play_exit_transition()
	
	await SceneManager.start_game_from_save(slot_index)

## 重建房间纹理映射缓存（运行时只做字典查询）
## 重建房间到纹理的查询表
func _rebuild_room_texture_lookup() -> void:
	_room_texture_lookup.clear()
	for binding in room_filled_texture_bindings:
		if binding == null:
			continue
		var key: String = binding.room_id.strip_edges()
		if key == "":
			continue
		if binding.filled_texture:
			_room_texture_lookup[key] = binding.filled_texture

## 按房间ID解析填充纹理
## 根据房间ID选择填充纹理
func _resolve_filled_texture(_slot_index: int, room_id: String, fallback: Texture2D) -> Texture2D:
	var key: String = room_id.strip_edges()
	if key != "" and _room_texture_lookup.has(key):
		var mapped: Variant = _room_texture_lookup.get(key)
		if mapped is Texture2D:
			return mapped
	return fallback

## 将秒数格式化为显示文本
func _format_play_time(total_seconds: int) -> String:
	var safe_seconds: int = max(0, total_seconds)
	var hours: int = int(safe_seconds / 3600.0)
	var minutes: int = int((safe_seconds % 3600) / 60.0)
	var seconds: int = safe_seconds % 60
	return "游戏时长 %02d:%02d:%02d" % [hours, minutes, seconds]

## 停止指定槽位的悬停动画
func _kill_slot_tween(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= _slot_tweens.size():
		return
	var tween: Tween = _slot_tweens[slot_index]
	if tween and tween.is_valid():
		tween.kill()
	_slot_tweens[slot_index] = null

## 处理存档槽悬停进入
func _on_save_slot_mouse_entered(slot_index: int) -> void:
	if _scene_input_locked or is_dialog_open:
		return
	var slot_button: TextureButton = save_slot_buttons[slot_index]
	var empty_slot: Sprite2D = slot_button.get_node("EmptySlot")
	var filled_slot: Sprite2D = slot_button.get_node("FilledSlot")
	var outline: Panel = _slot_outlines[slot_index]
	_kill_slot_tween(slot_index)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(empty_slot, "position:y", _slot_empty_base_positions[slot_index].y - slot_hover_offset_y, slot_hover_duration)
	tween.parallel().tween_property(filled_slot, "position:y", _slot_filled_base_positions[slot_index].y - slot_hover_offset_y, slot_hover_duration)
	tween.parallel().tween_property(outline, "modulate:a", 1.0, slot_hover_duration)
	_slot_tweens[slot_index] = tween

## 处理存档槽悬停离开
func _on_save_slot_mouse_exited(slot_index: int) -> void:
	var slot_button: TextureButton = save_slot_buttons[slot_index]
	var empty_slot: Sprite2D = slot_button.get_node("EmptySlot")
	var filled_slot: Sprite2D = slot_button.get_node("FilledSlot")
	var outline: Panel = _slot_outlines[slot_index]
	_kill_slot_tween(slot_index)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(empty_slot, "position", _slot_empty_base_positions[slot_index], slot_hover_duration)
	tween.parallel().tween_property(filled_slot, "position", _slot_filled_base_positions[slot_index], slot_hover_duration)
	tween.parallel().tween_property(outline, "modulate:a", 0.0, slot_hover_duration)
	_slot_tweens[slot_index] = tween

## 处理输入事件（新增ESC键初始冷却检查）
## 处理存档选择场景输入
func _input(event):
	if _scene_input_locked:
		if event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton:
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") and not is_dialog_open:
		_on_back_button_pressed()

## 处理删除按钮按下
func _on_delete_button_pressed(slot_index: int):
	if not delete_confirm_scene:
		push_error("SaveSelectScene: delete_confirm_scene 未配置！请在 Inspector 中拖拽 DeleteConfirmDialog.tscn")
		return
	
	LightingManager.dim_lights(0.0, 0.5)
	
	var confirm_dialog = delete_confirm_scene.instantiate()
	add_child(confirm_dialog)
	confirm_dialog.confirm_callback = _on_confirm_delete.bind(slot_index)
	confirm_dialog.tree_exited.connect(_on_dialog_closed)

## 设置所有按钮的启用状态
## 设置所有按钮的启用状态
func _set_buttons_enabled(enabled: bool):
	for slot_button in save_slot_buttons:
		slot_button.disabled = !enabled
	$BackButton.disabled = !enabled

## 处理对话框关闭
## 处理删除确认对话框关闭
func _on_dialog_closed():
	is_dialog_open = false
	_set_buttons_enabled(true)
	LightingManager.restore_lights(0.5)
	
	## 重新启用ESC键处理
	set_process_input(true)

## 确认删除存档
## 确认删除指定存档
func _on_confirm_delete(slot_index: int):
	if SaveManager.delete_save(slot_index):
		save_slots[slot_index].exists = false
		_update_slot_display()
		
		# 关键修复：如果删除的是当前存档，需要清空 Global 数据
		if slot_index == Global.current_save_slot:
			Global.destructible_walls_destroyed = []
			# 保险措施：避免后续逻辑把运行态数据再保存回已删除的槽位
			Global.current_save_slot = -1
			print("SaveSelectScene: 已清空当前存档的石墙摧毁记录")

## 处理返回按钮按下
## 处理返回按钮按下
func _on_back_button_pressed():
	if _scene_input_locked:
		return
	AudioManager.play_sfx("button_click")
	
	if is_dialog_open:
		return

	_set_scene_input_locked(true)
	if ui_transition_animator:
		await ui_transition_animator.play_exit_transition()
		
	LightingManager.stop_all_light_effects()
	await SceneManager.switch_scene(ScenePaths.UI_TITLE)

## 退出场景时停止灯光效果
## 退出场景时清理灯光
func _exit_tree():
	LightingManager.stop_all_light_effects()

## 查询当前交互锁状态
func is_scene_interaction_locked() -> bool:
	return _scene_input_locked

## 设置场景输入锁
func _set_scene_input_locked(locked: bool) -> void:
	_scene_input_locked = locked
	_set_buttons_enabled(not locked)

## 播放入场动画后解锁输入
func _on_scene_transition_enter_begin() -> void:
	_set_scene_input_locked(true)
	if ui_transition_animator:
		await ui_transition_animator.play_enter_transition()
	_set_scene_input_locked(false)
