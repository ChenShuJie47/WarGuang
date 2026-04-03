extends Node

# 场景切换管理器
# 在SceneManager.gd中添加BGM管理
func switch_scene(scene_path: String, fade_duration: float = 0.5):
	# 修复：切换场景前确保结束当前对话
	var dialogue_system = get_node_or_null("/root/DialogueSystem")
	if dialogue_system and dialogue_system.is_dialogue_active:
		dialogue_system.end_dialogue()
	# 根据目标场景决定 BGM
	var target_bgm = ""
	if scene_path == ScenePaths.UI_TITLE or scene_path == ScenePaths.UI_SAVE_SELECT or scene_path == ScenePaths.UI_SETTINGS:
		target_bgm = "BGM0"
	elif scene_path == ScenePaths.GAME_MAIN:
		target_bgm = "BGM1"
	
	# 渐黑
	await FadeManager.fade_out(fade_duration)
	
	# 切换 BGM（如果需要）
	if target_bgm != "":
		await AudioManager.play_bgm(target_bgm, fade_duration)
	
	# 切换场景
	get_tree().change_scene_to_file(scene_path)
	
	# 等待一帧确保新场景加载完成
	await get_tree().process_frame
	# 渐显
	await FadeManager.fade_in(fade_duration)
	
	print("场景切换完成")

# 特殊处理：从 GameSettingScene 返回到 TitleScene
func return_to_title_from_game_setting():
	# 渐出游戏 BGM
	await AudioManager.fade_out_bgm("main_game", 1.0)
	
	# 切换场景
	await switch_scene(ScenePaths.UI_TITLE, 0.25)
	
	# 关键修复：清除动态检查点记录
	Global.clear_dynamic_checkpoints()
	
	# 渐入 UI BGM
	await AudioManager.fade_in_bgm("BGM0", 1.0)

# 从存档进入游戏
func start_game_from_save(slot_index: int, fade_duration: float = 1.0):
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
	
	# 带转场效果进入游戏
	await switch_scene("res://Scenes/GameScenes/MainGameScene.tscn", fade_duration)
	
	# 等待场景加载完成
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
