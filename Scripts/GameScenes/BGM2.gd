extends Area2D

@export var bgm_name: String = "BGM3"
@export var fade_duration: float = 1.0

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	if body.is_in_group("player"):
		print("进入BGM区域: ", bgm_name)
		AudioManager.play_bgm(bgm_name, fade_duration)

func _on_body_exited(body):
	if body.is_in_group("player"):
		print("离开BGM区域: ", bgm_name)
		# 直接停止BGM，不恢复之前的
		if AudioManager.current_bgm == bgm_name:
			AudioManager.stop_bgm(fade_duration)
