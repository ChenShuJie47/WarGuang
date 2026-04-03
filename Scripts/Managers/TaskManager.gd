extends Node

## 单例实例
static var instance: TaskManager

## NPC对话记录
var npc_interactions: Dictionary = {}  # 格式: {npc_id: count}

## 任务状态
var tasks_completed: Dictionary = {}

## 特殊对话标记
var special_dialogues_shown: Dictionary = {}

func _ready():
	instance = self

## 记录NPC对话
func record_npc_dialogue(npc_id: String):
	if not npc_id in npc_interactions:
		npc_interactions[npc_id] = 0
	
	npc_interactions[npc_id] += 1
	
	# 强制保存到全局存档
	if Global.current_save_slot >= 0:
		# 等待一帧确保所有状态更新
		await get_tree().process_frame
		SaveManager.save_game(Global.current_save_slot, Global.get_save_data())



## 获取NPC对话次数
func get_npc_dialogue_count(npc_id: String) -> int:
	return npc_interactions.get(npc_id, 0)

## 标记特殊对话已显示
func mark_special_dialogue_shown(dialogue_id: String):
	special_dialogues_shown[dialogue_id] = true
	# 立即保存到全局存档
	if Global.current_save_slot >= 0:
		SaveManager.save_game(Global.current_save_slot, Global.get_save_data())

## 检查特殊对话是否已显示
func has_special_dialogue_been_shown(dialogue_id: String) -> bool:
	return dialogue_id in special_dialogues_shown

## 完成任务
func complete_task(task_name: String):
	tasks_completed[task_name] = true
	
	# 通过Global解锁能力
	if Global and Global.has_method("unlock_ability"):
		var ability_name = task_name.replace("unlock_", "")
		Global.unlock_ability(ability_name)
	else:
		print("TaskManager: 错误 - Global.unlock_ability方法不存在")

## 检查任务状态
func is_task_complete(task_name: String) -> bool:
	return task_name in tasks_completed and tasks_completed[task_name]

## 重置为新游戏状态
func reset_for_new_game():
	npc_interactions = {}
	tasks_completed = {}
	special_dialogues_shown = {}

func reset_for_scene_load():
	# 重置 NPC 对话状态，确保可以重新交互
	print("TaskManager: 重置 NPC 状态用于场景加载")
	# 不需要清空数据，只需要确保 NPC 可以正常交互
