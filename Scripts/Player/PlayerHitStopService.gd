extends RefCounted
class_name PlayerHitStopService

static func trigger_tier2_with_fallback(player: Node, fallback_duration: float, fallback_intensity: float) -> void:
	if TimerControlManager and TimerControlManager.has_method("hit_stop"):
		TimerControlManager.hit_stop(2)
	elif player and player.has_method("start_hit_stop"):
		player.start_hit_stop(fallback_duration, fallback_intensity)

static func trigger_tier3_with_fallback(player: Node, fallback_duration: float, fallback_intensity: float) -> void:
	if TimerControlManager and TimerControlManager.has_method("hit_stop"):
		TimerControlManager.hit_stop(3)
	elif player and player.has_method("start_hit_stop"):
		player.start_hit_stop(fallback_duration, fallback_intensity)
