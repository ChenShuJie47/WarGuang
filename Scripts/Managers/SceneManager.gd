extends Node

var _scene_switch_in_progress: bool = false

# UI 场景切换统一入口（普通 UI 场景之间）。
func switch_scene(scene_path: String):
	if not _begin_scene_switch("switch_scene -> %s" % scene_path):
		return

	# 修复：切换场景前确保结束当前对话
	var dialogue_system = get_node_or_null("/root/DialogueSystem")
	if dialogue_system and dialogue_system.is_dialogue_active:
		dialogue_system.end_dialogue()

	var target_bgm = _resolve_target_bgm(scene_path)
	await _do_scene_transition(
		scene_path,
		FadeManager.ui_switch_fade_out_duration,
		FadeManager.ui_switch_black_hold_duration,
		FadeManager.ui_switch_fade_in_duration,
		target_bgm
	)
	_end_scene_switch()
	print("场景切换完成")

# 特殊处理：从 GameSettingScene 返回到 TitleScene
func return_to_title_from_game_setting(already_black: bool = false):
	if not _begin_scene_switch("return_to_title_from_game_setting"):
		return

	if already_black:
		if AudioManager:
			AudioManager.fade_out_bgm("main_game", 1.0)
		await _do_scene_transition(
			ScenePaths.UI_TITLE,
			0.0,
			FadeManager.ui_switch_black_hold_duration,
			FadeManager.ui_switch_fade_in_duration,
			"BGM0"
		)
	else:
		# 渐出游戏 BGM
		await AudioManager.fade_out_bgm("main_game", 1.0)
		await _do_scene_transition(
			ScenePaths.UI_TITLE,
			FadeManager.ui_switch_fade_out_duration,
			FadeManager.ui_switch_black_hold_duration,
			FadeManager.ui_switch_fade_in_duration,
			"BGM0"
		)
	
	# 关键修复：清除动态检查点记录
	Global.clear_dynamic_checkpoints()
	_end_scene_switch()

# 从存档进入游戏
func start_game_from_save(slot_index: int):
	if not _begin_scene_switch("start_game_from_save"):
		return

	# 新增：清理门注册（防止从标题重新进入时重复注册）
	var door_manager = get_node_or_null("/root/DoorManager")
	if door_manager and door_manager.has_method("clear_all_doors"):
		door_manager.clear_all_doors()
	
	Global.current_save_slot = slot_index
	
	# 记录开始时间（从点击存档开始）
	var start_time = Time.get_ticks_msec()
	
	# 加载存档数据
	if SaveManager.save_exists(slot_index):
		var data = SaveManager.load_game(slot_index)
		if not data.is_empty():
			Global.load_save_data(data)
		else:
			Global.initialize_new_game()
			SaveManager.save_game(slot_index, Global.get_save_data())
	else:
		Global.initialize_new_game()
		SaveManager.save_game(slot_index, Global.get_save_data())
	
	# 确保 TaskManager 重置 NPC 状态
	var task_manager = get_node_or_null("/root/TaskManager")
	if task_manager and task_manager.has_method("reset_for_scene_load"):
		task_manager.reset_for_scene_load()
	
	# 存档进游戏采用专用流程：淡出 -> 全黑保持 -> 切场并等待主场景可视准备 -> 淡入。
	var black_start_ms: int = Time.get_ticks_msec()
	await FadeManager.fade_out(FadeManager.ui_save_to_game_fade_out_duration)
	await AudioManager.play_bgm("BGM1", FadeManager.ui_save_to_game_fade_out_duration)
	get_tree().change_scene_to_file(ScenePaths.GAME_MAIN)
	await get_tree().process_frame
	var main_scene = get_tree().current_scene
	if main_scene and main_scene.has_method("wait_until_boot_visual_ready"):
		await main_scene.wait_until_boot_visual_ready()
	var elapsed_black: float = float(Time.get_ticks_msec() - black_start_ms) / 1000.0
	var remain_black: float = maxf(0.0, FadeManager.ui_save_to_game_black_hold_duration - elapsed_black)
	if remain_black > 0.0:
		await get_tree().create_timer(remain_black).timeout
	await FadeManager.fade_in(FadeManager.ui_save_to_game_fade_in_duration)

	# 等待一帧让淡入后的状态稳定
	await get_tree().process_frame
	
	# 确保 DialogueManager 重置
	if DialogueManager and DialogueManager.has_method("reset"):
		DialogueManager.reset()
	
	# 修复：确保 DialogueSystem 也重置
	var dialogue_system = get_node_or_null("/root/DialogueSystem")
	if dialogue_system and dialogue_system.has_method("reset"):
		dialogue_system.reset()
	
	# 强制重置 DialogueSystem 状态
	if DialogueSystem:
		DialogueSystem.is_dialogue_active = false
	
	# 确保 BGM 播放
	if RoomManager.current_room != "":
		await get_tree().create_timer(0.5).timeout
		RoomManager.switch_room_bgm(RoomManager.current_room)
	
	# 获取玩家实例
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var lock_time = player.warp_control_lock_time
		
		# 计算已用时间
		var elapsed_time = (Time.get_ticks_msec() - start_time) / 1000.0
		var remaining_time = max(0, lock_time - elapsed_time)
		
		# 等待剩余禁用时间
		if remaining_time > 0:
			await get_tree().create_timer(remaining_time).timeout
		
		# 恢复玩家控制
		player.set_player_control(true)
		player.exit_sleep_state()
		
		# 清除输入阻塞
		var viewport = get_viewport()
		if viewport:
			viewport.set_input_as_handled()

	_end_scene_switch()

func _resolve_target_bgm(scene_path: String) -> String:
	if scene_path == ScenePaths.UI_TITLE or scene_path == ScenePaths.UI_SAVE_SELECT or scene_path == ScenePaths.UI_SETTINGS:
		return "BGM0"
	if scene_path == ScenePaths.GAME_MAIN:
		return "BGM1"
	return ""

func _do_scene_transition(scene_path: String, fade_out_duration: float, black_hold_duration: float, fade_in_duration: float, target_bgm: String) -> void:
	await FadeManager.fade_out(fade_out_duration)

	if target_bgm != "":
		await AudioManager.play_bgm(target_bgm, fade_out_duration)

	get_tree().change_scene_to_file(scene_path)
	await get_tree().process_frame

	if black_hold_duration > 0.0:
		await get_tree().create_timer(black_hold_duration).timeout

	# 在黑屏准备淡出时触发新场景入场动画（此时仍处在黑屏下）。
	var current_scene := get_tree().current_scene
	if current_scene and current_scene.has_method("_on_scene_transition_enter_begin"):
		current_scene._on_scene_transition_enter_begin()

	await FadeManager.fade_in(fade_in_duration)

func _begin_scene_switch(tag: String) -> bool:
	if _scene_switch_in_progress:
		print("SceneManager: 切场请求被拒绝（进行中） tag=", tag)
		return false
	_scene_switch_in_progress = true
	return true

func _end_scene_switch() -> void:
	_scene_switch_in_progress = false
