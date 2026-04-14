extends Node
class_name UITransitionAnimator

## 标题节点路径
@export var title_path: NodePath = NodePath("../Title")
## 额外参与动画的节点路径列表
@export var extra_target_paths: Array[NodePath] = []
## 入场动画时长（秒）
@export var enter_duration: float = 0.8
## 退场动画时长（秒）
@export var exit_duration: float = 0.4
## 标题节点上下漂移距离（像素）
@export var title_drift_distance: float = 80.0
## 额外节点上下漂移距离（像素）
@export var extra_drift_distance: float = 20.0
## 放大峰值倍率
@export var peak_scale_multiplier: float = 1.2
## 入场峰值停顿时长（秒）
@export var enter_peak_hold_duration: float = 0.3
## 退场峰值停顿时长（秒）
@export var exit_peak_hold_duration: float = 0.2
## 退场总时长中“放大到峰值”阶段占比（不含停顿）
@export_range(0.1, 0.8, 0.05) var exit_peak_phase_ratio: float = 0.2

# 缓存的标题节点
var _title: CanvasItem
# 缓存的额外节点
var _extra_targets: Array[CanvasItem] = []
# 初始标题颜色
var _initial_title_modulate: Color = Color(1, 1, 1, 1)
# 初始标题位置
var _initial_title_position: Vector2
# 初始标题缩放
var _initial_title_scale: Vector2 = Vector2.ONE
# 额外节点初始颜色缓存
var _extra_initial_modulates: Array[Color] = []
# 额外节点初始位置缓存
var _extra_initial_positions: Array[Vector2] = []
# 额外节点初始缩放缓存
var _extra_initial_scales: Array[Vector2] = []
# 当前动画Tween
var _tween: Tween = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_cache_targets()
	if _title:
		_initial_title_modulate = _title.modulate
		_initial_title_position = _title.position
		_initial_title_scale = _title.scale
	_apply_enter_start_state()

func play_enter_transition() -> void:
	if not _has_targets():
		return
	_stop_tween()
	_apply_enter_start_state()
	var hold_duration: float = minf(maxf(0.0, enter_peak_hold_duration), maxf(0.0, enter_duration - 0.01))
	var settle_duration: float = maxf(0.01, enter_duration - hold_duration)
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_CUBIC)
	_tween.set_ease(Tween.EASE_OUT)
	if hold_duration > 0.0:
		if _title:
			_tween.parallel().tween_property(_title, "modulate:a", _initial_title_modulate.a, hold_duration)
		for i in range(_extra_targets.size()):
			var hold_target = _extra_targets[i]
			_tween.parallel().tween_property(hold_target, "modulate:a", _extra_initial_modulates[i].a, hold_duration)
		_tween.chain()
	if _title:
		_tween.parallel().tween_property(_title, "modulate:a", _initial_title_modulate.a, settle_duration)
		_tween.parallel().tween_property(_title, "position:y", _initial_title_position.y, settle_duration)
		_tween.parallel().tween_property(_title, "scale", _initial_title_scale, settle_duration)
	for i in range(_extra_targets.size()):
		var target = _extra_targets[i]
		_tween.parallel().tween_property(target, "modulate:a", _extra_initial_modulates[i].a, settle_duration)
		_tween.parallel().tween_property(target, "position:y", _extra_initial_positions[i].y, settle_duration)
		_tween.parallel().tween_property(target, "scale", _extra_initial_scales[i], settle_duration)
	await _tween.finished

func play_exit_transition() -> void:
	if not _has_targets():
		return
	_stop_tween()
	var peak_duration: float = maxf(0.01, exit_duration * exit_peak_phase_ratio)
	var hold_duration: float = minf(maxf(0.0, exit_peak_hold_duration), maxf(0.0, exit_duration - peak_duration - 0.01))
	var vanish_duration: float = maxf(0.01, exit_duration - peak_duration - hold_duration)
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_CUBIC)
	_tween.set_ease(Tween.EASE_IN)
	if _title:
		_tween.parallel().tween_property(_title, "scale", _initial_title_scale * peak_scale_multiplier, peak_duration)
	for i in range(_extra_targets.size()):
		var target = _extra_targets[i]
		_tween.parallel().tween_property(target, "scale", _extra_initial_scales[i] * peak_scale_multiplier, peak_duration)

	if hold_duration > 0.0:
		_tween.chain().tween_interval(hold_duration)

	_tween.chain()
	if _title:
		_tween.parallel().tween_property(_title, "modulate:a", 0.0, vanish_duration)
		_tween.parallel().tween_property(_title, "position:y", _initial_title_position.y - title_drift_distance, vanish_duration)
		_tween.parallel().tween_property(_title, "scale", Vector2.ZERO, vanish_duration)
	for i in range(_extra_targets.size()):
		var target = _extra_targets[i]
		_tween.parallel().tween_property(target, "modulate:a", 0.0, vanish_duration)
		_tween.parallel().tween_property(target, "position:y", _extra_initial_positions[i].y + extra_drift_distance, vanish_duration)
		_tween.parallel().tween_property(target, "scale", Vector2.ZERO, vanish_duration)
	await _tween.finished

func reset_state() -> void:
	_stop_tween()
	if _title:
		_title.modulate = _initial_title_modulate
		_title.position = _initial_title_position
		_title.scale = _initial_title_scale
	for i in range(_extra_targets.size()):
		var target = _extra_targets[i]
		target.modulate = _extra_initial_modulates[i]
		target.position = _extra_initial_positions[i]
		target.scale = _extra_initial_scales[i]

func _apply_enter_start_state() -> void:
	if _title:
		_title.modulate = Color(_initial_title_modulate.r, _initial_title_modulate.g, _initial_title_modulate.b, 0.0)
		_title.position = Vector2(_initial_title_position.x, _initial_title_position.y - title_drift_distance)
		_title.scale = _initial_title_scale * peak_scale_multiplier
	for i in range(_extra_targets.size()):
		var target = _extra_targets[i]
		var base_modulate = _extra_initial_modulates[i]
		var base_pos = _extra_initial_positions[i]
		var base_scale = _extra_initial_scales[i]
		target.modulate = Color(base_modulate.r, base_modulate.g, base_modulate.b, 0.0)
		target.position = Vector2(base_pos.x, base_pos.y + extra_drift_distance)
		target.scale = base_scale * peak_scale_multiplier

func _cache_targets() -> void:
	_title = _resolve_target(title_path)
	_extra_targets.clear()
	_extra_initial_modulates.clear()
	_extra_initial_positions.clear()
	_extra_initial_scales.clear()
	for path in extra_target_paths:
		var target := _resolve_target(path)
		if target:
			_extra_targets.append(target)
			_extra_initial_modulates.append(target.modulate)
			_extra_initial_positions.append(target.position)
			_extra_initial_scales.append(target.scale)

func _resolve_target(path: NodePath) -> CanvasItem:
	var target := get_node_or_null(path)
	if target and target is CanvasItem:
		return target
	return null

func _has_targets() -> bool:
	return _title != null or not _extra_targets.is_empty()

func _stop_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null
