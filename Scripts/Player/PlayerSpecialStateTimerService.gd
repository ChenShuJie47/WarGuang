extends RefCounted
class_name PlayerSpecialStateTimerService

# 处理特殊状态（睡眠、观察）计时器，仅在 IDLE 中推进。
static func handle_special_state_timers(player: Node, fixed_delta: float) -> void:
	if player.current_state == player.PlayerState.IDLE:
		player.sleep_timer += fixed_delta

		if player.is_pressing_up and not player.is_pressing_down:
			player.look_timer += fixed_delta
		elif player.is_pressing_down and not player.is_pressing_up:
			player.look_timer += fixed_delta
		else:
			player.look_timer = 0.0

		if player.sleep_timer >= player.idle_to_sleep_time:
			player.change_state(player.PlayerState.SLEEP)
			player.sleep_timer = 0.0
			return

		if player.is_pressing_up and not player.is_pressing_down and player.look_timer >= player.idle_to_look_time:
			player.change_state(player.PlayerState.LOOKUP)
			player.look_timer = 0.0
			return

		if player.is_pressing_down and not player.is_pressing_up and player.look_timer >= player.idle_to_look_time:
			player.change_state(player.PlayerState.LOOKDOWN)
			player.look_timer = 0.0
			return
	else:
		player.sleep_timer = 0.0
		player.look_timer = 0.0
