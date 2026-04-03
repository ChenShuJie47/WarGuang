extends Node

signal dialogue_started()
signal dialogue_ended()

signal effect_triggered(effect_name)

var is_dialogue_active: bool = false

# 修改：使用简单的字典而不是自定义类
func create_dialogue_state(player) -> Dictionary:
	return {
		"black_dash_unlocked": player.black_dash_unlocked,
		"dash_unlocked": player.dash_unlocked,
		"double_jump_unlocked": player.double_jump_unlocked,
		"glide_unlocked": player.glide_unlocked,
		"wall_grip_unlocked": player.wall_grip_unlocked,
		"super_dash_unlocked": player.super_dash_unlocked
	}

func validate_dialogue_conditions(npc_id: String, player) -> void:
	print("=== 对话条件验证 ===")
	print("NPC ID:", npc_id)
	print("黑色冲刺解锁:", player.black_dash_unlocked)
	print("超级冲刺解锁:", player.super_dash_unlocked)
	print("===================")

func start_dialogue():
	if not is_dialogue_active:
		is_dialogue_active = true
		dialogue_started.emit()
		print("DialogueSystem: 对话开始")

func end_dialogue():
	if is_dialogue_active:
		is_dialogue_active = false
		dialogue_ended.emit()

# 新增：重置对话系统状态（用于场景切换时）
func reset():
	is_dialogue_active = false
	print("DialogueSystem: 状态已重置")

func trigger_effect(effect_name: String):
	effect_triggered.emit(effect_name)
