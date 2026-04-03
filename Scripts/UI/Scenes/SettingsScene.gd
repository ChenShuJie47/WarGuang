# SettingsScene.gd
extends CanvasLayer

## 设置场景主脚本

## 节点引用
@onready var audio_button = $SettingsRoot/AudioButton          # 音量按钮
@onready var controls_button = $SettingsRoot/ControlsButton    # 按键映射按钮
@onready var audio_page = $SettingsRoot/AudioPage              # 音频页面
@onready var controls_page = $SettingsRoot/ControlsPage        # 控制页面
@onready var close_button = $BackButton                        # 关闭按钮

## 音量滑块引用（根据你的实际节点路径调整）
@onready var master_volume_slider = $SettingsRoot/AudioPage/VolumeContainer/MasterVolumeLabel/MasterVolumeSlider
@onready var bgm_volume_slider = $SettingsRoot/AudioPage/VolumeContainer/BGMVolumeLabel/BGMVolumeSlider
@onready var sfx_volume_slider = $SettingsRoot/AudioPage/VolumeContainer/SFXVolumeLabel/SFXVolumeSlider
@onready var voice_volume_slider = $SettingsRoot/AudioPage/VolumeContainer/VoiceVolumeLabel/VoiceVolumeSlider

## 场景来源信息
var opened_from: String = ""
var parent_scene: Node = null
## ESC键启用状态
var esc_enabled: bool = false

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	
	# 连接按钮信号
	audio_button.pressed.connect(_on_audio_button_pressed)
	controls_button.pressed.connect(_on_controls_button_pressed)
	close_button.pressed.connect(_on_close_button_pressed)
	
	# 连接音量滑块信号
	if master_volume_slider:
		master_volume_slider.value_changed.connect(_on_master_volume_changed)
	if bgm_volume_slider:
		bgm_volume_slider.value_changed.connect(_on_bgm_volume_changed)
	if sfx_volume_slider:
		sfx_volume_slider.value_changed.connect(_on_sfx_volume_changed)
	if voice_volume_slider:
		voice_volume_slider.value_changed.connect(_on_voice_volume_changed)
	
	# 初始显示音频页面
	_switch_to_page("controls")
	
	# 设置焦点
	if audio_button is Control:
		audio_button.grab_focus()
	
	# 淡入效果
	FadeManager.fade_in(0.15)
	
	# ESC冷却
	var esc_timer = Timer.new()
	esc_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	esc_timer.wait_time = 0.1
	esc_timer.one_shot = true
	esc_timer.autostart = true
	esc_timer.timeout.connect(func():
		esc_enabled = true
		if esc_timer.is_inside_tree():
			remove_child(esc_timer)
			esc_timer.queue_free()
	)
	add_child(esc_timer)

## 设置场景来源
func setup(from_scene: String, parent: Node = null):
	opened_from = from_scene
	parent_scene = parent

## 切换页面
func _switch_to_page(page_name: String):
	match page_name:
		"audio":
			audio_page.visible = true
			controls_page.visible = false
			audio_button.disabled = true
			controls_button.disabled = false
		"controls":
			audio_page.visible = false
			controls_page.visible = true
			audio_button.disabled = false
			controls_button.disabled = true

## 音频按钮按下
func _on_audio_button_pressed():
	AudioManager.play_sfx("button_click")
	
	# 静默取消控制页面中的映射
	if controls_page and controls_page.has_method("cancel_current_mapping"):
		controls_page.cancel_current_mapping()
	
	_switch_to_page("audio")

## 控制按钮按下
func _on_controls_button_pressed():
	AudioManager.play_sfx("button_click")
	
	# 静默取消任何映射
	if controls_page and controls_page.has_method("cancel_current_mapping"):
		controls_page.cancel_current_mapping()
	
	_switch_to_page("controls")

## 关闭按钮按下
func _on_close_button_pressed():
	AudioManager.play_sfx("button_click")
	_close_settings()

## 处理输入
func _input(event):
	if event.is_action_pressed("ui_cancel") and esc_enabled:
		# 检查是否正在重新映射
		if InputMapManager.is_remapping():
			# 正在重新映射，不关闭设置
			return
		
		get_viewport().set_input_as_handled()
		_close_settings()

## 关闭设置场景
func _close_settings():
	set_process_input(false)
	set_process_unhandled_input(false)
	
	if close_button:
		close_button.disabled = true
	
	# 取消任何正在进行的重新映射
	if InputMapManager:
		InputMapManager.cancel_remap()
	
	await FadeManager.fade_out(0.15)
	
	# 根据来源通知父场景
	if opened_from == "GameSettingScene" and parent_scene and is_instance_valid(parent_scene):
		await get_tree().process_frame
		if parent_scene.has_method("_on_settings_closed"):
			parent_scene._on_settings_closed()
	elif opened_from == "TitleScene" and parent_scene and is_instance_valid(parent_scene):
		await get_tree().process_frame
		if parent_scene.has_method("_on_settings_closed"):
			parent_scene._on_settings_closed()
	
	queue_free()

## 音量控制函数
func _on_master_volume_changed(value: float):
	AudioManager.set_bus_volume_percent("Master", value)

func _on_bgm_volume_changed(value: float):
	AudioManager.set_bus_volume_percent("BGM", value)

func _on_sfx_volume_changed(value: float):
	AudioManager.set_bus_volume_percent("SFX", value)

func _on_voice_volume_changed(value: float):
	AudioManager.set_bus_volume_percent("Voice", value)

func _exit_tree():
	LightingManager.stop_all_light_effects()
