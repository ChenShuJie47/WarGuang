extends Area2D
class_name BaseJumpBox

## 触发判定设置
@export_category("触发判定")
## 完美触发判定窗口（秒）
@export var perfect_trigger_window: float = 0.12

## 通用反馈设置
@export_category("通用反馈")
## 是否启用触发白闪（打击感）
@export var trigger_white_flash_enabled: bool = true
## 白闪持续时间（秒）
@export var trigger_white_flash_duration: float = 0.1
## 普通触发音效（可选）
@export var normal_trigger_sfx: AudioStream
## 完美触发音效（可选）
@export var perfect_trigger_sfx: AudioStream

var overlapping_players: Dictionary = {}
var pending_perfect_until_ms: Dictionary = {}

var _trigger_flash_default_modulate: Color = Color.WHITE
var _trigger_sfx_player: AudioStreamPlayer2D = null

func _base_setup_trigger_detection() -> void:
	if body_entered.is_connected(_on_body_entered_base) == false:
		body_entered.connect(_on_body_entered_base)
	if body_exited.is_connected(_on_body_exited_base) == false:
		body_exited.connect(_on_body_exited_base)
	_setup_trigger_sfx_player()
	_prepare_trigger_flash_defaults()

func _base_process_trigger_detection() -> void:
	_check_overlapping_players_for_trigger()

func _on_body_entered_base(body) -> void:
	if body and body.is_in_group("player"):
		overlapping_players[body.get_instance_id()] = body
	if _can_trigger_for_player(body):
		trigger_bounce(body)

func _on_body_exited_base(body) -> void:
	if not body:
		return
	overlapping_players.erase(body.get_instance_id())
	pending_perfect_until_ms.erase(body.get_instance_id())

func _check_overlapping_players_for_trigger() -> void:
	if not _is_trigger_active():
		return
	for player in overlapping_players.values():
		if not is_instance_valid(player):
			continue
		if _can_trigger_for_player(player):
			trigger_bounce(player)
			return

func _can_trigger_for_player(body) -> bool:
	if not body:
		return false
	if not body.is_in_group("player"):
		return false
	if not _is_trigger_active() or not _is_visual_yes_state():
		return false
	if body.current_state == body.PlayerState.DASH:
		return false
	if not body.has_double_jumped:
		return false
	if not _is_player_jumpbox_eligible(body):
		return false
	if body.has_method("can_accept_jumpbox_bounce") and not body.can_accept_jumpbox_bounce():
		return false
	return true

func _is_player_jumpbox_eligible(body) -> bool:
	if body.current_animation == "JUMP2":
		return true
	if body.has_method("is_recent_double_jump_start"):
		return body.is_recent_double_jump_start(perfect_trigger_window)
	return false

func _determine_trigger_grade(player) -> String:
	if player.has_method("is_recent_double_jump_start") and player.is_recent_double_jump_start(perfect_trigger_window):
		return "perfect"
	var player_id = player.get_instance_id()
	var now_ms = Time.get_ticks_msec()
	if pending_perfect_until_ms.has(player_id) and now_ms <= int(pending_perfect_until_ms[player_id]):
		return "perfect"
	return "normal"

func _mark_perfect_candidates_on_yes_activation() -> void:
	var now_ms = Time.get_ticks_msec()
	var expiry_ms = now_ms + int(perfect_trigger_window * 1000.0)
	for player in overlapping_players.values():
		if not is_instance_valid(player):
			continue
		if not player.is_in_group("player"):
			continue
		if not player.has_double_jumped:
			continue
		if player.current_animation != "JUMP2":
			continue
		pending_perfect_until_ms[player.get_instance_id()] = expiry_ms

func trigger_bounce(player):
	if not _can_trigger_for_player(player):
		return

	var trigger_grade = _determine_trigger_grade(player)
	_apply_trigger_effect(player, trigger_grade)
	_apply_common_feedback(player, trigger_grade)
	pending_perfect_until_ms.erase(player.get_instance_id())
	var post_result = _consume_after_trigger(player, trigger_grade)
	if post_result is GDScriptFunctionState:
		await post_result

func _apply_common_feedback(_player, trigger_grade: String) -> void:
	_play_trigger_sfx(trigger_grade)
	_play_trigger_flash()

func _play_trigger_sfx(trigger_grade: String) -> void:
	if _trigger_sfx_player == null:
		return
	var stream: AudioStream = perfect_trigger_sfx if trigger_grade == "perfect" else normal_trigger_sfx
	if stream == null:
		return
	_trigger_sfx_player.stream = stream
	_trigger_sfx_player.play()

func _play_trigger_flash() -> void:
	if not trigger_white_flash_enabled:
		return
	var sprite := _get_trigger_sprite()
	if sprite == null:
		return
	sprite.modulate = Color(2.0, 2.0, 2.0, 1.0)
	var timer = get_tree().create_timer(trigger_white_flash_duration)
	timer.timeout.connect(func():
		if is_instance_valid(sprite):
			sprite.modulate = _trigger_flash_default_modulate
	)

func _prepare_trigger_flash_defaults() -> void:
	var sprite := _get_trigger_sprite()
	if sprite != null:
		_trigger_flash_default_modulate = sprite.modulate

func _setup_trigger_sfx_player() -> void:
	if is_instance_valid(_trigger_sfx_player):
		return
	_trigger_sfx_player = get_node_or_null("TriggerSFX") as AudioStreamPlayer2D
	if _trigger_sfx_player == null:
		_trigger_sfx_player = AudioStreamPlayer2D.new()
		_trigger_sfx_player.name = "TriggerSFX"
		add_child(_trigger_sfx_player)

func _get_trigger_sprite() -> CanvasItem:
	return null

func _is_trigger_active() -> bool:
	return false

func _is_visual_yes_state() -> bool:
	return false

func _apply_trigger_effect(_player, _trigger_grade: String) -> void:
	pass

func _consume_after_trigger(_player, _trigger_grade: String) -> void:
	pass
