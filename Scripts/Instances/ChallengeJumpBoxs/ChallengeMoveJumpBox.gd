extends ChallengeJumpBox
class_name ChallengeMoveJumpBox

## ============================================
## 移动式挑战 JumpBox - 继承自基础版
## ============================================
## 新增功能:
## - 沿两点路径移动
## - 可配置速度和停留时间
## - 到达端点自动折返
## ============================================

## 移动设置
@export_category("移动设置")
## 移动目标点 1（相对于初始位置的偏移）
@export var target_point_1_offset: Vector2 = Vector2(-100, 0)
## 移动目标点 2（相对于初始位置的偏移）
@export var target_point_2_offset: Vector2 = Vector2(100, 0)
## 移动速度（像素/秒）- 帧率独立
@export var move_speed: float = 20.0
## 到达端点后停留时间（秒）
@export var wait_time_at_endpoint: float = 1.0

# 内部变量
var current_target_index: int = 0  # 当前目标点索引（0 或 1）
var wait_timer: float = 0.0
var is_waiting: bool = false
var actual_target_1: Vector2 = Vector2.ZERO  # 实际目标点 1（世界坐标）
var actual_target_2: Vector2 = Vector2.ZERO  # 实际目标点 2（世界坐标）

func _ready():
	# 调用父类的 _ready()
	super._ready()
	
	# 计算实际目标点（相对于初始位置）
	actual_target_1 = global_position + target_point_1_offset
	actual_target_2 = global_position + target_point_2_offset
	
	# 移动到起始点（目标点 1）
	global_position = actual_target_1
	current_target_index = 1  # 下一个目标是目标点 2

func _process(delta):
	# 仅 YES 激活态移动；NO 和所有 TRANSITION/END/START 状态都冻结移动。
	if not is_active or not animated_sprite or animated_sprite.animation != "YES" or current_anim_state != AnimState.YES:
		return

	# 如果正在等待，更新计时器
	if is_waiting:
		wait_timer += delta
		if wait_timer >= wait_time_at_endpoint:
			is_waiting = false
			wait_timer = 0.0
			_switch_target()
		return
	
	# 移动到目标点（帧率独立）
	var current_pos = global_position
	var target_pos = _get_current_target()
	
	var direction = (target_pos - current_pos).normalized()
	var distance_to_target = current_pos.distance_to(target_pos)
	
	# 修复：帧率独立的移动
	# 使用 min 确保不会超过目标点
	var move_distance = min(move_speed * delta, distance_to_target)
	global_position += direction * move_distance
	
	# 检查是否到达目标点（距离小于阈值）
	if distance_to_target < 1.0:
		global_position = target_pos  # 精确对齐
		is_waiting = true
		wait_timer = 0.0

## 获取当前目标点
func _get_current_target() -> Vector2:
	if current_target_index == 0:
		return actual_target_1
	else:
		return actual_target_2

## 切换目标点
func _switch_target():
	current_target_index = 1 - current_target_index  # 在 0 和 1 之间切换

## 覆盖父类方法：重新激活时也重置移动状态
func reactivate():
	super.reactivate()
	# 重置到起始点
	global_position = actual_target_1
	current_target_index = 1
	is_waiting = false
	wait_timer = 0.0

## 获取扩展状态信息
func get_extended_state() -> Dictionary:
	var base_state = get_current_state()
	base_state["is_waiting"] = is_waiting
	base_state["wait_timer"] = wait_timer
	base_state["current_target_index"] = current_target_index
	return base_state
