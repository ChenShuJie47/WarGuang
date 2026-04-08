extends Area2D
class_name JumpBox

## 弹跳设置
@export_category("弹跳设置")
## 垂直向上的力大小
@export var vertical_force: float = 900.0

## 重生设置
@export_category("重生设置")
## 从禁用到重新启用的时间（秒）
@export var respawn_time: float = 2.0

# 节点引用
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

# 状态变量
var is_active: bool = true
var original_position: Vector2
var animation_finished_emitted: bool = false
var is_transitioning: bool = false
var is_destroying: bool = false

enum AnimState {
	START,
	YES,
	YN_TRANSITION,
	NO,
	NY_TRANSITION,
	END,
	NONE
}
var current_anim_state: AnimState = AnimState.NONE

func _ready():
	original_position = global_position
	if body_entered.is_connected(_on_body_entered) == false:
		body_entered.connect(_on_body_entered)
	_setup_instance()
	call_deferred("play_start_animation")

func _process(delta):
	_update_custom(delta)

## 子类重写：做实例初始化（例如移动路径）
func _setup_instance() -> void:
	pass

## 子类重写：每帧更新（例如移动）
func _update_custom(_delta: float) -> void:
	pass

func play_start_animation():
	if is_destroying:
		return

	is_transitioning = true
	set_inactive()
	if animated_sprite:
		animated_sprite.visible = true
	current_anim_state = AnimState.START

	if not animated_sprite or not animated_sprite.sprite_frames:
		is_transitioning = false
		return

	if animated_sprite.sprite_frames.has_animation("START"):
		animated_sprite.play("START")
		await animated_sprite.animation_finished

	_play_loop_if_exists("YES")
	current_anim_state = AnimState.YES
	set_active()
	is_transitioning = false

## 播放 END 动画（供外部调用）
func play_end_animation():
	if not animated_sprite or not animated_sprite.sprite_frames:
		return
	current_anim_state = AnimState.END
	if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("END"):
		animated_sprite.play("END")
		await animated_sprite.animation_finished
		animation_finished_emitted = true

func destroy_with_end_animation():
	if is_destroying:
		return

	is_destroying = true
	is_transitioning = false
	set_inactive()
	await play_end_animation()
	queue_free()

func reactivate():
	if is_destroying:
		return

	is_transitioning = false
	set_active()
	if animated_sprite:
		animated_sprite.visible = true
	_play_loop_if_exists("YES")
	current_anim_state = AnimState.YES

func _on_body_entered(body):
	if _can_trigger_for_player(body):
		trigger_bounce(body)

func _can_trigger_for_player(body) -> bool:
	if not is_active or not body:
		return false
	if is_transitioning or is_destroying:
		return false
	if current_anim_state != AnimState.YES:
		return false
	if not animated_sprite or animated_sprite.animation != "YES":
		return false
	if not body.is_in_group("player"):
		return false
	if body.current_state == body.PlayerState.DASH:
		return false
	if body.current_animation != "JUMP2":
		return false
	if not body.has_double_jumped:
		return false
	if body.has_method("can_accept_jumpbox_bounce") and not body.can_accept_jumpbox_bounce():
		return false
	return true

func _apply_player_bounce(player) -> void:
	if player.has_method("start_jumpbox_bounce"):
		player.start_jumpbox_bounce(vertical_force)
	if player.has_method("start_jumpbox_hit_stop"):
		player.start_jumpbox_hit_stop()
	get_tree().create_timer(0.06).timeout.connect(func():
		CameraShakeManager.shake("y_weak", player.phantom_camera)
	)

func set_inactive() -> void:
	is_active = false
	if collision_shape:
		collision_shape.set_deferred("disabled", true)

func set_active() -> void:
	is_active = true
	if collision_shape:
		collision_shape.set_deferred("disabled", false)

func trigger_bounce(player):
	if not is_active or not player or is_transitioning or is_destroying:
		return

	_apply_player_bounce(player)
	is_transitioning = true
	set_inactive()

	# YES -> YN_TRANSITION
	if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("YN_TRANSITION"):
		current_anim_state = AnimState.YN_TRANSITION
		animated_sprite.play("YN_TRANSITION")
		await animated_sprite.animation_finished

	# NO（禁用循环）
	_play_loop_if_exists("NO")
	current_anim_state = AnimState.NO

	if respawn_time > 0.0:
		await get_tree().create_timer(respawn_time).timeout

	if is_destroying:
		return

	# NO -> NY_TRANSITION
	if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("NY_TRANSITION"):
		current_anim_state = AnimState.NY_TRANSITION
		animated_sprite.play("NY_TRANSITION")
		await animated_sprite.animation_finished

	set_active()
	_play_loop_if_exists("YES")
	current_anim_state = AnimState.YES
	is_transitioning = false

func _play_loop_if_exists(anim_name: String) -> void:
	if not animated_sprite or not animated_sprite.sprite_frames:
		return
	if animated_sprite.sprite_frames.has_animation(anim_name):
		animated_sprite.play(anim_name)
		animated_sprite.sprite_frames.set_animation_loop(anim_name, true)
