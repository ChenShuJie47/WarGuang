extends CanvasLayer  # 修复：改为 CanvasLayer

## 删除确认对话框场景（在 Inspector 中拖拽 DeleteConfirmDialog.tscn）
@export var delete_confirm_scene: PackedScene

class SaveData:
	var exists: bool = false
	var player_max_health: int = 3
	var coins: int = 0
	var timestamp: String = ""

var save_slots = []  ## 存档槽数据数组，存储每个槽位的存档信息
var delete_button_connections = []  ## 删除按钮连接状态数组，记录每个删除按钮是否已连接信号
var is_dialog_open: bool = false  ## 删除确认对话框是否打开状态

var esc_cooldown: bool = false  ## ESC键防重复触发冷却状态
var esc_timer: Timer  ## ESC键防重复触发计时器
var esc_initial_cooldown: bool = true  ## ESC键初始冷却状态（新增：场景开始后0.1秒内不接受ESC输入）

@onready var save_slot_buttons = [
	$SaveSlot1,
	$SaveSlot2, 
	$SaveSlot3
]

func _ready():
	delete_button_connections.resize(3)
	for i in range(3):
		delete_button_connections[i] = false
	
	## 创建ESC冷却计时器（防止快速重复触发）
	esc_timer = Timer.new()
	esc_timer.wait_time = 0.1
	esc_timer.one_shot = true
	esc_timer.timeout.connect(_enable_esc)
	add_child(esc_timer)
	
	_load_save_data()
	_connect_signals()
	_update_slot_display()
	
	$BackButton.pressed.connect(_on_back_button_pressed)
	FadeManager.fade_in(0.1)
	
	await get_tree().create_timer(0.1).timeout
	
	## 修改：调用LightingManager的统一函数
	LightingManager.setup_ui_breathing_effect(self)
	
	## 新增：延迟0.1秒后启用ESC键（模拟SettingsScene的初始冷却机制）
	get_tree().create_timer(0.1).timeout.connect(_enable_initial_esc)

## 新增：启用初始ESC键输入
func _enable_initial_esc():
	esc_initial_cooldown = false

## 启用ESC键（用于防重复触发机制）
func _enable_esc():
	esc_cooldown = false

## 加载存档数据
func _load_save_data():
	save_slots = []
	for i in range(3):
		var save_data = SaveData.new()
		var save_info = SaveManager.get_save_info(i)
		save_data.exists = save_info.get("exists", false)
		if save_data.exists:
			save_data.player_max_health = save_info.get("player_max_health", 3)
			save_data.coins = save_info.get("player_coins", 0)
			save_data.timestamp = save_info.get("timestamp", "")
		save_slots.append(save_data)

## 连接信号
func _connect_signals():
	for i in range(3):
		var slot_button = save_slot_buttons[i]
		
		if slot_button.pressed.is_connected(_on_save_slot_pressed):
			slot_button.pressed.disconnect(_on_save_slot_pressed)
		
		slot_button.pressed.connect(_on_save_slot_pressed.bind(i))
		
		if not delete_button_connections[i]:
			var delete_button = slot_button.get_node("DeleteButton")
			
			if delete_button.pressed.is_connected(_on_delete_button_pressed):
				delete_button.pressed.disconnect(_on_delete_button_pressed)
			
			delete_button.pressed.connect(_on_delete_button_pressed.bind(i))
			delete_button_connections[i] = true

## 更新存档槽显示
func _update_slot_display():
	for i in range(3):
		var slot_button = save_slot_buttons[i]
		var save_data = save_slots[i]
		
		slot_button.get_node("EmptySlot").visible = !save_data.exists
		slot_button.get_node("FilledSlot").visible = save_data.exists
		slot_button.get_node("DeleteButton").visible = save_data.exists

## 处理存档槽按钮按下
func _on_save_slot_pressed(slot_index: int):
	AudioManager.play_sfx("button_click")
	
	if is_dialog_open:
		return
	
	var save_data = save_slots[slot_index]
	if save_data.exists:
		await SceneManager.start_game_from_save(slot_index, 1.5)
	else:
		Global.current_save_slot = slot_index
		Global.initialize_new_game()
		SaveManager.save_game(slot_index, Global.get_save_data())
		await SceneManager.switch_scene("res://Scenes/GameScenes/MainGameScene.tscn", 1.5)

## 处理输入事件（新增ESC键初始冷却检查）
func _input(event):
	if event.is_action_pressed("ui_cancel") and not esc_cooldown and not is_dialog_open:
		## 检查初始冷却状态
		if esc_initial_cooldown:
			print("SaveSelectScene: ESC键仍在初始冷却中")
			return
			
		esc_cooldown = true
		esc_timer.start()
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
func _set_buttons_enabled(enabled: bool):
	for slot_button in save_slot_buttons:
		slot_button.disabled = !enabled
	$BackButton.disabled = !enabled

## 处理对话框关闭
func _on_dialog_closed():
	is_dialog_open = false
	_set_buttons_enabled(true)
	LightingManager.restore_lights(0.5)
	
	## 重新启用ESC键处理
	set_process_input(true)

## 确认删除存档
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
func _on_back_button_pressed():
	AudioManager.play_sfx("button_click")
	
	if is_dialog_open:
		return
		
	LightingManager.stop_all_light_effects()
	await SceneManager.switch_scene("res://Scenes/UI/Scenes/TitleScene.tscn", 0.15)

## 退出场景时停止灯光效果
func _exit_tree():
	LightingManager.stop_all_light_effects()
