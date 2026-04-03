@tool
extends Node2D
class_name TextArea

## 区域基础大小（可在编辑器直接拖动调整）
## 注意：最终大小 = size * scale
@export var size: Vector2 = Vector2(200, 150) : set = set_size

## 参考颜色（仅编辑器可见）
@export var debug_color: Color = Color(0.0, 0.784, 0.196, 0.137)

## 运行时是否可见（默认 false，只在编辑器显示）
@export var show_in_game: bool = false

# 节点引用
var collision_shape: CollisionShape2D
var polygon: Polygon2D

func _ready():
	_create_visualization()
	
	# 运行时隐藏可视化（除非明确启用）
	if not Engine.is_editor_hint() and not show_in_game:
		set_visible(false)

func _create_visualization():
	# 清理旧节点
	if is_instance_valid(collision_shape):
		collision_shape.queue_free()
	if is_instance_valid(polygon):
		polygon.queue_free()
	
	# 创建 CollisionShape2D（编辑器中可见的矩形框）
	collision_shape = CollisionShape2D.new()
	collision_shape.name = "DebugCollisionShape"
	
	var rect_shape = RectangleShape2D.new()
	rect_shape.size = size
	collision_shape.shape = rect_shape
	
	add_child(collision_shape)
	
	# 创建 Polygon2D（半透明填充效果）
	polygon = Polygon2D.new()
	polygon.name = "DebugPolygon"
	polygon.color = debug_color
	
	_update_polygon()
	
	add_child(polygon)

func _update_polygon():
	if is_instance_valid(polygon) and size:
		var points = PackedVector2Array([
			Vector2(-size.x / 2, -size.y / 2),
			Vector2(size.x / 2, -size.y / 2),
			Vector2(size.x / 2, size.y / 2),
			Vector2(-size.x / 2, size.y / 2)
		])
		polygon.polygon = points

func set_size(new_size: Vector2):
	size = new_size
	if Engine.is_editor_hint():
		_create_visualization()
	else:
		_update_polygon()
		if is_instance_valid(collision_shape) and collision_shape.shape:
			collision_shape.shape.size = new_size

## 获取实际大小（考虑 scale）
func get_actual_size() -> Vector2:
	return size * scale

## 获取实际区域（全局坐标）
func get_global_rect() -> Rect2:
	var actual_size = get_actual_size()
	var center = global_position
	
	# 关键修复：使用正确的矩形计算方法
	# Rect2 的参数是 (左上角位置，大小)
	var top_left = center - actual_size / 2
	
	return Rect2(top_left, actual_size)
