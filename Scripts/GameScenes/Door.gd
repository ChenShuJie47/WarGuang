# Door.gd
extends Area2D

## 门设置
@export_category("门设置")
## 门的唯一 ID，相同 ID 的两个门互相传送
@export var door_id: String = ""

## 传送效果设置
@export_category("传送效果设置")
## 渐入时间（秒）
@export var fade_in_duration: float = 0.1
## 黑屏时间（秒）
@export var black_screen_duration: float = 0.5
## 淡出时间（秒）
@export var fade_out_duration: float = 0.4
## Door 非瞬移追镜时长（秒）
@export var door_camera_catchup_duration: float = 0.20
## Door 传送后临时放开相机限制时长（秒）
@export var door_camera_limit_unlock_duration: float = 0.32

# 内部变量
var can_teleport: bool = true
var is_player_inside: bool = false
var is_enabled: bool = true

func _ready():
	# 检查 door_id 是否设置
	if door_id == "":
		print("错误：门节点没有设置 door_id，路径：", get_path())
		is_enabled = false
		return
	
	# 向 DoorManager 注册
	DoorManager.register_door(self)
	
	# 连接信号
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

## 门被销毁时从 DoorManager 注销
func _exit_tree():
	if door_id != "" and DoorManager:
		DoorManager.unregister_door(self)

func _on_body_entered(body):
	if body.is_in_group("player") and can_teleport and is_enabled:
		# 关键修复：检查玩家是否处于死亡状态
		if body.has_method("is_in_death_state") and body.is_in_death_state():
			return  # 死亡过程中不触发传送
		
		is_player_inside = true
		await teleport_player(body)

func _on_body_exited(body):
	if body.is_in_group("player"):
		is_player_inside = false
		can_teleport = true  # 离开后重新启用传送

## 传送玩家
func teleport_player(player):
	# 进入 Door 即锁输入并清理惯性，直到自动走位结束。
	if player.has_method("lock_control"):
		player.lock_control(999.0, "door_transfer")
	player.velocity = Vector2.ZERO

	# 中断受伤视觉效果
	if player.has_method("interrupt_hurt_visual_only"):
		player.interrupt_hurt_visual_only()
	elif player.has_method("interrupt_hurt_visual_effect"):
		player.interrupt_hurt_visual_effect()
	
	var other_door = DoorManager.find_other_door(self)
	
	if not other_door:
		push_error("严重错误：找不到相同 ID 的另一个门，ID='" + door_id + "'，路径：" + str(get_path()))
		return
	
	can_teleport = false
	other_door.can_teleport = false
	
	# 1. 渐入（渐黑）
	await FadeManager.fade_out(fade_in_duration)
	
	# 2. 黑屏期间切换房间和传送玩家
	var target_room_id = other_door.get_room_id()
	var target_position = other_door.global_position

	# 传送窗口内临时抑制 RoomTrigger 切房回调，防止角点门附近二次切房竞态
	if RoomManager and RoomManager.has_method("suppress_player_room_enter"):
		RoomManager.suppress_player_room_enter(0.45)
	
	RoomManager.load_room(target_room_id)
	
	player.global_position = target_position
	player.velocity = Vector2.ZERO
	# 玩家已落到目标门后再次刷新房间相机限制，避免边界门首帧限制滞后
	RoomManager.update_camera_limits()
	# 等场景树与物理一帧，使房间显隐、相机限制与变换就绪后再同步相机（仍处在全黑中）
	await get_tree().process_frame
	await get_tree().physics_frame
	if player.has_method("start_door_camera_catchup_after_teleport"):
		player.start_door_camera_catchup_after_teleport(
			door_camera_catchup_duration,
			door_camera_limit_unlock_duration
		)
	# 传送到目标房间后稍作停顿，再开始自动走位；期间保持连续锁控。
	await get_tree().create_timer(0.1).timeout
	if player.has_method("start_door_autowalk_to_dynamic_checkpoint"):
		var autowalk_started: bool = player.start_door_autowalk_to_dynamic_checkpoint(target_room_id, target_position, player.is_facing_right)
		if not autowalk_started and player.has_method("lock_control"):
			# 目标房间可能暂无动态检查点，避免无限锁输入。
			player.lock_control(0.18, "door_transfer_fallback")
	
	# 同步后额外等待一帧，让 PhantomCameraHost 更新 Camera2D
	await get_tree().physics_frame
	
	# 3. 黑屏等待（相机已在上一段完成切换，此处仅保持全黑时长）
	await get_tree().create_timer(black_screen_duration).timeout
	
	# 4. 淡出（恢复）
	await FadeManager.fade_in(fade_out_duration)
	
	other_door.is_player_inside = true

## 获取门所在房间的 ID
func get_room_id() -> String:
	# 向上查找房间节点
	var parent = get_parent()
	while parent and not parent.has_method("get_room_data"):
		parent = parent.get_parent()
	
	if parent and parent.has_method("get_room_data"):
		var room_data = parent.get_room_data()
		if room_data and room_data.has("id"):
			return room_data.id
	
	# 备用方案：从场景树路径推断房间
	var scene_path = get_path()
	if "Room1" in scene_path:
		return "Room1"
	elif "Room2" in scene_path:
		return "Room2"
	elif "Room3" in scene_path:
		return "Room3"
	
	push_warning("Door.get_room_id(): 无法确定房间 ID，路径=", scene_path)
	return ""

## 禁用传送功能
func disable_teleport():
	is_enabled = false
	print("门 ID='", door_id, "'的传送功能已禁用")
