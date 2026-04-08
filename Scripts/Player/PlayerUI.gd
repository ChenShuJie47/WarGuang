extends CanvasLayer
class_name PlayerUI

## ============================================
## PlayerUI - 玩家 UI 管理器
## ============================================

## 血量单位场景（在 Inspector 中拖拽 HealthUnit.tscn）
@export var health_unit_scene: PackedScene

## 游戏设置场景（在 Inspector 中拖拽 GameSettingScene.tscn）
@export var game_setting_scene: PackedScene

var max_health: int = 3
var current_health: int = 3
var health_units: Array = []

## 信号定义
signal health_changed(new_health)
signal max_health_changed(new_max_health)
signal player_died()

## 节点引用
@onready var health_container = $HealthContainer
@onready var coin_container = $CoinContainer
@onready var coin_label = $CoinContainer/CoinLabel
@onready var coin_change_label = $CoinContainer/CoinChangeLabel
@onready var game_setting_button = $GameSettingButton
@onready var save_label = $SaveLabeI
@onready var player_icon = $PlayerIcon  # 添加玩家头像引用

## 游戏设置按钮的独立 CanvasLayer
var game_setting_button_layer: CanvasLayer

## 游戏设置实例引用
var game_setting_instance: Node = null

## 血量布局参数
@export_category("血量 UI 布局设置")
## 血量单位之间的水平间距
@export var health_unit_spacing: float = 1.0
## 第一个血量单位的 X 坐标
@export var health_unit_start_x: float = 0.0
## 所有血量单位的 Y 坐标
@export var health_unit_y: float = 0.0

## 钱币动画设置
@export_category("钱币动画设置")
## 获得钱币后延迟多少秒开始递增
@export var coin_increment_delay: float = 1.5

## 钱币动画结束后等待多少秒开始淡出
@export var coin_hide_delay: float = 2.0
## 钱币淡入淡出动画的持续时间（秒）
@export var coin_fade_duration: float = 0.5
## 钱币动画变化间隔时间（≤10 个时的间隔）
@export var coin_change_interval_slow: float = 0.2
## 钱币动画变化间隔时间（≤100 个时的间隔）
@export var coin_change_interval_mod: float = 0.05
## 钱币动画变化间隔时间（>100 个时的间隔）
@export var coin_change_interval_fast: float = 0.02

@export_category("存档标签设置")
## 存档标签显示持续时间（秒）
@export var save_label_show_duration: float = 2.0
## 存档标签淡入淡出时间（秒）
@export var save_label_fade_duration: float = 0.5

# 在类的变量声明部分添加
var save_label_tween: Tween

## 钱币系统相关变量
var current_display_coins: int = 0
var coin_change_amount: int = 0
var coin_visible: bool = false
var coin_hide_timer: float = 0.0
var coin_tween: Tween
var coin_delay_timer: float = 0.0
var is_waiting_for_increment: bool = false
var is_increasing: bool = false
var is_animating: bool = false

func _ready():
	initialize_health_display()
	initialize_coin_display()
	add_to_group("player_ui")
	
	# 初始化存档标签
	if save_label:
		save_label.visible = false
		save_label.modulate.a = 0.0
	
	# 关键修复：创建独立的 CanvasLayer 包裹 GameSettingButton
	_create_game_setting_button_layer()
	
	# 连接信号
	game_setting_button.pressed.connect(_open_game_setting_menu)
	Global.player_max_health_changed.connect(_on_global_max_health_changed)
	Global.player_health_changed.connect(_on_global_health_changed)
	Global.coins_changed.connect(_on_coins_changed)
	Global.coins_changing.connect(_on_coins_changing)

## 创建 GameSettingButton 的独立 CanvasLayer
func _create_game_setting_button_layer():
	# 创建新的 CanvasLayer
	game_setting_button_layer = CanvasLayer.new()
	game_setting_button_layer.layer = 101  # 比设置界面 (100) 还高
	
	# 从父节点移除按钮并添加到新的 CanvasLayer
	if game_setting_button and game_setting_button.get_parent():
		game_setting_button.get_parent().remove_child(game_setting_button)
		game_setting_button_layer.add_child(game_setting_button)
		get_tree().root.add_child(game_setting_button_layer)

func _process(_delta):
	# 处理钱币延迟递增
	if is_waiting_for_increment:
		coin_delay_timer += _delta
		if coin_delay_timer >= coin_increment_delay:
			is_waiting_for_increment = false
			coin_delay_timer = 0.0
			# 关键修复：调用 play_coin_animation()
			play_coin_animation()
	
	# 处理钱币自动隐藏
	if coin_visible and coin_change_amount == 0 and not is_waiting_for_increment:
		coin_hide_timer += _delta
		if coin_hide_timer >= coin_hide_delay:
			hide_coin_ui()
			coin_hide_timer = 0.0

# 血量显示初始化
func initialize_health_display():
	# 清除现有的血量单位
	for unit in health_units:
		if is_instance_valid(unit):
			unit.queue_free()
	health_units.clear()
	
	# 创建新的血量单位
	for i in range(max_health):
		var health_unit = health_unit_scene.instantiate()
		
		health_unit.position = Vector2(health_unit_start_x + (i * health_unit_spacing), health_unit_y)
		health_unit.scale = Vector2(2, 2)
		health_container.add_child(health_unit)
		health_units.append(health_unit)
		
		# 连接动画完成信号
		if health_unit.animated_sprite:
			health_unit.animated_sprite.animation_finished.connect(_on_health_unit_animation_finished.bind(health_unit))
	
	# 初始设置为满血
	current_health = max_health
	_apply_health_state_immediately()

func _on_health_unit_animation_finished(health_unit):
	match health_unit.animated_sprite.animation:
		"ADD":
			# ADD 动画完成后切换到 HAVE 状态
			health_unit.set_state(health_unit.HealthState.HAVE)
		"REDUCE":
			# REDUCE 动画完成后切换到 NULL 状态
			health_unit.set_state(HealthUnit.HealthState.NULL)

# 立即应用血量状态（不播放动画）
func _apply_health_state_immediately():
	# 应用每个血量单位的状态
	for i in range(health_units.size()):
		var health_unit = health_units[i]
		
		if not is_instance_valid(health_unit):
			continue
		
		# 修复：类型检查，确保是 HealthUnit
		if not health_unit.has_method("set_state"):
			continue
		
		if i < current_health:
			if current_health == 1 and i == 0:
				health_unit.set_state(HealthUnit.HealthState.LASTHAVE)
			else:
				health_unit.set_state(HealthUnit.HealthState.HAVE)
		else:
			health_unit.set_state(HealthUnit.HealthState.NULL)
	
	# 触发低血量视觉效果
	
# 统一的血量设置函数
func set_health_internal(new_health: int, play_animation: bool = true):
	var old_health = current_health
	current_health = clamp(new_health, 0, max_health)
	
	if play_animation and old_health != current_health:
		_play_health_animation_for_change(old_health, current_health)
	else:
		_apply_health_state_immediately()
	
	health_changed.emit(current_health)
	Global.player_current_health = current_health
	
	if current_health <= 0:
		player_died.emit()

# 播放血量变化动画（根据血量变化）
func _play_health_animation_for_change(old_health: int, new_health: int):
	# 计算变化的血量单位索引
	var start_index = min(old_health, new_health)
	var end_index = max(old_health, new_health)
	
	# 确定是增加还是减少
	var is_healing = new_health > old_health
	
	for i in range(start_index, end_index):
		if i < health_units.size():
			var health_unit = health_units[i]
			if is_instance_valid(health_unit):
				if is_healing:
					health_unit.set_state(HealthUnit.HealthState.ADD)
				else:
					health_unit.set_state(HealthUnit.HealthState.REDUCE)
	
	# 更新所有血量单位的最终状态
	await get_tree().create_timer(0.3).timeout
	_apply_health_state_immediately()

# 更新低血量视觉效果
func _update_low_health_effect():
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("update_low_health_effect"):
		player.update_low_health_effect()

# 公共接口函数
func take_damage(damage: int = 1):
	if damage <= 0 or current_health <= 0:
		return
	
	set_health_internal(current_health - damage, true)
	
	# 关键修复：在血量变为 0 时立即触发低血量效果
	if current_health == 0:
		# 通过信号通知 Player 触发低血量效果
		var player = get_tree().get_first_node_in_group("player")
		if player and player.has_method("_trigger_low_health_effect"):
			player._trigger_low_health_effect()

func heal(heal_amount: int = 1):
	if heal_amount <= 0 or current_health >= max_health:
		return
	
	set_health_internal(current_health + heal_amount, true)

func set_health(new_health: int):
	set_health_internal(new_health, true)

func increase_max_health(amount: int = 1):
	if amount <= 0:
		return
	
	var old_max_health = max_health
	max_health += amount
	current_health += amount  # 增加上限时同时恢复血量
	
	# 重新创建血量显示
	initialize_health_display()
	
	# 关键修复：只为新增的血量单位播放 ADD 动画
	for i in range(old_max_health, max_health):
		if i < health_units.size():
			var health_unit = health_units[i]
			if is_instance_valid(health_unit):
				health_unit.set_state(HealthUnit.HealthState.ADD)
	
	# 发出信号
	max_health_changed.emit(max_health)
	health_changed.emit(current_health)

# 钱币系统相关函数
func initialize_coin_display():
	# 初始设置钱币显示
	current_display_coins = Global.player_coins
	coin_label.text = str(current_display_coins)
	coin_change_label.visible = false
	
	# 初始隐藏钱币 UI
	coin_container.modulate.a = 0.0
	coin_visible = false

func _on_coins_changed(new_amount: int):
	if not is_animating:
		var change = new_amount - current_display_coins
		if change > 0:
			coin_change_amount = change
			is_increasing = true
			play_coin_animation()
	else:
		var remaining = new_amount - current_display_coins
		if remaining > 0:
			coin_change_amount = remaining
			is_increasing = true
			coin_change_label.text = "+" + str(coin_change_amount)
			_restart_animation()
		else:
			coin_change_amount = -remaining
			is_increasing = false
			coin_change_label.text = "-" + str(coin_change_amount)
			_restart_animation()

# 处理钱币花费动画
func _on_coins_changing(_old_amount: int, new_amount: int, _duration: float):
	var decrease_amount = _old_amount - new_amount
	
	if decrease_amount > 0:
		if not is_animating:
			coin_change_amount = decrease_amount
			is_increasing = false
			play_coin_animation()
		else:
			var remaining = current_display_coins - new_amount
			if remaining > 0:
				coin_change_amount = remaining
				is_increasing = false
				coin_change_label.text = "-" + str(coin_change_amount)
				_restart_animation()
			else:
				coin_change_amount = -remaining
				is_increasing = true
				coin_change_label.text = "+" + str(coin_change_amount)
				_restart_animation()

func _restart_animation():
	# 停止当前动画
	if coin_tween:
		coin_tween.kill()
		coin_tween = null
	
	# 重新播放
	play_coin_animation()

func play_coin_animation():
	is_animating = true
	
	coin_hide_timer = 0.0
	show_coin_ui()
	
	if coin_container:
		coin_container.visible = true
		coin_container.modulate.a = 1.0
	if coin_label:
		coin_label.visible = true
	
	var amount = coin_change_amount
	if is_increasing:
		coin_change_label.text = "+" + str(amount)
	else:
		coin_change_label.text = "-" + str(amount)
	coin_change_label.visible = true
	
	if coin_tween:
		coin_tween.kill()
		coin_tween = null
	
	coin_tween = create_tween()
	coin_tween.set_parallel(false)
	
	for i in range(amount):
		var remaining = amount - i
		var current_interval = _get_coin_change_interval(remaining)
		
		coin_tween.tween_callback(func(): 
			if is_increasing:
				coin_change_amount -= 1
				current_display_coins += 1
			else:
				coin_change_amount -= 1
				current_display_coins -= 1
			
			if coin_change_amount > 0:
				if is_increasing:
					coin_change_label.text = "+" + str(coin_change_amount)
				else:
					coin_change_label.text = "-" + str(coin_change_amount)
			else:
				coin_change_label.visible = false
			
			coin_label.text = str(current_display_coins)
		)
		coin_tween.tween_interval(current_interval)
	
	coin_tween.tween_callback(func():
		is_animating = false
		
		coin_change_label.visible = false
		coin_hide_timer = 2.0
		
		if current_display_coins != Global.player_coins:
			print("警告：显示值", current_display_coins, "≠ 实际值", Global.player_coins)
			current_display_coins = Global.player_coins
			coin_label.text = str(current_display_coins)
	)

## 根据变化数量获取间隔时间（使用外部变量）
func _get_coin_change_interval(amount: int) -> float:
	if amount <= 10:
		return coin_change_interval_slow
	elif amount <= 100:
		return coin_change_interval_mod
	else:
		return coin_change_interval_fast

func update_coin_display():
	coin_label.text = str(current_display_coins)

func show_coin_ui():
	if coin_visible:
		return
	
	coin_visible = true
	coin_hide_timer = 0.0
	
	if coin_tween:
		coin_tween.kill()
	
	coin_tween = create_tween()
	coin_tween.tween_property(coin_container, "modulate:a", 1.0, coin_fade_duration)

func hide_coin_ui():
	if not coin_visible:
		return
	
	coin_visible = false
	
	if coin_tween:
		coin_tween.kill()
	
	coin_tween = create_tween()
	coin_tween.tween_property(coin_container, "modulate:a", 0.0, coin_fade_duration)

func show_save_label():
	if not save_label:
		return
	
	if save_label_tween:
		save_label_tween.kill()
	
	# 关键修复：强制重置状态，确保每次都从透明开始
	save_label.visible = true
	save_label.modulate.a = 0.0
	
	# 使用 Tween 序列实现完整动画
	save_label_tween = create_tween()
	save_label_tween.tween_property(save_label, "modulate:a", 1.0, save_label_fade_duration)
	save_label_tween.tween_interval(save_label_show_duration)
	save_label_tween.tween_property(save_label, "modulate:a", 0.0, save_label_fade_duration)
	save_label_tween.tween_callback(func(): save_label.visible = false)

# 游戏设置相关函数
func _on_game_setting_button_pressed():
	AudioManager.play_sfx("button_click")
	
	_open_game_setting_menu()

func _open_game_setting_menu():
	if game_setting_instance != null:
		return
	
	if not game_setting_scene:
		push_error("PlayerUI: game_setting_scene 未配置！请在 Inspector 中拖拽 GameSettingScene.tscn")
		return
	
	game_setting_instance = game_setting_scene.instantiate()
	
	if game_setting_instance.has_signal("menu_closed"):
		game_setting_instance.menu_closed.connect(_on_game_setting_closed)
	
	# 隐藏 GameSettingButton
	if game_setting_button:
		game_setting_button.visible = false
	
	# 确保游戏暂停 - 关键修复
	get_tree().paused = true
	
	get_tree().root.add_child(game_setting_instance)

func _on_game_setting_closed():
	game_setting_instance = null
	
	# 重新显示 GameSettingButton
	if game_setting_button:
		game_setting_button.visible = true
	
	# 确保游戏恢复运行 - 关键修复
	get_tree().paused = false

# PlayerUI.gd - 移除 ESC 防抖
func _input(event):
	if event.is_action_pressed("ui_cancel") and game_setting_instance == null:
		_open_game_setting_menu()

# 全局数据更新
func _on_global_max_health_changed(new_max_health: int):
	if new_max_health != max_health:
		max_health = new_max_health
		current_health = min(current_health, max_health)
		initialize_health_display()

func _on_global_health_changed(new_health: int):
	if new_health != current_health:
		# 使用动画方式更新血量，确保播放 ADD 动画
		set_health_internal(new_health, true)
		
		# 关键修复：通知 Player 更新低血量效果
		var player = get_tree().get_first_node_in_group("player")
		if player and player.has_method("update_low_health_effect"):
			player.update_low_health_effect()

# 公共方法
func get_health() -> int:
	return current_health

func set_max_health(new_max_health: int):
	max_health = new_max_health
	current_health = min(current_health, max_health)
	max_health_changed.emit(max_health)
	initialize_health_display()
	Global.player_max_health = max_health
	Global.player_current_health = current_health

## 隐藏 UI（保留设置按钮和钱币）
func hide_ui_except_settings():
	health_container.visible = false
	coin_container.visible = false
	if player_icon:
		player_icon.visible = false
	if save_label:
		save_label.visible = false

## 带淡出效果隐藏 UI（忽略钱币，因为挑战开始时钱币已经是隐藏的）
func fade_out_ui_no_coin(duration: float):
	var tween = create_tween()
	tween.tween_property(health_container, "modulate:a", 0.0, duration)
	if player_icon:
		tween.parallel().tween_property(player_icon, "modulate:a", 0.0, duration)
	if save_label:
		tween.parallel().tween_property(save_label, "modulate:a", 0.0, duration)
	tween.tween_callback(func():
		health_container.visible = false
		if player_icon:
			player_icon.visible = false
		if save_label:
			save_label.visible = false
	)

## 显示 UI
func show_ui():
	health_container.visible = true
	coin_container.visible = true
	health_container.modulate.a = 1.0
	coin_container.modulate.a = 1.0
	if player_icon:
		player_icon.visible = true
		player_icon.modulate.a = 1.0
	if save_label:
		save_label.visible = true
		save_label.modulate.a = 1.0

## 带淡入效果显示 UI（忽略钱币，因为挑战结束时钱币不需要自动显示）
func fade_in_ui_no_coin(_duration: float):
	health_container.visible = true
	health_container.modulate.a = 1.0
	if player_icon:
		player_icon.visible = true
		player_icon.modulate.a = 1.0
	if save_label:
		save_label.visible = true
		save_label.modulate.a = 1.0
	# 注意：不显示 coin_container，保持隐藏状态
