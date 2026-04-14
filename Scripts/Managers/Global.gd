extends Node

const SAVE_VERSION: int = 1

## 信号定义
signal player_health_changed(new_health)
signal player_max_health_changed(new_max_health)
signal coins_changed(new_amount)
signal coins_changing(old_amount, new_amount, duration)  # 钱币变化动画信号

## 玩家数据
var player_max_health: int = 3
var player_current_health: int = 3
var player_coins: int = 100  # 玩家钱币数量

## 能力解锁状态
var unlocked_abilities: Dictionary = {
	"dash": false,
	"double_jump": false, 
	"glide": false,
	"black_dash": false,
	"wall_grip": false,
	"super_dash": false  # 新增超级冲刺
}

# 击败的Boss记录
var defeated_bosses: Array = []

# 已收集的道具记录
var collected_items: Array = []

# 可破坏石墙摧毁记录（当前存档）- 从存档数据中读取/保存
var destructible_walls_destroyed: Array = []

# 疯子挑战状态记录
var maniac_challenge_completed: bool = false
var maniac_last_challenge_failed: bool = false

# 第二阶段挑战状态记录
var maniac_stage2_challenge_completed: bool = false
var maniac_stage2_last_challenge_failed: bool = false

# 第三阶段挑战状态记录
var maniac_stage3_challenge_completed: bool = false
var maniac_stage3_last_challenge_failed: bool = false

# 存档点数据
var save_point_position: Vector2 = Vector2.ZERO  # 静态存档点位置
var last_save_point: Dictionary = {"position": Vector2(0, 0), "scene_path": "", "save_point_id": ""}

# 新增：动态检查点相关
var last_checkpoint_position: Vector2 = Vector2.ZERO  # 最近一次激活的检查点位置（动态或静态）
var last_checkpoint_type: String = "static"  # "dynamic" 或 "static"

func _ready():
	add_to_group("global")
	# 初始化时，默认使用静态存档点作为最后检查点
	last_checkpoint_position = get_save_point_position()
	last_checkpoint_type = "static"

# 当前存档槽
var current_save_slot: int = -1

var last_save_room: String = "Room1"  # 最后存档的房间

# 初始化新游戏（创建新存档时调用）
func initialize_new_game():
	print("Global: 初始化新游戏")
	# 重置所有存档相关数据
	player_max_health = 3
	player_current_health = 3
	player_coins = 0
	last_save_room = "Room1"
	unlocked_abilities = {
		"dash": false,
		"double_jump": false,
		"glide": false,
		"black_dash": false,
		"wall_grip": false,
		"super_dash": false
	}
	defeated_bosses = []
	collected_items = []
	destructible_walls_destroyed = []  # ⭐ 关键！新存档时清空石墙摧毁记录
	maniac_challenge_completed = false
	maniac_last_challenge_failed = false
	maniac_stage2_challenge_completed = false
	maniac_stage2_last_challenge_failed = false
	maniac_stage3_challenge_completed = false
	maniac_stage3_last_challenge_failed = false
	last_save_point = {"position": Vector2(0, 0), "scene_path": "", "save_point_id": ""}
	last_checkpoint_position = Vector2.ZERO
	last_checkpoint_type = "static"
	
	# ⭐ 关键修复：重置 TaskManager 的 NPC 对话记录
	var task_manager = get_node_or_null("/root/TaskManager")
	if task_manager:
		task_manager.npc_interactions.clear()
		task_manager.tasks_completed.clear()
		task_manager.special_dialogues_shown.clear()


# 保存游戏数据
func get_save_data() -> Dictionary:
	var position_data = {}
	if last_save_point.has("position") and typeof(last_save_point["position"]) == TYPE_VECTOR2:
		position_data = {"x": last_save_point["position"].x, "y": last_save_point["position"].y}
	else:
		position_data = last_save_point.get("position", {"x": 0, "y": 0})
	
	# 获取 TaskManager 数据
	var task_manager = get_node("/root/TaskManager")
	
	# 修复：添加挑战状态记录
	return {
		"save_version": SAVE_VERSION,
		"player_max_health": player_max_health,
		"player_current_health": player_max_health,
		"player_coins": player_coins,
		"last_save_room": last_save_room,
		"unlocked_abilities": unlocked_abilities.duplicate(true),
		"defeated_bosses": defeated_bosses.duplicate(),
		"collected_items": collected_items.duplicate(),
		"last_save_point": {
			"position": position_data,
			"scene_path": last_save_point["scene_path"],
			"save_point_id": last_save_point["save_point_id"]
		},
		# 确保包含 NPC 对话数据
		"npc_interactions": task_manager.npc_interactions.duplicate(true) if task_manager else {},
		"tasks_completed": task_manager.tasks_completed.duplicate(true) if task_manager else {},
		"special_dialogues_shown": task_manager.special_dialogues_shown.duplicate(true) if task_manager else {},
		# 修复：添加疯子挑战状态
		"maniac_challenge_completed": maniac_challenge_completed,
		"maniac_last_challenge_failed": maniac_last_challenge_failed,
		"maniac_stage2_challenge_completed": maniac_stage2_challenge_completed,
		"maniac_stage2_last_challenge_failed": maniac_stage2_last_challenge_failed,
		"maniac_stage3_challenge_completed": maniac_stage3_challenge_completed,
		"maniac_stage3_last_challenge_failed": maniac_stage3_last_challenge_failed,
		"destructible_walls_destroyed": destructible_walls_destroyed.duplicate(true),  # 深拷贝防止引用污染
		"timestamp": Time.get_datetime_string_from_system()
	}

# 加载游戏数据
func load_save_data(data: Dictionary):
	print("Global: 开始加载存档数据")

	# 关键：先重置关键落地字段，避免“缺字段时继承旧运行态”
	last_save_room = "Room1"
	last_save_point = {"position": Vector2(0, 0), "scene_path": "", "save_point_id": ""}
	
	if data.has("player_max_health"):
		player_max_health = data["player_max_health"]
		player_max_health_changed.emit(player_max_health)
	
	# 总是设置为满血状态
	player_current_health = player_max_health
	player_health_changed.emit(player_current_health)
	
	if data.has("player_coins"):
		player_coins = data["player_coins"]
		coins_changed.emit(player_coins)
	
	if data.has("unlocked_abilities"):
		unlocked_abilities = data["unlocked_abilities"]
		_notify_ability_unlocks()
	
	if data.has("defeated_bosses"):
		defeated_bosses = data["defeated_bosses"]
	
	if data.has("collected_items"):
		collected_items = data["collected_items"]
	
	if data.has("last_save_point"):
		var save_point_data = data["last_save_point"]
		if save_point_data.has("position") and typeof(save_point_data["position"]) == TYPE_DICTIONARY:
			var pos_data = save_point_data["position"]
			last_save_point["position"] = Vector2(pos_data["x"], pos_data["y"])
		else:
			last_save_point["position"] = save_point_data.get("position", Vector2(0, 0))
		
		last_save_point["scene_path"] = save_point_data.get("scene_path", ScenePaths.GAME_MAIN)
		last_save_point["save_point_id"] = save_point_data.get("save_point_id", "start_point")

	# 关键：确保房间落点来自该存档槽本身
	if data.has("last_save_room"):
		last_save_room = data["last_save_room"]
	
	# 方案A：动态检查点不入档，只把检查点运行态重置为与静态存档点一致
	last_checkpoint_position = get_save_point_position()
	last_checkpoint_type = "static"
	
	# 加载NPC对话数据
	var task_manager = get_node("/root/TaskManager")
	if task_manager:
		if data.has("npc_interactions"):
			task_manager.npc_interactions = data["npc_interactions"]
		
		if data.has("tasks_completed"):
			task_manager.tasks_completed = data["tasks_completed"]
		
		if data.has("special_dialogues_shown"):
			task_manager.special_dialogues_shown = data["special_dialogues_shown"]
	
	# 修复：加载疯子挑战状态
	if data.has("maniac_challenge_completed"):
		maniac_challenge_completed = data["maniac_challenge_completed"]
	
	if data.has("maniac_last_challenge_failed"):
		maniac_last_challenge_failed = data["maniac_last_challenge_failed"]
	
	if data.has("maniac_stage2_challenge_completed"):
		maniac_stage2_challenge_completed = data["maniac_stage2_challenge_completed"]
	
	if data.has("maniac_stage2_last_challenge_failed"):
		maniac_stage2_last_challenge_failed = data["maniac_stage2_last_challenge_failed"]

	if data.has("maniac_stage3_challenge_completed"):
		maniac_stage3_challenge_completed = data["maniac_stage3_challenge_completed"]

	if data.has("maniac_stage3_last_challenge_failed"):
		maniac_stage3_last_challenge_failed = data["maniac_stage3_last_challenge_failed"]
	
	# 加载可破坏石墙摧毁记录（每个存档独立）
	if data.has("destructible_walls_destroyed"):
		destructible_walls_destroyed = data["destructible_walls_destroyed"].duplicate()  # 使用 .duplicate() 防止引用污染
	else:
		destructible_walls_destroyed = []  # 新存档或无数据时重置为空数组
	
	print("Global: 存档数据加载完成")

# 通知能力解锁
func _notify_ability_unlocks():
	if EventBus and EventBus.instance:
		if unlocked_abilities.get("dash", false):
			EventBus.instance.emit_signal("dash_unlocked")
		if unlocked_abilities.get("double_jump", false):
			EventBus.instance.emit_signal("double_jump_unlocked")
		if unlocked_abilities.get("glide", false):
			EventBus.instance.emit_signal("glide_unlocked")
		if unlocked_abilities.get("black_dash", false):
			EventBus.instance.emit_signal("black_dash_unlocked")
		if unlocked_abilities.get("super_dash", false):
			EventBus.instance.emit_signal("super_dash_unlocked")
		if unlocked_abilities.get("wall_grip", false):
			EventBus.instance.emit_signal("wall_grip_unlocked")

# 解锁能力
func unlock_ability(ability_name: String):
	if unlocked_abilities.has(ability_name) and !unlocked_abilities[ability_name]:
		unlocked_abilities[ability_name] = true
		# 通知EventBus
		_notify_ability_unlocks()
		if current_save_slot >= 0:
			SaveManager.save_game(current_save_slot, get_save_data())
			print("Global: 能力解锁已保存到存档")

# 击败Boss
func defeat_boss(boss_name: String):
	if not boss_name in defeated_bosses:
		defeated_bosses.append(boss_name)
		if current_save_slot >= 0:
			SaveManager.save_game(current_save_slot, get_save_data())

# 增加硬币
func add_coins(amount: int):
	player_coins += amount
	# 发射钱币变化信号
	coins_changed.emit(player_coins)
	if current_save_slot >= 0:
		SaveManager.save_game(current_save_slot, get_save_data())

## 花费钱币（带动画效果）- 关键修复：只发射 coins_changing 信号
func spend_coins(amount: int) -> bool:
	if player_coins >= amount:
		var old_coins = player_coins
		player_coins -= amount  # 立即减少实际钱币数量
		
		# 只发射动画信号，不发射 coins_changed 信号
		# PlayerUI 会在动画完成后自己更新显示
		coins_changing.emit(old_coins, player_coins, 0.1)
		if current_save_slot >= 0:
			SaveManager.save_game(current_save_slot, get_save_data())
		return true
	else:
		print("DEBUG: 钱币不足，需要", amount, "当前:", player_coins)
		return false

## 获取当前钱币数（新增）
func get_coins() -> int:
	return player_coins

# 记录已收集的道具
func mark_item_collected(item_id: String):
	if not item_id in collected_items:
		collected_items.append(item_id)
		if current_save_slot >= 0:
			SaveManager.save_game(current_save_slot, get_save_data())

# 检查道具是否已收集
func is_item_collected(item_id: String) -> bool:
	return item_id in collected_items

## 设置静态存档点（玩家主动存档）
func set_save_point(position: Vector2, save_point_id: String = "default_chair", scene_path: String = ScenePaths.GAME_MAIN):
	last_save_point["position"] = position
	last_save_point["scene_path"] = scene_path
	last_save_point["save_point_id"] = save_point_id
	
	# 关键修复：同时更新最后检查点（静态优先级高）
	last_checkpoint_position = position
	last_checkpoint_type = "static"
	
	# 恢复生命值
	player_current_health = player_max_health
	player_health_changed.emit(player_current_health)

## 新增：设置动态检查点
func set_dynamic_checkpoint(position: Vector2):
	last_checkpoint_position = position
	last_checkpoint_type = "dynamic"

## 新增：获取最后激活的检查点位置（死亡时使用）
func get_last_checkpoint_position() -> Vector2:
	return last_checkpoint_position

## 新增：清除动态检查点记录（退出游戏时）
func clear_dynamic_checkpoints():
	# 只清除动态检查点记录，恢复到静态
	last_checkpoint_position = get_save_point_position()
	last_checkpoint_type = "static"
	print("Global: 清除动态检查点记录，恢复到静态存档点")

# 获取最近存档点位置
func get_save_point_position() -> Vector2:
	var position = last_save_point.get("position", Vector2(0, 0))
	if typeof(position) == TYPE_VECTOR2:
		return position
	elif typeof(position) == TYPE_DICTIONARY:
		return Vector2(position.get("x", 0), position.get("y", 0))
	else:
		print("警告：存档位置数据损坏，使用默认位置")
		return Vector2(0, 0)
