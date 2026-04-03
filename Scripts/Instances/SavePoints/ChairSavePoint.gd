extends Area2D

@onready var interaction_prompt = $InteractionPrompt

@export var save_point_id: String = "default_chair"
## 交互后禁止操控的时间（秒）
@export var interaction_lock_duration: float = 1.0

var player_in_range: bool = false
var has_interacted: bool = false

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	interaction_prompt.visible = false
	
	if save_point_id == "default_chair":
		save_point_id = "chair_%s" % [str(global_position).replace("(", "").replace(")", "").replace(", ", "_")]

func _on_body_entered(body):
	if body.is_in_group("player"):
		player_in_range = true
		interaction_prompt.visible = true
		has_interacted = false

func _on_body_exited(body):
	if body.is_in_group("player"):
		player_in_range = false
		interaction_prompt.visible = false

func _input(event):
	if event.is_action_pressed("interactive") and player_in_range and not has_interacted:
		# 检查玩家是否在冲刺状态
		var player = get_tree().get_first_node_in_group("player")
		if player and player.get_player_state() == player.PlayerState.DASH:
			print("存档点: 冲刺状态下不能交互")
			return
		
		_interact_with_chair()

func _interact_with_chair():
	has_interacted = true
	
	# 获取当前房间ID
	var current_room_id = RoomManager.current_room
	
	# 设置存档点，包含房间ID
	Global.set_save_point(global_position, save_point_id, "res://Scenes/GameScenes/MainGameScene.tscn")
	
	# 记录当前房间到全局数据（需要扩展Global）
	Global.last_save_room = current_room_id
	
	# 播放存档音效
	AudioManager.play_instance_sfx("save_game")
	
	# 让玩家进入睡眠状态并锁定控制
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.set_player_state(player.PlayerState.SLEEP)
		player.lock_control(interaction_lock_duration)
		print("存档点: 玩家进入睡眠状态，控制锁定", interaction_lock_duration, "秒")
	
	# 显示存档成功标签
	var player_ui = get_tree().get_first_node_in_group("player_ui")
	if player_ui and player_ui.has_method("show_save_label"):
		player_ui.show_save_label()
	
	# 显示存档成功提示
	_show_save_success()
	
	# 2秒后重置交互状态
	await get_tree().create_timer(2.0).timeout
	has_interacted = false

func _show_save_success():
	print("游戏已存档在椅子位置: ", global_position, " (ID: ", save_point_id, ")")
