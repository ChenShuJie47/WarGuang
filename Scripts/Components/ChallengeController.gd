extends Node
class_name ChallengeController
const ChallengeUIControllerScript = preload("res://Scripts/UI/ChallengeUIController.gd")

## ============================================
## ChallengeController - 挑战系统核心控制器
## ============================================
## 功能:
## - 挑战流程控制
## - JumpBox 生成管理
## - 失败条件检测
## - UI 管理
## ============================================

## 配置资源（在 Inspector 中指定）
@export var config: ChallengeConfig

## UI 过渡配置
@export_category("UI Transition")
## UI 淡入淡出时间（秒）
@export var ui_fade_duration: float = 1.0

## 挑战 UI 场景（由 ManiacNPC 传递过来）
var challenge_ui_scene: PackedScene

## 挑战状态
enum State { INACTIVE, ACTIVE, SUCCESS, FAILED }
var current_state: State = State.INACTIVE

## 运行时变量
var triggered_count: int = 0
var spawned_jumpboxes: Array = []  # 当前生成的 JumpBox 数组
var challenge_bounds: Rect2
var respawn_timers: Dictionary = {}  # spawn_point_index -> timer
var has_triggered_first: bool = false  # 是否已触发第一个 JumpBox
var runtime_spawn_points: Array[Marker2D] = []  # 运行时生成点缓存（不污染资源）
var player_ref: Node = null
var ui_controller = null

## 信号
signal challenge_started()
signal challenge_completed()
signal challenge_failed()

func _ready():
	ui_controller = ChallengeUIControllerScript.new()
	ui_controller.setup(self, challenge_ui_scene, ui_fade_duration)

## 初始化挑战边界和生成点
func _init_challenge_bounds():
	# 获取 ManiacNPC（父节点）
	var maniac_npc = get_parent()
	
	# 尝试获取 NPC_Areas 层
	var npcs_layer = maniac_npc.get_parent()  # NPCs
	var areas_layer = null
	if npcs_layer.has_node("../NPC_Areas"):
		areas_layer = npcs_layer.get_node("../NPC_Areas")
	elif maniac_npc.has_node("../../NPC_Areas"):
		areas_layer = maniac_npc.get_node("../../NPC_Areas")
	
	if not areas_layer:
		push_error("ChallengeController: 找不到 NPC_Areas 层！")
		return
	
	# 从 NPC_Areas 获取 ChallengeArea
	var challenge_area_name = "Maniac_Challenge/ChallengeArea"
	if areas_layer.has_node(challenge_area_name):
		var challenge_area = areas_layer.get_node(challenge_area_name)
		if challenge_area and challenge_area.has_method("get_global_rect"):
			challenge_bounds = challenge_area.get_global_rect()
			
	else:
		push_warning("ChallengeController: 未找到挑战区域 ", challenge_area_name)
	
	# 关键修复：根据配置名称查找对应的 SpawnPoints 容器
	var spawn_points_name = _get_spawn_points_name()
	var spawn_points_container = maniac_npc.get_node_or_null(spawn_points_name)
	
	if not spawn_points_container:
		push_error("ChallengeController: 没有找到指定的 SpawnPoints 容器 [", spawn_points_name, "]！请在 ManiacNPC 下创建该节点")
		return
	
	if spawn_points_container:
		# 清空并重新收集所有 Marker2D 子节点
		runtime_spawn_points.clear()
		for child in spawn_points_container.get_children():
			if child is Marker2D:
				runtime_spawn_points.append(child)
				# 关键修复：强制更新 global_position，确保 transform 正确累积
				child.force_update_transform()

## 根据配置名称获取生成点节点名称
func _get_spawn_points_name() -> String:
	if not config:
		return "SpawnPoints"

	if config.stage_id > 0:
		return "SpawnPoints" + str(config.stage_id)
	
	var challenge_name = config.challenge_name
	
	# 修复：支持多种命名方式
	# 方式 1: "疯子挑战 1", "疯子挑战 2"...
	# 方式 2: "疯子挑战 第一阶段", "疯子挑战 第二阶段"...
	# 方式 3: "Challenge1", "Challenge2"...
	
	if challenge_name.contains("1") or challenge_name.contains("第一阶段"):
		return "SpawnPoints1"
	elif challenge_name.contains("2") or challenge_name.contains("第二阶段"):
		return "SpawnPoints2"
	elif challenge_name.contains("3") or challenge_name.contains("第三阶段"):
		return "SpawnPoints3"
	elif challenge_name.contains("4") or challenge_name.contains("第四阶段"):
		return "SpawnPoints4"
	# 未来扩展：添加更多阶段...
	
	# 默认回退
	return "SpawnPoints"

func _init_spawn_points():
	# 修复：ChallengeController 的父节点是 ManiacNPC
	var maniac_npc = get_parent()
	
	var spawn_points_name = _get_spawn_points_name()
	
	var spawn_points_node: Node = null
	
	# 在 ManiacNPC 的子节点中查找
	if maniac_npc.has_node(spawn_points_name):
		spawn_points_node = maniac_npc.get_node(spawn_points_name)
	else:
		# 回退方案：查找任意 SpawnPoints
		if maniac_npc.has_node("SpawnPoints"):
			spawn_points_node = maniac_npc.get_node("SpawnPoints")
	
	if spawn_points_node:
		var spawn_points = []
		
		for child in spawn_points_node.get_children():
			if child is Marker2D:
				spawn_points.append(child)
		
		spawn_points.sort_custom(func(a, b): return a.name < b.name)
		
		if config:
			config.spawn_points = spawn_points
		
	else:
		push_warning("ChallengeController: 没有找到 SpawnPoints 节点！请在 ManiacNPC 下创建", spawn_points_name)

func start_challenge():
	if current_state == State.ACTIVE:
		return
	
	if not config:
		push_error("ChallengeController: 配置无效！")
		return
	
	# 修复：启动挑战时才初始化区域和生成点
	_init_challenge_bounds()
	if runtime_spawn_points.is_empty():
		push_error("ChallengeController: 运行时生成点为空！")
		return
	
	current_state = State.ACTIVE
	triggered_count = 0
	respawn_timers.clear()
	has_triggered_first = false
	if ui_controller != null:
		ui_controller.setup(self, challenge_ui_scene, ui_fade_duration)
	
	var tween = create_tween()
	tween.set_parallel(true)
	
	tween.tween_callback(_fade_out_player_ui)
	tween.tween_callback(_spawn_all_jumpboxes)
	tween.tween_callback(_show_challenge_ui)
	tween.tween_callback(_update_challenge_ui)
	
	challenge_started.emit()

## 带淡出效果隐藏玩家 UI（不管钱币 UI）
func _fade_out_player_ui():
	if ui_controller != null:
		ui_controller.fade_out_player_ui()

func _spawn_all_jumpboxes():
	if not config or runtime_spawn_points.is_empty():
		push_error("ChallengeController: 没有配置生成点！")
		return
	
	for i in range(runtime_spawn_points.size()):
		var spawn_point = runtime_spawn_points[i]
		if not is_instance_valid(spawn_point):
			print("DEBUG ChallengeController: 生成点 ", i, " 无效！")
			continue
		
		_spawn_jumpbox_at(spawn_point)

func _spawn_jumpbox_at(spawn_point: Marker2D):
	if not config.jumpbox_scene:
		push_error("ChallengeController: 没有配置 JumpBox 场景！")
		return
	
	var jumpbox = config.jumpbox_scene.instantiate()
	jumpbox.global_position = spawn_point.global_position
	jumpbox.challenge_id = config.challenge_name
	
	# 关键修复：添加到 MainGameScene 而不是 current_scene（确保坐标系统一）
	var main_scene = get_tree().root.get_node_or_null("MainGameScene")
	if main_scene:
		main_scene.add_child(jumpbox)
	else:
		get_tree().current_scene.add_child(jumpbox)
	spawned_jumpboxes.append(jumpbox)
	
	if jumpbox.has_signal("bounce_triggered"):
		jumpbox.bounce_triggered.connect(_on_jumpbox_bounce_triggered.bind(jumpbox, spawn_point))

func _on_jumpbox_bounce_triggered(body, jumpbox, spawn_point):
	if body.is_in_group("player") and current_state == State.ACTIVE:
		if body.current_animation != "JUMP2":
			return
		
		# 修复：立即增加计数并更新 UI
		triggered_count += 1
		
		if jumpbox in spawned_jumpboxes:
			spawned_jumpboxes.erase(jumpbox)
		
		# 修复：立即更新 UI
		_update_challenge_ui()
		
		has_triggered_first = true
		
		var spawn_index = runtime_spawn_points.find(spawn_point)
		
		if jumpbox.animated_sprite and jumpbox.animated_sprite.sprite_frames:
			if jumpbox.animated_sprite.sprite_frames.has_animation("END"):
				jumpbox.animated_sprite.play("END")
				await jumpbox.animated_sprite.animation_finished
		
		jumpbox.queue_free()
		
		if triggered_count >= config.target_count:
			_complete_challenge()
		else:
			respawn_timers[spawn_index] = config.cooldown_time

func _process(_delta):
	if current_state == State.ACTIVE:
		# 更新所有重生计时器（每个生成点独立）
		for spawn_index in respawn_timers.keys():
			respawn_timers[spawn_index] -= _delta
			if respawn_timers[spawn_index] <= 0:
				_on_respawn_timer_finished(spawn_index)
				respawn_timers.erase(spawn_index)
		
		# 检查失败条件（落地或离开区域）
		_check_failure_conditions()

func _on_respawn_timer_finished(spawn_index: int):
	if current_state != State.ACTIVE:
		return
	
	if spawn_index < runtime_spawn_points.size():
		var spawn_point = runtime_spawn_points[spawn_index]
		_spawn_jumpbox_at(spawn_point)
	else:
		print("DEBUG ChallengeController: 生成点 ", spawn_index, " 无效，跳过重生")

func _get_player() -> Node:
	if is_instance_valid(player_ref):
		return player_ref
	player_ref = get_tree().get_first_node_in_group("player")
	return player_ref

func _check_failure_conditions():
	var player = _get_player()
	if not player:
		return
	
	if config.require_in_bounds:
		var player_pos = player.global_position
		var in_bounds = challenge_bounds.has_point(player_pos)
		
		if not in_bounds:
			print("DEBUG ChallengeController: 玩家离开挑战区域，挑战失败")
			_fail_challenge()
			return
	
	if config.require_no_floor and has_triggered_first:
		if player.is_on_floor():
			print("DEBUG ChallengeController: 玩家落地，挑战失败")
			_fail_challenge()
			return

## 完成挑战
func _complete_challenge():
	if current_state != State.ACTIVE:
		return
	
	# 修复：先改变状态，_process 会停止检测
	current_state = State.SUCCESS
	
	# 清理所有重生计时器
	respawn_timers.clear()
	
	await _play_end_animation_and_cleanup_force()
	
	# 修复：同步淡出挑战 UI 和淡入玩家 UI
	_hide_challenge_ui_with_fade()
	_do_fade_in_player_ui()
	
	challenge_completed.emit()

## 挑战失败
func _fail_challenge():
	if current_state != State.ACTIVE:
		return
	
	# 修复：先改变状态，_process 会停止检测
	current_state = State.FAILED
	
	# 清理所有重生计时器
	respawn_timers.clear()
	
	await _play_end_animation_and_cleanup_force()
	
	# 修复：同步淡出挑战 UI 和淡入玩家 UI（与成功逻辑保持一致）
	_hide_challenge_ui_with_fade()
	_do_fade_in_player_ui()
	
	challenge_failed.emit()

## 播放所有剩余 JumpBox 的 END 动画并清理（同时销毁）
func _play_end_animation_and_cleanup_force():
	if spawned_jumpboxes.is_empty():
		return
	
	for jumpbox in spawned_jumpboxes:
		if is_instance_valid(jumpbox):
			jumpbox.set_inactive()
			jumpbox.current_anim_state = jumpbox.AnimState.FLY
			
			if jumpbox.animated_sprite and jumpbox.animated_sprite.sprite_frames:
				if jumpbox.animated_sprite.sprite_frames.has_animation("END"):
					jumpbox.animated_sprite.play("END")
	
	var max_wait_time = 0.0
	for jumpbox in spawned_jumpboxes:
		if is_instance_valid(jumpbox) and jumpbox.animated_sprite:
			if jumpbox.animated_sprite.sprite_frames:
				if jumpbox.animated_sprite.sprite_frames.has_animation("END"):
					var anim_length = jumpbox.animated_sprite.sprite_frames.get_frame_duration("END", 0)
					max_wait_time = max(max_wait_time, anim_length)
	
	await get_tree().create_timer(max_wait_time).timeout
	
	for jumpbox in spawned_jumpboxes:
		if is_instance_valid(jumpbox):
			jumpbox.queue_free()
	
	spawned_jumpboxes.clear()

## 通用清理逻辑（挑战和失败都用）
func _cleanup_challenge_common():
	if spawned_jumpboxes.is_empty():
		return
	
	# 同时销毁所有 JumpBox（不播放 END 动画）
	for jumpbox in spawned_jumpboxes:
		if is_instance_valid(jumpbox):
			jumpbox.queue_free()
	
	spawned_jumpboxes.clear()

func _update_challenge_ui():
	if ui_controller != null:
		ui_controller.update_challenge_ui(triggered_count, config.target_count)

func _show_challenge_ui():
	if ui_controller != null:
		ui_controller.show_challenge_ui()

func _hide_challenge_ui_with_fade():
	if ui_controller != null:
		ui_controller.hide_challenge_ui_with_fade(_on_challenge_ui_fade_out_complete)

## 带淡入效果恢复玩家 UI（真正的淡入实现）
func _do_fade_in_player_ui():
	if ui_controller != null:
		ui_controller.fade_in_player_ui()

func _hide_challenge_ui():
	var challenge_ui = get_tree().current_scene.get_node_or_null("ChallengeUI")
	if challenge_ui:
		challenge_ui.queue_free()

## 挑战 UI 淡出完成回调
func _on_challenge_ui_fade_out_complete(challenge_ui: Node):
	if is_instance_valid(challenge_ui):
		challenge_ui.queue_free()
