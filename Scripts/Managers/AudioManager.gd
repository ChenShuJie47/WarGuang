# AudioManager.gd
extends Node

## 音频总线名称
const MASTER_BUS = "Master"
const BGM_BUS = "BGM" 
const SFX_BUS = "SFX"
const VOICE_BUS = "Voice"

## 音频配置
const BGM_FADE_IN_DURATION: float = 1.0  ## BGM淡入持续时间（秒）
const BGM_FADE_OUT_DURATION: float = 1.0  ## BGM淡出持续时间（秒）
const BGM_CROSSFADE_DURATION: float = 1.0  ## BGM交叉淡入淡出持续时间（秒）
const BGM_DUCK_DURATION: float = 1.0  ## 音频闪避持续时间（秒）
const BGM_DUCK_VOLUME: float = 0.5  ## 音频闪避时的音量（0-1）

# BGM优先级 - 区域BGM设为同级，Boss设为更高
var bgm_priorities = {
	"BGM0": 1,    # UI BGM
	"BGM1": 2,    # 区域BGM
	"BGM1x": 2,   # 区域BGM
	"BGM3": 2,    # 区域BGM
	"boss": 3     # Boss BGM
}

# 音频文件路径 - 更新为正确的BGM名称
var bgm_paths = {
	"BGM0": "res://Assets/Audios/BGM/BGM0荒凉无边.mp3",
	"BGM1": "res://Assets/Audios/BGM/BGM1炽天使战斗曲.mp3",
	"BGM1x": "res://Assets/Audios/BGM/BGM1x宁静八音盒.mp3",
	"BGM3": "res://Assets/Audios/BGM/BGM3恐惧追逐.mp3",
	"boss": ""  # 后续添加
}

# 分类音效路径
var sfx_ui_paths = {
	"button_click": "res://Assets/Audios/SFX/UI/鼠标点击音效.mp3"
}

var sfx_instances_paths = {
	"save_game": "res://Assets/Audios/SFX/Instances/存档点交互音效.mp3"
}

var sfx_player_paths = {
	# 玩家相关音效 - 后续添加
}

var sfx_environment_paths = {
	# 环境音效 - 后续添加
}

# 当前播放的BGM
var current_bgm: String = ""
var current_bgm_priority: int = 0
var bgm_players: Dictionary = {}
var bgm_tweens: Dictionary = {}
var audio_duck_tween: Tween
## 房间BGM管理
var room_bgm_map: Dictionary = {}  # 房间ID -> BGM名称
var current_room_bgm: String = ""
var is_event_bgm_playing: bool = false

func _ready():
	print("AudioManager: 初始化")
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# 预创建BGM播放器
	for bgm_name in bgm_paths:
		if bgm_paths[bgm_name] and ResourceLoader.exists(bgm_paths[bgm_name]):  # 检查文件是否存在
			var player = AudioStreamPlayer.new()
			player.bus = BGM_BUS
			player.name = "BGM_" + bgm_name
			player.process_mode = Node.PROCESS_MODE_ALWAYS
			add_child(player)
			bgm_players[bgm_name] = player
		else:
			print("AudioManager: 警告 - BGM文件不存在: ", bgm_name, " 路径: ", bgm_paths.get(bgm_name, ""))

# 播放BGM（带优先级检查）
func play_bgm(bgm_name: String, fade_duration: float = BGM_FADE_IN_DURATION):
	if not bgm_paths.has(bgm_name) or not bgm_paths[bgm_name]:
		print("AudioManager: 错误 - 未找到BGM: ", bgm_name)
		return
	
	# 检查文件是否存在
	if not ResourceLoader.exists(bgm_paths[bgm_name]):
		print("AudioManager: 错误 - BGM文件不存在: ", bgm_paths[bgm_name])
		return
	
	var priority = bgm_priorities.get(bgm_name, 0)
	
	# 检查优先级
	if priority < current_bgm_priority and current_bgm != "":
		print("AudioManager: 忽略低优先级BGM: ", bgm_name)
		return
	
	# 如果已经在播放相同的BGM，不做任何事
	if current_bgm == bgm_name:
		return
	
	# 淡出当前BGM
	if current_bgm != "":
		await fade_out_bgm(current_bgm, fade_duration)
	
	var player = bgm_players[bgm_name]
	if player.stream == null:
		var stream = load(bgm_paths[bgm_name])
		if stream:
			player.stream = stream
			player.finished.connect(_on_bgm_finished.bind(bgm_name))
	
	# 淡入新BGM
	await fade_in_bgm(bgm_name, fade_duration)
	current_bgm = bgm_name
	current_bgm_priority = priority

# 统一的音效播放方法
func play_sfx(sfx_name: String, category: String = "ui"):
	var path_dict
	match category:
		"ui": path_dict = sfx_ui_paths
		"instances": path_dict = sfx_instances_paths
		"player": path_dict = sfx_player_paths
		"environment": path_dict = sfx_environment_paths
		_: 
			print("AudioManager: 错误 - 未知音效类别: ", category)
			return
	
	if path_dict.has(sfx_name):
		# 检查文件是否存在
		if not ResourceLoader.exists(path_dict[sfx_name]):
			print("AudioManager: 错误 - 音效文件不存在: ", path_dict[sfx_name])
			return
			
		var stream = load(path_dict[sfx_name])
		if stream:
			var sfx_player = AudioStreamPlayer.new()
			sfx_player.process_mode = Node.PROCESS_MODE_ALWAYS
			add_child(sfx_player)
			sfx_player.stream = stream
			sfx_player.bus = SFX_BUS
			sfx_player.play()
			sfx_player.finished.connect(sfx_player.queue_free)
			
			# 可选：为重要音效启用音频闪避
			if category == "instances":
				duck_bgm_for_sfx(1.5, 0.7)
	else:
		print("AudioManager: 错误 - 未找到音效: ", sfx_name, " 在类别: ", category)

## 注册房间BGM
func register_room_bgm(room_id: String, bgm_name: String):
	room_bgm_map[room_id] = bgm_name

## 播放房间BGM
func play_room_bgm(room_id: String):
	if not room_bgm_map.has(room_id):
		print("AudioManager: 错误 - 房间未注册BGM:", room_id)
		return
	
	var bgm_name = room_bgm_map[room_id]
	if bgm_name == "":
		print("AudioManager: 房间", room_id, "没有设置BGM")
		return
	
	# 如果正在播放事件BGM，不切换
	if is_event_bgm_playing:
		print("AudioManager: 事件BGM播放中，不切换房间BGM")
		return
	
	# 检查优先级
	var priority = bgm_priorities.get(bgm_name, 0)
	if priority < current_bgm_priority and current_bgm != "":
		return
	
	# 播放BGM
	await play_bgm(bgm_name)
	current_room_bgm = bgm_name

## 播放事件BGM（Boss战等，高优先级）
func play_event_bgm(bgm_name: String):
	is_event_bgm_playing = true
	await force_play_bgm(bgm_name)
	print("AudioManager: 播放事件BGM -", bgm_name)

## 停止事件BGM，恢复房间BGM
func stop_event_bgm():
	is_event_bgm_playing = false
	if RoomManager.current_room != "":
		await play_room_bgm(RoomManager.current_room)
	print("AudioManager: 停止事件BGM，恢复房间BGM")

## 检查是否正在播放事件BGM
func is_playing_event_bgm() -> bool:
	return is_event_bgm_playing

## 强制播放BGM（无视优先级，用于事件BGM）
func force_play_bgm(bgm_name: String, fade_duration: float = BGM_FADE_IN_DURATION):
	if not bgm_paths.has(bgm_name) or not bgm_paths[bgm_name]:
		print("AudioManager: 错误 - 未找到BGM:", bgm_name)
		return
	
	# 检查文件是否存在
	if not ResourceLoader.exists(bgm_paths[bgm_name]):
		print("AudioManager: 错误 - BGM文件不存在:", bgm_paths[bgm_name])
		return
	
	if current_bgm == bgm_name:
		return
	
	# 淡出当前BGM
	if current_bgm != "":
		await fade_out_bgm(current_bgm, fade_duration)
	
	var player = bgm_players[bgm_name]
	if player.stream == null:
		var stream = load(bgm_paths[bgm_name])
		if stream:
			player.stream = stream
			player.finished.connect(_on_bgm_finished.bind(bgm_name))
	
	# 淡入新BGM
	await fade_in_bgm(bgm_name, fade_duration)
	current_bgm = bgm_name
	current_bgm_priority = bgm_priorities.get(bgm_name, 0)

# 淡入BGM
func fade_in_bgm(bgm_name: String, duration: float = BGM_FADE_IN_DURATION):
	var player = bgm_players[bgm_name]
	player.volume_db = -80.0
	player.play()
	
	if bgm_tweens.has(bgm_name):
		bgm_tweens[bgm_name].kill()
	
	var tween = create_tween()
	tween.tween_property(player, "volume_db", 0.0, duration)
	bgm_tweens[bgm_name] = tween
	await tween.finished

# 淡出BGM
func fade_out_bgm(bgm_name: String, duration: float = BGM_FADE_OUT_DURATION):
	if bgm_players.has(bgm_name):
		var player = bgm_players[bgm_name]
		
		if bgm_tweens.has(bgm_name):
			bgm_tweens[bgm_name].kill()
		
		var tween = create_tween()
		tween.tween_property(player, "volume_db", -80.0, duration)
		tween.tween_callback(player.stop)
		bgm_tweens[bgm_name] = tween
		await tween.finished

## 交叉淡入淡出切换BGM（使用现有的淡入淡出函数）
func crossfade_bgm(new_bgm_name: String, fade_duration: float = BGM_CROSSFADE_DURATION):
	if not bgm_paths.has(new_bgm_name) or not bgm_paths[new_bgm_name]:
		print("AudioManager: 错误 - 未找到BGM: ", new_bgm_name)
		return
	
	# 检查文件是否存在
	if not ResourceLoader.exists(bgm_paths[new_bgm_name]):
		print("AudioManager: 错误 - BGM文件不存在: ", bgm_paths[new_bgm_name])
		return
	
	var priority = bgm_priorities.get(new_bgm_name, 0)
	
	# 检查优先级
	if priority < current_bgm_priority and current_bgm != "":
		return
	
	# 如果已经在播放相同的BGM，不做任何事
	if current_bgm == new_bgm_name:
		return
	
	# 使用现有的fade_out_bgm函数淡出当前BGM
	if current_bgm != "":
		await fade_out_bgm(current_bgm, fade_duration)
	
	var player = bgm_players[new_bgm_name]
	if player.stream == null:
		var stream = load(bgm_paths[new_bgm_name])
		if stream:
			player.stream = stream
			player.finished.connect(_on_bgm_finished.bind(new_bgm_name))
	
	# 使用现有的fade_in_bgm函数淡入新BGM
	await fade_in_bgm(new_bgm_name, fade_duration)
	current_bgm = new_bgm_name
	current_bgm_priority = priority

func _on_bgm_finished(bgm_name: String):
	# 循环播放
	if current_bgm == bgm_name:
		bgm_players[bgm_name].play()

# 停止BGM
func stop_bgm(fade_duration: float = BGM_FADE_OUT_DURATION):
	if current_bgm != "":
		await fade_out_bgm(current_bgm, fade_duration)
		current_bgm = ""
		current_bgm_priority = 0

# 音频闪避 - 播放重要音效时临时降低BGM音量
func duck_bgm_for_sfx(duck_duration: float = BGM_DUCK_DURATION, duck_volume: float = BGM_DUCK_VOLUME):
	if current_bgm != "":
		var player = bgm_players[current_bgm]
		var original_volume = player.volume_db
		
		# 停止之前的闪避tween
		if audio_duck_tween and audio_duck_tween.is_valid():
			audio_duck_tween.kill()
		
		# 临时降低BGM音量
		audio_duck_tween = create_tween()
		audio_duck_tween.tween_property(player, "volume_db", linear_to_db(duck_volume), 0.2)
		audio_duck_tween.tween_interval(duck_duration)
		audio_duck_tween.tween_property(player, "volume_db", original_volume, 0.5)

# 播放UI音效
func play_ui_sfx(sfx_name: String):
	play_sfx(sfx_name, "ui")

# 播放实例音效
func play_instance_sfx(sfx_name: String):
	play_sfx(sfx_name, "instances")

# 播放空间音效（使用AudioStreamPlayer2D）
func play_spatial_sfx(sfx_name: String, position: Vector2, category: String = "player"):
	var path_dict
	match category:
		"player": path_dict = sfx_player_paths
		"environment": path_dict = sfx_environment_paths
		"instances": path_dict = sfx_instances_paths
		_: 
			print("AudioManager: 错误 - 未知音效类别: ", category)
			return
	
	if path_dict.has(sfx_name):
		# 检查文件是否存在
		if not ResourceLoader.exists(path_dict[sfx_name]):
			print("AudioManager: 错误 - 音效文件不存在: ", path_dict[sfx_name])
			return
			
		var stream = load(path_dict[sfx_name])
		if stream:
			var sfx_player = AudioStreamPlayer2D.new()
			sfx_player.process_mode = Node.PROCESS_MODE_ALWAYS
			sfx_player.stream = stream
			sfx_player.bus = SFX_BUS
			sfx_player.global_position = position
			
			# 添加到当前场景
			var current_scene = get_tree().current_scene
			if current_scene:
				current_scene.add_child(sfx_player)
				sfx_player.play()
				sfx_player.finished.connect(sfx_player.queue_free)
				print("AudioManager: 播放空间音效 - ", sfx_name, " 位置: ", position)
	else:
		print("AudioManager: 错误 - 未找到音效: ", sfx_name, " 在类别: ", category)

# 音量控制方法（0-100范围）
func get_bus_volume_percent(bus_name: String) -> float:
	var bus_index = AudioServer.get_bus_index(bus_name)
	if bus_index != -1:
		return db_to_linear(AudioServer.get_bus_volume_db(bus_index)) * 100.0
	return 70.0

func set_bus_volume_percent(bus_name: String, value: float):
	var bus_index = AudioServer.get_bus_index(bus_name)
	if bus_index != -1:
		var linear_value = value / 100.0
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(linear_value))

func set_master_volume(value: float):
	set_bus_volume_percent("Master", value * 100.0)

func set_bgm_volume(value: float):
	set_bus_volume_percent("BGM", value * 100.0)

func set_sfx_volume(value: float):
	set_bus_volume_percent("SFX", value * 100.0)

func set_voice_volume(value: float):
	set_bus_volume_percent("Voice", value * 100.0)
