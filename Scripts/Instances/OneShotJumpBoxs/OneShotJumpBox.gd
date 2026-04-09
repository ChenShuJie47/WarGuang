extends BaseJumpBox
class_name OneShotJumpBox

## 一次性 JumpBox（START -> YES -> END -> 销毁）

@export_category("弹跳设置")
@export var vertical_force: float = 900.0

@export_category("生命周期")
## 进入 YES 后，若未触发，超过该时长自动销毁（秒）；<=0 表示不自动销毁
@export var auto_destroy_time: float = 0.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var is_active: bool = false
var is_destroying: bool = false

func _ready():
	_base_setup_trigger_detection()
	call_deferred("_start_lifecycle")

func _process(_delta):
	_base_process_trigger_detection()

func _start_lifecycle() -> void:
	if is_destroying:
		return
	set_inactive()
	if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("START"):
		animated_sprite.play("START")
		await animated_sprite.animation_finished
	if is_destroying:
		return
	set_active()
	if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("YES"):
		animated_sprite.play("YES")
		animated_sprite.sprite_frames.set_animation_loop("YES", true)
	_mark_perfect_candidates_on_yes_activation()

	if auto_destroy_time > 0.0:
		await get_tree().create_timer(auto_destroy_time).timeout
		if not is_destroying and is_active:
			await _play_end_and_destroy()

func _get_trigger_sprite() -> CanvasItem:
	return animated_sprite

func _is_trigger_active() -> bool:
	return is_active and not is_destroying

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
	if is_destroying:
		return
	set_inactive()
	await _play_end_and_destroy()

func _play_end_and_destroy() -> void:
	if is_destroying:
		return
	is_destroying = true
	if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("END"):
		animated_sprite.play("END")
		await animated_sprite.animation_finished
	queue_free()

func set_inactive() -> void:
	is_active = false
	if collision_shape:
		collision_shape.set_deferred("disabled", true)

func set_active() -> void:
	is_active = true
	if collision_shape:
		collision_shape.set_deferred("disabled", false)
