extends CanvasLayer
class_name ChallengeCounterUI

## 挑战计数器 UI
## 显示当前挑战进度 (例如：1/12)

@onready var label: Label = $MarginContainer/HBoxContainer/TextureRect/Label

## 更新计数器显示
func update_counter(current: int, target: int):
	if label:
		label.text = str(current) + "/" + str(target)
		print("DEBUG ChallengeCounterUI: 更新计数为 ", current, "/", target)
	else:
		push_error("ChallengeCounterUI: Label 节点未找到！")
