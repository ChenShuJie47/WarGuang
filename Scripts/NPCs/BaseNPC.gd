extends Area2D
class_name BaseNPC

## ============================================
## BaseNPC - 所有 NPC 的基础类
## ============================================
## 功能:
## - 基础交互逻辑
## - 对话气球显示
## - 交互提示管理
## ============================================

## NPC 唯一标识符（在 Inspector 中设置）
@export var npc_id: String = ""

## 对话资源（在 Inspector 中指定）
@export var dialogue_resource: DialogueResource

## 气球对话场景（在 Inspector 中拖拽 MyBalloon.tscn）
@export var balloon_scene: PackedScene

## 是否只能交互一次
@export var interact_once: bool = false

# 节点引用
@onready var animated_sprite = $AnimatedSprite2D if has_node("AnimatedSprite2D") else null
@onready var interaction_prompt = $InteractionPrompt if has_node("InteractionPrompt") else null

# 内部变量 (var): 使用 # 注释，写在变量右边
var player_in_range: bool = false  # 玩家是否在范围内
var has_interacted: bool = false  # 是否已经交互过
var is_talking: bool = false  # 是否正在对话

func _ready():
	# 修复：删除 super._ready()，因为 Area2D 没有 _ready() 方法
	# 使用 get_node_or_null 访问 DialogueSystem
	var dialogue_system = get_node_or_null("/root/DialogueSystem")
	if dialogue_system:
		if dialogue_system.has_signal("dialogue_started"):
			dialogue_system.dialogue_started.connect(_on_dialogue_started)
		if dialogue_system.has_signal("dialogue_ended"):
			dialogue_system.dialogue_ended.connect(_on_dialogue_ended)
	
	# 修复：连接 Area2D 的 body_entered/body_exited 信号
	if has_node("CollisionShape2D") or has_node("Area2D"):
		if not body_entered.is_connected(_on_body_entered):
			body_entered.connect(_on_body_entered)
		if not body_exited.is_connected(_on_body_exited):
			body_exited.connect(_on_body_exited)
	
	# 初始隐藏提示
	if interaction_prompt:
		interaction_prompt.visible = false
	
	_play_default_idle()

func _process(_delta):
	if player_in_range:
		if Input.is_action_just_pressed("interactive"):
			print("DEBUG BaseNPC._process: 检测到交互输入，npc_id=", npc_id)
			# 修复：调用 try_interact() 而不是直接调用 player.start_dialogue()
			try_interact()

## 尝试与 NPC 交互（子类必须实现）
func try_interact():
	print("DEBUG BaseNPC.try_interact: 被调用，npc_id=", npc_id)
	print("  player_in_range=", player_in_range)
	
	if not player_in_range:
		print("DEBUG BaseNPC: 玩家不在范围，返回")
		return
	
	# 修复：检查 DialogueSystem
	var dialogue_system = get_node_or_null("/root/DialogueSystem")
	var in_dialogue = false
	if dialogue_system:
		in_dialogue = dialogue_system.is_dialogue_active
	
	print("DEBUG BaseNPC: in_dialogue=", in_dialogue)
	if in_dialogue:
		print("DEBUG BaseNPC: 对话进行中，返回")
		return
	
	if interact_once and has_interacted:
		print("DEBUG BaseNPC: 已交互过，返回")
		return
	
	print("DEBUG BaseNPC: 调用 _start_interaction()")
	_start_interaction()

## 开始交互
func _start_interaction():
	var task_manager = get_node_or_null("/root/TaskManager")
	if task_manager:
		task_manager.record_npc_dialogue(npc_id)
	
	# 修复：使用 ScenePaths 常量而不是实例方法
	if not balloon_scene:
		balloon_scene = load(ScenePaths.UI_MY_BALLOON)
	
	if not balloon_scene:
		push_error("BaseNPC: balloon_scene 未配置！")
		return
	
	var balloon = balloon_scene.instantiate()
	get_tree().current_scene.add_child(balloon)
	
	# 设置对话内容
	if balloon.has_method("set_dialogue"):
		balloon.set_dialogue(dialogue_resource, self)
	
	# 隐藏交互提示
	if interaction_prompt:
		interaction_prompt.visible = false

## 切换到指定动画（安全版本）
func play_animation(animation_name: String):
	if not animated_sprite:
		return
	
	if not animated_sprite.sprite_frames:
		return
	
	if animated_sprite.sprite_frames.has_animation(animation_name):
		animated_sprite.play(animation_name)
	else:
		print("警告：NPC ", npc_id, " 没有动画:", animation_name)

## 播放默认空闲动画
func _play_default_idle():
	if animated_sprite and animated_sprite.sprite_frames:
		# 尝试播放常见空闲动画名称
		var idle_names = ["IDLE", "idle", "Idle"]
		for animation_name in idle_names:
			if animated_sprite.sprite_frames.has_animation(animation_name):
				animated_sprite.play(animation_name)
				return

## 对话开始信号处理
func _on_dialogue_started():
	is_talking = true

## 对话结束信号处理
func _on_dialogue_ended():
	await get_tree().process_frame
	is_talking = false
	
	if interact_once:
		has_interacted = true
		if interaction_prompt:
			interaction_prompt.visible = false

## 身体进入信号处理
func _on_body_entered(body):
	if body.is_in_group("player"):
		player_in_range = true
		# 检查玩家状态决定是否显示提示
		var player = get_tree().get_first_node_in_group("player")
		if player and player.current_state == player.PlayerState.DASH:
			if interaction_prompt:
				interaction_prompt.visible = false
		else:
			if !interact_once or (interact_once and !has_interacted):
				if interaction_prompt:
					interaction_prompt.visible = true

## 身体离开信号处理
func _on_body_exited(body):
	if body.is_in_group("player"):
		player_in_range = false
		if interaction_prompt:
			interaction_prompt.visible = false
