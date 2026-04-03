extends CanvasLayer

@onready var color_rect: ColorRect = $ColorRect

## 遮罩的透明度（0-1）
@export var overlay_alpha: float = 0.7

func _ready():
	# 设置层级在对话框之上，设置界面之下
	layer = 95
	
	# 初始隐藏
	visible = false
	
	# 设置 ColorRect 全屏
	if color_rect:
		color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		color_rect.color = Color(0, 0, 0, overlay_alpha)

## 显示遮罩
func show_overlay():
	visible = true

## 隐藏遮罩
func hide_overlay():
	visible = false
