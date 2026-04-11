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
	elif player:
		start_hit_stop(player, fallback_duration, fallback_intensity)

# 先优先走全局时间控制器的 Tier3 命中停顿。
static func trigger_tier3_with_fallback(player: Node, fallback_duration: float, fallback_intensity: float) -> void:
	if TimerControlManager and TimerControlManager.has_method("hit_stop"):
		TimerControlManager.hit_stop(3)
	elif player:
		start_hit_stop(player, fallback_duration, fallback_intensity)

# 受伤命中停顿统一入口：优先 TimerControlManager，失败再回退本地 start_hit_stop。
static func trigger_hurt(player: Node) -> void:
	if not player or not player.hit_stop_enabled:
		return
	trigger_tier2_with_fallback(player, FALLBACK_HURT_DURATION, FALLBACK_HURT_INTENSITY)

static func start_hurt_hit_stop(player: Node) -> void:
	trigger_hurt(player)

# JumpBox 命中停顿统一入口：perfect 使用 tier3，其它使用 tier2。
static func trigger_jumpbox(player: Node, trigger_grade: String = "normal") -> void:
	if not player or not player.hit_stop_enabled:
		return
	if trigger_grade == "perfect":
		trigger_tier3_with_fallback(player, FALLBACK_JUMPBOX_DURATION, FALLBACK_JUMPBOX_INTENSITY)
		return
	trigger_tier2_with_fallback(player, FALLBACK_JUMPBOX_DURATION, FALLBACK_JUMPBOX_INTENSITY)

static func start_jumpbox_hit_stop(player: Node, trigger_grade: String = "normal") -> void:
	trigger_jumpbox(player, trigger_grade)

static func start_hit_stop(player: Node, duration: float, intensity: float = 1.0) -> void:
	if not player.hit_stop_enabled or player.is_hit_stop:
		return

	var actual_duration: float = duration * intensity
	player.is_hit_stop = true
	player.saved_time_scale = Engine.time_scale
	Engine.time_scale = 0.0

	var start_time: int = Time.get_ticks_msec()
	var check_hit_stop_end = func():
		while player.is_hit_stop:
			var current_time: int = Time.get_ticks_msec()
			var elapsed: float = (current_time - start_time) / 1000.0
			if elapsed >= actual_duration:
				Engine.time_scale = player.saved_time_scale
				player.is_hit_stop = false
				break
			await player.get_tree().process_frame
	check_hit_stop_end.call()
