extends Area2D
class_name CameraFocusBeacon

@export_category("Focus Capture")
## 焦点目标节点路径；留空时默认使用自身位置。
@export var focus_target_path: NodePath = NodePath("FocusTarget")
## 抢夺区的回退范围；当碰撞形状无法解析时使用。
@export var capture_radius: float = 240.0
## 抢夺强度，越大越容易压过普通跟随。
@export var steal_strength: float = 0.65
## 距离衰减曲线指数，越高越偏向靠近目标点时才产生明显抢夺。
@export var falloff_power: float = 1.5
## 单个抢夺区允许影响相机的最大偏移量。
@export var max_focus_offset: float = 220.0

# 碰撞形状节点，用于可视化调整抢夺区范围。
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_sync_capture_shape()

func _sync_capture_shape() -> void:
	if collision_shape == null:
		return
	if collision_shape.shape is CircleShape2D:
		(collision_shape.shape as CircleShape2D).radius = maxf(capture_radius, 1.0)

func _resolve_focus_target() -> Node2D:
	if focus_target_path != NodePath(""):
		var target = get_node_or_null(focus_target_path)
		if target is Node2D:
			return target
	return self

func _get_capture_range() -> float:
	if collision_shape == null or collision_shape.shape == null:
		return maxf(capture_radius, 1.0)
	if collision_shape.shape is CircleShape2D:
		return maxf((collision_shape.shape as CircleShape2D).radius, 1.0)
	if collision_shape.shape is RectangleShape2D:
		var rect_shape := collision_shape.shape as RectangleShape2D
		return maxf(rect_shape.size.length() * 0.5, 1.0)
	if collision_shape.shape is CapsuleShape2D:
		var capsule_shape := collision_shape.shape as CapsuleShape2D
		return maxf(capsule_shape.radius + capsule_shape.height * 0.5, 1.0)
	return maxf(capture_radius, 1.0)

func get_focus_capture_sample_for_player(player: Node2D) -> Dictionary:
	var target := _resolve_focus_target()
	if target == null:
		return {"valid": false}
	if player == null:
		return {"valid": false}
	var capture_range := _get_capture_range()
	var to_target: Vector2 = target.global_position - player.global_position
	var distance := to_target.length()
	if distance > capture_range:
		return {"valid": false}
	var normalized := clampf(distance / capture_range, 0.0, 1.0)
	var weight := maxf(steal_strength, 0.0) * pow(1.0 - normalized, maxf(falloff_power, 0.01))
	if weight <= 0.001:
		return {"valid": false}
	var offset := to_target * weight
	if max_focus_offset > 0.0 and offset.length() > max_focus_offset:
		offset = offset.normalized() * max_focus_offset
	return {
		"valid": true,
		"weight": weight,
		"offset": offset,
		"target": target.global_position
	}

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	if body.has_method("register_camera_focus_zone"):
		body.register_camera_focus_zone(self)

func _on_body_exited(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	if body.has_method("unregister_camera_focus_zone"):
		body.unregister_camera_focus_zone(self)
