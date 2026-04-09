@tool  # 必须在编辑器显示
extends Node2D
class_name ChallengeMovePath

## 编辑器专用可视化路径点
## 运行时自动删除，不消耗性能

## 目标点 1 偏移
@export var target_point_1_offset: Vector2 = Vector2(-50, 0)
## 目标点 2 偏移
@export var target_point_2_offset: Vector2 = Vector2(50, 0)
## 路径颜色
@export var path_color: Color = Color(0.196, 0.784, 0.353, 0.255)

func _ready():
	# 运行时自动删除
	if not Engine.is_editor_hint():
		queue_free()

func _draw():
	# 绘制路径线
	draw_line(target_point_1_offset, target_point_2_offset, path_color, 2.0)
	
	# 绘制目标点
	draw_circle(target_point_1_offset, 5.0, path_color)
	draw_circle(target_point_2_offset, 5.0, path_color)
