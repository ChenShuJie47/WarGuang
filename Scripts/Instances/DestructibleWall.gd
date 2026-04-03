extends Node2D
class_name DestructibleWall

## ============================================
## DestructibleWall - 可破坏石墙（方案 B）
## ============================================
## 功能:
## - StaticBody2D 负责物理阻挡
## - Area2D 负责检测玩家撞击
## - 单面可撞击（通过 facing_direction 控制）
## - 摧毁后永久消失（存档持久化）
## ============================================

## 石墙设置
@export_category("石墙设置")
## 需要撞击的次数才能摧毁石墙
@export var hit_count_required: int = 3
## 可撞击方向（1 = 右侧可撞击，-1 = 左侧可撞击）
@export var facing_direction: int = 1
## 速度阈值范围（只有玩家水平速度绝对值在此范围内才算撞击）
## - 默认范围：180 ~ 350
## - 玩家走路速度 110（不会触发）✅
## - 玩家奔跑速度 220（会触发）✅
## - 玩家冲刺速度 400（不会触发）✅
@export var velocity_threshold_min: float = 180.0
@export var velocity_threshold_max: float = 350.0

## 高级设置
@export_category("高级设置")
## 唯一 ID（用于存档持久化，不填则自动生成）
@export var wall_id: String = ""

# 子节点引用
@onready var wall_body: StaticBody2D = $WallBody
@onready var wall_detector: Area2D = $WallDetector
@onready var animated_sprite: AnimatedSprite2D = $WallBody/AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $WallBody/CollisionShape2D

# 内部变量
var current_hit_count: int = 0
var is_destroyed: bool = false

func _ready():
	# 使用外部 ID 或自动生成
	if wall_id.is_empty():
		wall_id = generate_unique_id()
	
	# 根据 facing_direction 翻转 Sprite
	animated_sprite.flip_h = (facing_direction == -1)
	
	# 添加到 destructible_wall 组（用于房间切换时清理）
	add_to_group("destructible_wall")
	
	# 关键修复：检查当前存档中是否已有摧毁记录
	# 读档时需要根据这个状态决定是否禁用碰撞体
	if is_instance_valid(Global):
		if Global.destructible_walls_destroyed.has(wall_id):
			# 已被摧毁，禁用碰撞体并显示 DESTROYED 动画最后一帧
			is_destroyed = true
			call_deferred("_disable_collision_shape")
			# 设置到 DESTROYED 动画的最后一帧并停止
			if animated_sprite and animated_sprite.sprite_frames:
				if animated_sprite.sprite_frames.has_animation("DESTROYED"):
					var last_frame = animated_sprite.sprite_frames.get_frame_count("DESTROYED") - 1
					animated_sprite.set_frame(last_frame)
					animated_sprite.play("DESTROYED")
					animated_sprite.stop()  # 停在最后一帧
			return  # 已被摧毁，直接返回，不连接信号
	
	# 未被摧毁，连接 WallDetector 的信号并开始检测
	wall_detector.body_entered.connect(_on_detector_body_entered)
	
	# 关键：确保未被摧毁时播放 IDLE 动画
	if animated_sprite and animated_sprite.sprite_frames:
		if animated_sprite.sprite_frames.has_animation("IDLE"):
			animated_sprite.play("IDLE")

## 检测器检测到玩家进入
func _on_detector_body_entered(body):
	# 只处理玩家
	if not body.is_in_group("player"):
		return
	
	# 已被摧毁，忽略
	if is_destroyed:
		return
	
	# 1. 检查玩家是否在正确的方向
	if not is_player_on_correct_side(body):
		return
	
	# 2. 检查玩家速度
	var player_velocity = Vector2.ZERO
	if body.has_method("get_velocity"):
		player_velocity = body.get_velocity()
	
	var speed = abs(player_velocity.x)
	if speed < velocity_threshold_min or speed > velocity_threshold_max:
		return  # 速度不符合
	
	# 3. 检查玩家是否真的撞到墙（距离检测）
	if not is_player_touching_wall(body):
		return  # 只是经过检测器，没有真正撞墙
	
	# 所有条件满足，触发撞击
	print("DEBUG DestructibleWall: 检测到撞击，玩家速度=", player_velocity.x)
	_handle_impact()

## 检查玩家是否在正确的一侧
func is_player_on_correct_side(body) -> bool:
	var direction_to_player = (body.global_position - global_position).normalized()
	# facing_direction=1 时，玩家在右侧 (direction.x > 0) 有效
	# facing_direction=-1 时，玩家在左侧 (direction.x < 0) 有效
	return direction_to_player.x * facing_direction > 0

## 检查玩家是否真的接触墙壁
func is_player_touching_wall(body) -> bool:
	# 简单方法：检测玩家与墙的距离
	var distance = body.global_position.distance_to(wall_body.global_position)
	return distance < 50  # 距离小于 50 像素算撞墙

## 处理撞击
func _handle_impact():
	current_hit_count += 1
	
	if current_hit_count >= hit_count_required:
		# 最后一次撞击，摧毁石墙
		_destroy_wall()
	else:
		# 播放受击动画
		_play_hit_animation()

## 播放受击动画
func _play_hit_animation():
	if animated_sprite and animated_sprite.sprite_frames:
		if animated_sprite.sprite_frames.has_animation("HIT"):
			animated_sprite.play("HIT")
			# 等待动画播放完成
			await animated_sprite.animation_finished
			# 恢复静止动画
			if animated_sprite.sprite_frames.has_animation("IDLE"):
				animated_sprite.play("IDLE")

## 摧毁石墙
func _destroy_wall():
	is_destroyed = true
	
	# 禁用碰撞体（使用 call_deferred 避免物理查询冲突）
	call_deferred("_disable_collision_shape")
	
	# 播放摧毁动画（动画设置为不循环，会自动停在最后一帧）
	if animated_sprite and animated_sprite.sprite_frames:
		if animated_sprite.sprite_frames.has_animation("DESTROYED"):
			animated_sprite.play("DESTROYED")
	# 保存到 Global（持久化）- 只在未记录过时保存
	if is_instance_valid(Global):
		if not Global.destructible_walls_destroyed.has(wall_id):
			Global.destructible_walls_destroyed.append(wall_id)
	# 关键修改：不立即删除，等待房间切换时再删除
	# 这样玩家可以看到摧毁后的废墟状态

## 延迟禁用碰撞体（避免物理查询冲突）
func _disable_collision_shape():
	if collision_shape:
		collision_shape.disabled = true

## 生成唯一 ID（回退方案）
func generate_unique_id() -> String:
	# 使用场景路径 + 节点位置生成唯一 ID
	var scene_path = get_tree().current_scene.scene_file_path if get_tree().current_scene else "unknown"
	var position_str = str(global_position.x) + "_" + str(global_position.y)
	return scene_path.md5_text() + "_" + position_str.md5_text()

## 房间切换时调用（由 MainGameScene 或 SaveManager 调用）
func cleanup_destroyed_walls():
	# 检查是否已被摧毁
	if is_destroyed:
		queue_free()
