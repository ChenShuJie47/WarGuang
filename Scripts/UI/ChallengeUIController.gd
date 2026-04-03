extends RefCounted
class_name ChallengeUIController

var owner_node: Node = null
var challenge_ui_scene: PackedScene = null
var ui_fade_duration: float = 1.0

func setup(owner: Node, ui_scene: PackedScene, fade_duration: float) -> void:
	owner_node = owner
	challenge_ui_scene = ui_scene
	ui_fade_duration = fade_duration

func _find_challenge_ui() -> Node:
	var scene = owner_node.get_tree().current_scene
	var challenge_ui = scene.get_node_or_null("ChallengeUI")
	if challenge_ui:
		return challenge_ui

	var main_scene = owner_node.get_tree().root.get_node_or_null("MainGameScene")
	if main_scene:
		challenge_ui = main_scene.get_node_or_null("ChallengeUI")
	if challenge_ui:
		return challenge_ui

	var counters = owner_node.get_tree().get_nodes_in_group("challenge_counter")
	if counters.size() > 0:
		return counters[0]
	return null

func fade_out_player_ui() -> void:
	var player_ui = owner_node.get_tree().get_first_node_in_group("player_ui")
	if player_ui and player_ui.has_method("fade_out_ui_no_coin"):
		player_ui.fade_out_ui_no_coin(ui_fade_duration)
	elif player_ui and player_ui.has_method("fade_out_ui"):
		player_ui.fade_out_ui(ui_fade_duration)
	elif player_ui:
		player_ui.hide_ui_except_settings()

func show_challenge_ui() -> void:
	var challenge_ui = _find_challenge_ui()
	if challenge_ui != null:
		return

	if challenge_ui_scene == null:
		push_error("ChallengeUIController: challenge_ui_scene 未配置")
		return

	challenge_ui = challenge_ui_scene.instantiate()
	challenge_ui.name = "ChallengeUI"
	var main_scene = owner_node.get_tree().root.get_node_or_null("MainGameScene")
	if main_scene:
		main_scene.add_child(challenge_ui)
	else:
		owner_node.get_tree().current_scene.add_child(challenge_ui)

	if challenge_ui.has_node("MarginContainer"):
		var container = challenge_ui.get_node("MarginContainer")
		container.modulate.a = 0.0
	challenge_ui.add_to_group("challenge_counter")

func update_challenge_ui(current: int, target: int) -> void:
	var challenge_ui = _find_challenge_ui()
	if challenge_ui == null:
		show_challenge_ui()
		challenge_ui = _find_challenge_ui()
	if challenge_ui == null:
		return

	if challenge_ui.has_method("update_counter"):
		challenge_ui.update_counter(current, target)
	if challenge_ui.has_node("MarginContainer"):
		var container = challenge_ui.get_node("MarginContainer")
		if container.modulate.a < 1.0:
			var tween = owner_node.create_tween()
			tween.tween_property(container, "modulate:a", 1.0, ui_fade_duration)

func hide_challenge_ui_with_fade(on_complete: Callable) -> void:
	var challenge_ui = _find_challenge_ui()
	if challenge_ui == null:
		return

	if challenge_ui.has_node("MarginContainer"):
		var container = challenge_ui.get_node("MarginContainer")
		var tween = owner_node.create_tween()
		tween.tween_property(container, "modulate:a", 0.0, ui_fade_duration)
		if on_complete.is_valid():
			tween.tween_callback(on_complete.bind(challenge_ui))
		else:
			tween.tween_callback(challenge_ui.queue_free)
	else:
		challenge_ui.queue_free()

func fade_in_player_ui() -> void:
	var player_ui = owner_node.get_tree().get_first_node_in_group("player_ui")
	if player_ui == null:
		return

	if player_ui.has_node("HealthContainer"):
		player_ui.get_node("HealthContainer").visible = true
		player_ui.get_node("HealthContainer").modulate.a = 0.0
	if player_ui.has_node("PlayerIcon"):
		player_ui.get_node("PlayerIcon").visible = true
		player_ui.get_node("PlayerIcon").modulate.a = 0.0

	var fade_tween = owner_node.create_tween()
	fade_tween.set_parallel(true)
	if player_ui.has_node("HealthContainer"):
		fade_tween.parallel().tween_property(player_ui.get_node("HealthContainer"), "modulate:a", 1.0, ui_fade_duration)
	if player_ui.has_node("PlayerIcon"):
		fade_tween.parallel().tween_property(player_ui.get_node("PlayerIcon"), "modulate:a", 1.0, ui_fade_duration)
