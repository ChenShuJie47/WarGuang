extends Node2D
class_name PlayerFXController

## 单次特效使用的 SpriteFrames（Inspector 拖拽设置）。
@export var fx_frames: SpriteFrames
## 超级冲刺特效的播放间隔，周期性单播，不循环。
@export var super_dash_interval: float = 0.15
## 超级冲刺特效的根节点层级偏移。
@export var fx_z_index_offset: int = 1

## 当前绑定的玩家节点。
var player: Player = null
## 超级冲刺特效的累计计时器。
var super_dash_timer: float = 0.0
## 标记超级冲刺周期 FX 是否已经发出第一帧。
var super_dash_started: bool = false

## 跑步特效锚点节点。
@onready var run_anchor: Node2D = get_node_or_null("RunAnchor")
## 冲刺特效锚点节点。
@onready var dash_anchor: Node2D = get_node_or_null("DashAnchor")
## 跳跃特效锚点节点。
@onready var jump_anchor: Node2D = get_node_or_null("JumpAnchor")
## 落地特效锚点节点。
@onready var land_anchor: Node2D = get_node_or_null("LandAnchor")
## 墙跳特效锚点节点。
@onready var wall_jump_anchor: Node2D = get_node_or_null("WallJumpAnchor")
## 受伤特效锚点节点。
@onready var hurt_anchor: Node2D = get_node_or_null("HurtAnchor")
## 超级冲刺特效锚点节点。
@onready var super_dash_anchor: Node2D = get_node_or_null("SuperDashAnchor")
## JumpBox 普通触发特效锚点节点。
@onready var jumpbox_normal_anchor: Node2D = get_node_or_null("JumpBoxNormalAnchor") if get_node_or_null("JumpBoxNormalAnchor") else get_node_or_null("JumpBoxTriggerAnchor1")
## JumpBox 完美触发特效锚点节点。
@onready var jumpbox_perfect_anchor: Node2D = get_node_or_null("JumpBoxPerfectAnchor") if get_node_or_null("JumpBoxPerfectAnchor") else get_node_or_null("JumpBoxTriggerAnchor2")

## 启用控制器自身的每帧处理。
func _ready() -> void:
	set_process(true)

## 绑定玩家并注册反馈事件。
func setup(player_ref: Player) -> void:
	player = player_ref
	if not is_instance_valid(player):
		return
	if player.has_method("register_feedback_hook"):
		player.register_feedback_hook(&"state_changed", Callable(self, "_on_state_changed"))
		player.register_feedback_hook(&"landed", Callable(self, "_on_landed"))
		player.register_feedback_hook(&"jumpbox_bounce_started", Callable(self, "_on_jumpbox_bounce_started"))

## 每帧只负责超级冲刺期间的周期性特效。
func _process(delta: float) -> void:
	if not is_instance_valid(player) or fx_frames == null:
		return
	if player.current_state == player.PlayerState.SUPERDASH:
		super_dash_timer += delta
		if not super_dash_started:
			super_dash_started = true
			_spawn_fx("SuperDashAnchor", _get_fx_world_position("SuperDashAnchor"), player.animated_sprite.flip_h)
		elif super_dash_timer >= super_dash_interval:
			super_dash_timer = 0.0
			_spawn_fx("SuperDashAnchor", _get_fx_world_position("SuperDashAnchor"), player.animated_sprite.flip_h)
	else:
		super_dash_timer = 0.0
		super_dash_started = false

## 处理状态切换触发的单播特效。
func _on_state_changed(payload: Dictionary) -> void:
	if not is_instance_valid(player):
		return
	var from_state = payload.get("from", player.PlayerState.IDLE)
	var to_state = payload.get("to", player.PlayerState.IDLE)
	if from_state == to_state:
		return
	match to_state:
		player.PlayerState.RUN:
			_spawn_fx("RunAnchor", _get_fx_world_position("RunAnchor"), player.animated_sprite.flip_h)
		player.PlayerState.DASH:
			_spawn_fx("DashAnchor", _get_fx_world_position("DashAnchor"), player.animated_sprite.flip_h)
		player.PlayerState.JUMP:
			_spawn_fx("JumpAnchor", _get_fx_world_position("JumpAnchor"), player.animated_sprite.flip_h)
		player.PlayerState.WALLJUMP:
			_spawn_fx("WallJumpAnchor", _get_fx_world_position("WallJumpAnchor"), player.animated_sprite.flip_h)
		player.PlayerState.HURT:
			_spawn_fx("HurtAnchor", _get_fx_world_position("HurtAnchor"), player.animated_sprite.flip_h)

## 处理着地事件，播放落地特效。
func _on_landed(_payload: Dictionary) -> void:
	if not is_instance_valid(player):
		return
	_spawn_fx("LandAnchor", _get_fx_world_position("LandAnchor"), player.animated_sprite.flip_h)

## 处理 JumpBox 触发事件，按普通/完美触发不同特效。
func _on_jumpbox_bounce_started(payload: Dictionary) -> void:
	if not is_instance_valid(player):
		return
	var grade = String(payload.get("grade", "normal"))
	if grade == "perfect":
		var perfect_anim = _resolve_fx_animation_name("JumpBoxPerfectAnchor", "JumpBoxTriggerAnchor2")
		if perfect_anim != "":
			_spawn_fx(perfect_anim, _get_fx_world_position(perfect_anim), player.animated_sprite.flip_h)
	else:
		var normal_anim = _resolve_fx_animation_name("JumpBoxNormalAnchor", "JumpBoxTriggerAnchor1")
		if normal_anim != "":
			_spawn_fx(normal_anim, _get_fx_world_position(normal_anim), player.animated_sprite.flip_h)

## 计算锚点节点的世界坐标，可按朝向自动镜像 X 方向。
func _get_anchor_world(anchor: Node2D, directional: bool = false) -> Vector2:
	if not is_instance_valid(anchor):
		return Vector2.INF
	var local = anchor.position
	if directional and is_instance_valid(player) and not player.is_facing_right:
		local.x = -local.x
	return global_position + local

## 计算各类特效的生成位置，默认以玩家角色当前位置为基准。
func _get_fx_world_position(effect_name: String) -> Vector2:
	match effect_name:
		"RunAnchor":
			var run_pos = _get_anchor_world(run_anchor, true)
			if run_pos != Vector2.INF:
				return run_pos
		"DashAnchor":
			var dash_pos = _get_anchor_world(dash_anchor, true)
			if dash_pos != Vector2.INF:
				return dash_pos
		"JumpAnchor":
			var jump_pos = _get_anchor_world(jump_anchor, false)
			if jump_pos != Vector2.INF:
				return jump_pos
		"LandAnchor":
			var land_pos = _get_anchor_world(land_anchor, false)
			if land_pos != Vector2.INF:
				return land_pos
		"WallJumpAnchor":
			var wall_pos = _get_anchor_world(wall_jump_anchor, true)
			if wall_pos != Vector2.INF:
				return wall_pos
		"HurtAnchor":
			var hurt_pos = _get_anchor_world(hurt_anchor, false)
			if hurt_pos != Vector2.INF:
				return hurt_pos
		"SuperDashAnchor":
			var super_dash_pos = _get_anchor_world(super_dash_anchor, true)
			if super_dash_pos != Vector2.INF:
				return super_dash_pos
		"JumpBoxNormalAnchor", "JumpBoxTriggerAnchor1":
			var jumpbox_normal_pos = _get_anchor_world(jumpbox_normal_anchor, true)
			if jumpbox_normal_pos != Vector2.INF:
				return jumpbox_normal_pos
		"JumpBoxPerfectAnchor", "JumpBoxTriggerAnchor2":
			var jumpbox_perfect_pos = _get_anchor_world(jumpbox_perfect_anchor, true)
			if jumpbox_perfect_pos != Vector2.INF:
				return jumpbox_perfect_pos
		_:
			pass
	return player.animated_sprite.global_position if is_instance_valid(player) and is_instance_valid(player.animated_sprite) else global_position

## 按优先级解析可用的动画名，支持新旧命名兼容。
func _resolve_fx_animation_name(primary_name: String, fallback_name: String) -> String:
	if fx_frames == null:
		return ""
	if fx_frames.has_animation(primary_name):
		return primary_name
	if fallback_name != "" and fx_frames.has_animation(fallback_name):
		return fallback_name
	return ""

## 创建单个 FX 播放实例，播放完自动释放。
func _spawn_fx(effect_name: String, world_position: Vector2, flip_h: bool) -> void:
	if fx_frames == null or not fx_frames.has_animation(effect_name):
		return
	var fx_sprite := AnimatedSprite2D.new()
	fx_sprite.sprite_frames = fx_frames
	fx_sprite.animation = effect_name
	fx_sprite.flip_h = flip_h
	fx_sprite.global_position = world_position
	fx_sprite.top_level = true
	fx_sprite.z_index = player.z_index + fx_z_index_offset if is_instance_valid(player) else fx_z_index_offset
	fx_sprite.play()
	fx_sprite.animation_finished.connect(func():
		if is_instance_valid(fx_sprite):
			fx_sprite.queue_free()
	)
	var parent_node = player.get_parent() if is_instance_valid(player) and is_instance_valid(player.get_parent()) else get_tree().current_scene
	if parent_node:
		parent_node.add_child(fx_sprite)
