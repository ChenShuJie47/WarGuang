extends RefCounted
class_name PlayerHitStopService

const FALLBACK_HURT_DURATION: float = 0.1
const FALLBACK_HURT_INTENSITY: float = 1.2
const FALLBACK_JUMPBOX_DURATION: float = 0.25
const FALLBACK_JUMPBOX_INTENSITY: float = 0.8

# 先优先走全局时间控制器的 Tier2 命中停顿。
static func trigger_tier2_with_fallback(player: Node, fallback_duration: float, fallback_intensity: float) -> void:
	if TimerControlManager and TimerControlManager.has_method("hit_stop"):
		TimerControlManager.hit_stop(2)
	elif player and player.has_method("start_hit_stop"):
		player.start_hit_stop(fallback_duration, fallback_intensity)

# 先优先走全局时间控制器的 Tier3 命中停顿。
static func trigger_tier3_with_fallback(player: Node, fallback_duration: float, fallback_intensity: float) -> void:
	if TimerControlManager and TimerControlManager.has_method("hit_stop"):
		TimerControlManager.hit_stop(3)
	elif player and player.has_method("start_hit_stop"):
		player.start_hit_stop(fallback_duration, fallback_intensity)

# 受伤命中停顿统一入口：优先 TimerControlManager，失败再回退本地 start_hit_stop。
static func trigger_hurt(player: Node) -> void:
	if not player or not player.hit_stop_enabled:
		return
	trigger_tier2_with_fallback(player, FALLBACK_HURT_DURATION, FALLBACK_HURT_INTENSITY)

# JumpBox 命中停顿统一入口：perfect 使用 tier3，其它使用 tier2。
static func trigger_jumpbox(player: Node, trigger_grade: String = "normal") -> void:
	if not player or not player.hit_stop_enabled:
		return
	if trigger_grade == "perfect":
		trigger_tier3_with_fallback(player, FALLBACK_JUMPBOX_DURATION, FALLBACK_JUMPBOX_INTENSITY)
		return
	trigger_tier2_with_fallback(player, FALLBACK_JUMPBOX_DURATION, FALLBACK_JUMPBOX_INTENSITY)
