extends RefCounted
class_name PlayerDialogueStateService

# 对话开始：强制进入 INTERACTIVE 并停止水平移动。
static func on_dialogue_started(player: Node) -> void:
	player.change_state(player.PlayerState.INTERACTIVE)
	player.is_in_dialogue = true
	player.velocity.x = 0.0
	player.update_animation()

# 对话期间：锁定水平，保留重力。
static func handle_dialogue_physics(player: Node, fixed_delta: float) -> void:
	player.velocity.x = 0.0
	player.apply_gravity(fixed_delta)

# 对话结束：延迟一帧后恢复到地面/空中基础状态。
static func on_dialogue_ended(player: Node) -> void:
	player.is_in_dialogue = false
	await player.get_tree().process_frame
	if player.current_state == player.PlayerState.INTERACTIVE:
		print("Player: 从 INTERACTIVE 状态退出")
		if player.is_on_floor():
			player.change_state(player.PlayerState.IDLE)
		else:
			player.change_state(player.PlayerState.DOWN)
