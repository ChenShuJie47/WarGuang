extends BaseJumpBox
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
	_base_setup_trigger_detection()
	_setup_instance()
	call_deferred("play_start_animation")

func _process(delta):
	_update_custom(delta)
	_base_process_trigger_detection()

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
	_mark_perfect_candidates_on_yes_activation()
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
	_mark_perfect_candidates_on_yes_activation()

func _get_trigger_sprite() -> CanvasItem:
	return animated_sprite

func _is_trigger_active() -> bool:
	if not is_active:
		return false
	if is_transitioning or is_destroying:
		return false
	return current_anim_state == AnimState.YES

func _is_visual_yes_state() -> bool:
	return animated_sprite != null and animated_sprite.animation == "YES"

func _apply_trigger_effect(player, trigger_grade: String) -> void:
	var applied_force = vertical_force * 2.0 if trigger_grade == "perfect" else vertical_force
	if player.has_method("start_jumpbox_bounce"):
		player.start_jumpbox_bounce(applied_force, trigger_grade, {})
	if player.has_method("start_jumpbox_hit_stop"):
		player.start_jumpbox_hit_stop(trigger_grade)
	get_tree().create_timer(0.06).timeout.connect(func():
		CameraShakeManager.shake("y_weak", player.phantom_camera)
	)

func _consume_after_trigger(_player, _trigger_grade: String) -> void:
	is_transitioning = true
	set_inactive()

	if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("YN_TRANSITION"):
		current_anim_state = AnimState.YN_TRANSITION
		animated_sprite.play("YN_TRANSITION")
		await animated_sprite.animation_finished

	_play_loop_if_exists("NO")
	current_anim_state = AnimState.NO

	if respawn_time > 0.0:
		await get_tree().create_timer(respawn_time).timeout

	if is_destroying:
		return

	if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("NY_TRANSITION"):
		current_anim_state = AnimState.NY_TRANSITION
		animated_sprite.play("NY_TRANSITION")
		await animated_sprite.animation_finished

	set_active()
	_play_loop_if_exists("YES")
	current_anim_state = AnimState.YES
	_mark_perfect_candidates_on_yes_activation()
	is_transitioning = false

func set_inactive() -> void:
	is_active = false
	if collision_shape:
		collision_shape.set_deferred("disabled", true)

func set_active() -> void:
	is_active = true
	if collision_shape:
		collision_shape.set_deferred("disabled", false)

func trigger_bounce(player):
	await super.trigger_bounce(player)

func _play_loop_if_exists(anim_name: String) -> void:
	if not animated_sprite or not animated_sprite.sprite_frames:
		return
	if animated_sprite.sprite_frames.has_animation(anim_name):
		animated_sprite.play(anim_name)
		animated_sprite.sprite_frames.set_animation_loop(anim_name, true)
