extends Node2D
class_name HealthUnit  # 添加 class_name

@onready var animated_sprite = $AnimatedSprite2D

## 血量单位状态枚举
enum HealthState {
	NULL,      # 空血（灰色）
	HAVE,      # 有血（红色满格）
	LASTHAVE,  # 最后一点血（特殊显示）
	ADD,       # 增加动画
	REDUCE     # 减少动画
}

## 当前血量状态
var current_state: HealthState = HealthState.NULL

func _ready():
	set_state(HealthState.NULL)
	
	# 连接动画完成信号
	if animated_sprite:
		animated_sprite.animation_finished.connect(_on_animation_finished)

func set_state(new_state: HealthState):
	# 如果状态相同，不处理
	if current_state == new_state:
		return
	
	# 退出旧状态
	exit_state(current_state)
	
	# 进入新状态
	current_state = new_state
	enter_state(new_state)

func enter_state(state: HealthState):
	match state:
		HealthState.NULL:
			animated_sprite.play("NULL")
		HealthState.HAVE:
			animated_sprite.play("HAVE")
		HealthState.LASTHAVE:
			animated_sprite.play("LASTHAVE")
		HealthState.ADD:
			animated_sprite.play("ADD")
		HealthState.REDUCE:
			animated_sprite.play("REDUCE")

func exit_state(_state: HealthState):
	# 状态退出时的清理工作（目前不需要，保留扩展性）
	pass

func _on_animation_finished():
	# 动画完成后自动切换到对应状态
	match animated_sprite.animation:
		"ADD":
			set_state(HealthState.HAVE)
		"REDUCE":
			set_state(HealthState.NULL)
