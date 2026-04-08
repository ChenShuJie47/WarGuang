extends CanvasLayer

@onready var message_label = $Background/Message
@onready var confirm_button = $Background/ButtonContainer/ConfirmButton
@onready var cancel_button = $Background/ButtonContainer/CancelButton

var confirm_callback: Callable

func _ready():
	confirm_button.pressed.connect(_on_confirm_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	
	# 设置默认消息
	if message_label:
		message_label.text = "是否删除存档？"

func _on_confirm_pressed():
	AudioManager.play_sfx("button_click")
	
	if confirm_callback:
		confirm_callback.call()
	queue_free()

func _on_cancel_pressed():
	AudioManager.play_sfx("button_click")
	queue_free()

# 添加ESC键处理函数
func setup_esc_close():
	set_process_input(true)

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		_on_cancel_pressed()
		get_viewport().set_input_as_handled()  # 阻止事件传播
