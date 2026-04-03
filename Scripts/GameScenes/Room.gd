extends Node2D

## 房间设置
@export_category("房间设置")
@export var room_id: String = "Room1"

## 房间 BGM
@export var room_bgm: String = ""

## 相邻房间 ID 列表
@export var adjacent_rooms: Array[String] = []

## 房间颜色（用于全局 CanvasModulate）
@export var room_color: Color = Color.WHITE

## 相机设置
@export_category("相机设置")
@export var limit_camera_in_room: bool = true
@export var camera_margin: Vector2 = Vector2(20, 20)

## 房间边界引用（在场景中手动指定）
@export var room_bounds: TextArea

# 节点引用
@onready var room_trigger = $RoomTrigger

func _ready():
	setup_room_trigger()
	set_room_active(false)
	
	call_deferred("_correct_container_children_world_positions")

func _correct_container_children_world_positions():
	var container_names = ["NPCs", "Doors", "Instances", "HurtBoxs", "Props", "DynamicCheckpoints", "ChairSavePoints"]
	
	for container_name in container_names:
		var container = get_node_or_null(container_name)
		if container and container.position != Vector2.ZERO:
			for child in container.get_children():
				if child is Node2D:
					var world_pos = child.global_position
					container.position = Vector2.ZERO
					child.global_position = world_pos

func setup_room_trigger():
	if room_trigger and room_trigger is Area2D and room_bounds:
		var collision_shape = room_trigger.get_node("CollisionShape2D")
		if collision_shape and collision_shape.shape is RectangleShape2D:
			collision_shape.shape.size = room_bounds.get_actual_size()
			
			# 使用 global_position 确保坐标系统一
			# 无论 RoomTrigger 和 RoomBounds 在哪个层级，都能正确对齐
			room_trigger.global_position = room_bounds.global_position
	if room_trigger and not room_trigger.body_entered.is_connected(_on_player_entered):
		room_trigger.body_entered.connect(_on_player_entered)

func set_room_active(active: bool):
	set_process(active)
	set_physics_process(active)
	
	for child in get_children():
		if child != room_trigger:
			child.set_process(active)
			child.set_physics_process(active)
			if child.has_method("set_active"):
				child.set_active(active)
	
	visible = active

func _on_player_entered(body):
	if body.is_in_group("player"):
		RoomManager.player_entered_room(room_id)

func get_camera_limits() -> Rect2:
	if limit_camera_in_room and room_bounds:
		var bounds = room_bounds.get_global_rect()
		
		var limits = Rect2(
			bounds.position + camera_margin,
			bounds.size - camera_margin * 2
		)
		
		return limits
	else:
		return Rect2()

func get_room_data() -> Dictionary:
	return {
		"id": room_id,
		"bounds_size": room_bounds.get_actual_size() if room_bounds else Vector2.ZERO,
		"bounds_position": room_bounds.global_position if room_bounds else Vector2.ZERO,
		"bgm": room_bgm,
		"adjacent": adjacent_rooms,
		"color": room_color
	}

func get_room_color() -> Color:
	return room_color
