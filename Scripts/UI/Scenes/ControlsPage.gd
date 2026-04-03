# ControlsPage.gd
extends Node2D

## 控制设置页面脚本

## 节点引用
@onready var action_list = $ActionList                     ## 动作列表容器
@onready var controls_hint = $ControlsHint                 ## 控制页面提示标签
@onready var reset_button = $ResetPanel/ResetButton        ## 重置按钮
@onready var reset_hint_label = $ResetPanel/ResetHintLabel ## 重置提示标签

## 动作按钮映射（在_ready中填充）
var action_buttons = {}

## 重置相关变量
var reset_state: int = 0                                   ## 0:初始, 1:第一次按下
var reset_timer: float = 0.0
@export var reset_hint_show_time: float = 1.5              ## 重置提示显示时间
@export var reset_hint_fade_time: float = 0.5              ## 重置提示淡出时间
@export var reset_timeout: float = 2.0                     ## 重置超时时间

## 提示系统变量
@export var hint_wait_time: float = 0.5                    ## 成功/失败提示等待时间
@export var hint_fade_time: float = 0.5                    ## 提示淡出时间
var current_hint_type: String = ""                         ## 当前提示类型："waiting"、"success"、"cancel"
var hint_timer: Timer = null                               ## 提示计时器
var hint_tween: Tween = null                               ## 提示淡出tween

## 初始化
func _ready():
	## 初始隐藏提示
	controls_hint.visible = false
	reset_hint_label.visible = false
	
	## 创建提示计时器
	hint_timer = Timer.new()
	hint_timer.name = "HintTimer"
	hint_timer.one_shot = true
	hint_timer.timeout.connect(_on_hint_timer_timeout)
	add_child(hint_timer)
	
	## 设置动作按钮映射
	_setup_action_buttons()
	
	## 连接重置按钮信号
	reset_button.pressed.connect(_on_reset_button_pressed)
	
	## 更新所有动作的显示
	_update_all_action_displays()

## 设置动作按钮映射
func _setup_action_buttons():
	## 遍历所有动作项
	for child in action_list.get_children():
		if child is HBoxContainer:
			## 查找重新映射按钮
			var remap_button = _find_remap_button(child)
			if remap_button:
				## 根据HBoxContainer的名称确定动作
				var action_name = _get_action_from_hbox(child.name)
				if action_name != "":
					action_buttons[action_name] = remap_button
					remap_button.pressed.connect(_on_action_remap_button_pressed.bind(action_name))

## 查找HBoxContainer中的重新映射按钮
func _find_remap_button(hbox: HBoxContainer) -> TextureButton:
	for child in hbox.get_children():
		if child is TextureButton and child.name.contains("Remap"):
			return child
	return null

## 从HBoxContainer名称获取动作名称
func _get_action_from_hbox(hbox_name: String) -> String:
	var action_map = {
		"JumpAction": "jump",                ## 跳跃动作
		"DashAction": "dash",                ## 冲刺动作
		"LeftAction": "left",                ## 向左移动
		"RightAction": "right",              ## 向右移动
		"UpAction": "up",                    ## 向上移动
		"DownAction": "down",                ## 向下移动
		"SuperDashAction": "super_dash",     ## 超级冲刺
		"InteractiveAction": "interactive",  ## 交互
		"DialogueNextAction": "dialogue_next" ## 对话继续
	}
	
	return action_map.get(hbox_name, "")

## 动作重新映射按钮按下（支持切换）
func _on_action_remap_button_pressed(action: String):
	AudioManager.play_sfx("button_click")
	
	## 关键修复：如果已经在等待输入，直接切换动作
	if InputMapManager.is_remapping():
		## 直接切换，不取消提示
		InputMapManager.switch_remap_action(action)
		show_waiting_hint()  ## 重新显示等待提示
		return
	
	## 如果正在淡出结果提示，打断它
	if current_hint_type in ["success", "cancel"]:
		cancel_hint_effects()
	
	## 开始新的重新映射
	InputMapManager.start_remap_action(action)
	show_waiting_hint()

## 更新所有动作显示
func _update_all_action_displays():
	for action in action_buttons.keys():
		_update_action_display(action)

## 更新单个动作显示
func _update_action_display(action: String):
	var hbox_name = _get_hbox_name_from_action(action)
	if hbox_name == "":
		return
	
	var hbox = action_list.get_node_or_null(hbox_name)
	if not hbox:
		return
	
	## 查找按键显示标签（第二个子节点）
	if hbox.get_child_count() >= 2:
		var key_label = hbox.get_child(1)  ## KeyLabel
		if key_label is Label:
			key_label.text = InputMapManager.get_action_key_display(action)

## 获取动作对应的HBox名称
func _get_hbox_name_from_action(action: String) -> String:
	var action_map = {
		"jump": "JumpAction",
		"dash": "DashAction",
		"left": "LeftAction",
		"right": "RightAction",
		"up": "UpAction",
		"down": "DownAction",
		"super_dash": "SuperDashAction",
		"interactive": "InteractiveAction",
		"dialogue_next": "DialogueNextAction"
	}
	
	return action_map.get(action, "")

## 显示等待提示（不消失）
func show_waiting_hint(text: String = "请按下新的按键... (ESC取消)"):
	## 取消任何现有提示效果
	cancel_hint_effects()
	
	## 设置提示
	controls_hint.text = text
	controls_hint.modulate.a = 1.0
	controls_hint.modulate = Color.WHITE  ## 白色等待提示
	controls_hint.visible = true
	
	## 标记为等待类型
	current_hint_type = "waiting"

## 显示结果提示（自动消失）
func show_result_hint(text: String, is_success: bool = true):
	## 取消任何现有提示效果
	cancel_hint_effects()
	
	## 设置提示
	controls_hint.text = text
	controls_hint.modulate.a = 1.0
	controls_hint.visible = true
	
	## 设置颜色
	if is_success:
		controls_hint.modulate = Color.GREEN  ## 成功：绿色
	else:
		controls_hint.modulate = Color.YELLOW ## 取消/失败：黄色
	
	## 标记为结果类型
	current_hint_type = "success" if is_success else "cancel"
	
	## 开始等待计时
	hint_timer.start(hint_wait_time)

## 取消提示效果（计时器和tween）
func cancel_hint_effects():
	## 停止计时器
	if hint_timer and hint_timer.time_left > 0:
		hint_timer.stop()
	
	## 停止tween
	if hint_tween and hint_tween.is_valid():
		hint_tween.kill()
		hint_tween = null
	
	## 重置颜色为白色
	controls_hint.modulate = Color.WHITE

## 计时器超时处理（开始淡出）
func _on_hint_timer_timeout():
	if current_hint_type != "waiting":  ## 只有结果提示才淡出
		start_hint_fade_out()

## 开始淡出提示
func start_hint_fade_out():
	hint_tween = create_tween()
	hint_tween.tween_property(controls_hint, "modulate:a", 0.0, hint_fade_time)
	hint_tween.tween_callback(func():
		if current_hint_type != "waiting":  ## 确保不是等待提示
			controls_hint.visible = false
			controls_hint.modulate.a = 1.0
			current_hint_type = ""
	)

## 处理输入事件
func _input(event):
	## 检查是否正在等待重新映射输入
	if InputMapManager.is_remapping():
		var handled = InputMapManager.handle_remap_input(event)
		if handled:
			## 已处理，阻止事件传递
			get_viewport().set_input_as_handled()
			
			## 取消任何提示效果
			cancel_hint_effects()
			
			if event is InputEventKey and event.keycode == KEY_ESCAPE:
				## ESC取消
				show_result_hint("已取消重新映射", false)
			else:
				## 映射成功
				_update_all_action_displays()
				show_result_hint("映射成功！", true)

## 处理物理处理
func _process(delta):
	## 处理重置按钮超时
	if reset_state == 1:
		reset_timer += delta
		
		if reset_timer >= reset_hint_show_time:  ## 显示时间结束，开始淡出提示
			var fade_time = reset_hint_fade_time
			var tween = create_tween()
			tween.tween_property(reset_hint_label, "modulate:a", 0.0, fade_time)
			tween.tween_callback(func():
				if reset_state == 1:  ## 如果还在等待确认
					reset_state = 0
					reset_timer = 0.0
					reset_hint_label.visible = false
			)
		
		if reset_timer >= reset_timeout:  ## 超时重置
			reset_state = 0
			reset_timer = 0.0
			reset_hint_label.visible = false

## 重置按钮按下
func _on_reset_button_pressed():
	AudioManager.play_sfx("button_click")
	
	## 如果正在等待映射输入，先取消
	if InputMapManager.is_remapping():
		InputMapManager.cancel_remap()
		return
	
	## 如果正在显示结果提示，取消它
	if current_hint_type in ["success", "cancel"]:
		cancel_hint_effects()
		controls_hint.visible = false
		current_hint_type = ""
	
	match reset_state:
		0:  ## 第一次按下
			reset_state = 1
			reset_timer = 0.0
			reset_hint_label.text = "再按一次确认重置"
			reset_hint_label.modulate.a = 1.0
			reset_hint_label.visible = true
		
		1:  ## 第二次按下（确认）
			reset_state = 0
			reset_timer = 0.0
			
			## 执行重置
			if InputMapManager.reset_to_default():
				_update_all_action_displays()
				reset_hint_label.text = "已重置为默认设置"
				reset_hint_label.modulate.a = 1.0
				reset_hint_label.visible = true
				
				## 1秒后淡出
				var tween = create_tween()
				tween.tween_property(reset_hint_label, "modulate:a", 0.0, 1.0)
				tween.tween_callback(func():
					reset_hint_label.visible = false
				)

## 取消当前映射（用于页面切换等）
func cancel_current_mapping():
	if InputMapManager.is_remapping():
		## 如果正在等待输入，取消它并显示提示
		InputMapManager.cancel_remap()
		show_result_hint("已取消重新映射", false)
	elif current_hint_type in ["success", "cancel"]:
		## 如果是结果提示，直接隐藏
		cancel_hint_effects()
		controls_hint.visible = false
		current_hint_type = ""
