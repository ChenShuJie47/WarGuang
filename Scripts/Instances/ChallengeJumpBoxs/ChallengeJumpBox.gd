extends JumpBox
class_name ChallengeJumpBox

## ============================================
## 基础挑战 JumpBox - 所有变体的基类
## ============================================

# 状态变量
var challenge_id: String = ""  # 所属挑战 ID
var challenge_stage: int = 1  # 挑战阶段（1=第一阶段，2=第二阶段...）

## 信号
signal bounce_triggered(player)  # 被玩家触发时发出

## 触发弹跳（子类可以覆盖此方法添加额外逻辑）
func trigger_bounce(player):
	if not _can_trigger_for_player(player):
		return
	
	# 发出信号
	bounce_triggered.emit(player)
	await super.trigger_bounce(player)

## 获取当前状态（供子类访问）
func get_current_state() -> Dictionary:
	return {
		"is_active": is_active,
		"challenge_id": challenge_id,
		"challenge_stage": challenge_stage,
		"current_anim_state": current_anim_state
	}
