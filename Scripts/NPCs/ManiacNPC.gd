extends BaseNPC
class_name ManiacNPC

## ============================================
## ManiacNPC - 疯子 NPC
## ============================================
## 功能:
## - 待机状态机
## - 巡逻行为
## - 挑战系统
## ============================================

## 第一阶段挑战配置
@export var challenge_config: ChallengeConfig

## 第二阶段挑战配置
@export var stage2_challenge_config: ChallengeConfig
## 第三阶段挑战配置
@export var stage3_challenge_config: ChallengeConfig

## 挑战 UI 场景（在 Inspector 中拖拽 ChallengeCounter.tscn）
@export var challenge_ui_scene: PackedScene

var challenge_controller: ChallengeController = null  # 当前挑战控制器
var current_challenge_stage: int = 0  # 当前挑战阶段（0=未开始，1=第一阶段，2=第二阶段，3=第三阶段）

## 动画状态配置（内部变量）
## idle_animation: 待机空闲动画名称
var idle_animation: String = "IDLE"

## move_animation: 巡逻移动动画名称
var move_animation: String = "MOVE"

## talk_animation: 对话交互动画名称
var talk_animation: String = "TALK"

## impressed_animation: 对玩家表现印象深刻时的动画名称
var impressed_animation: String = "IMPRESSED"

## amazed_animation: 对玩家表现感到惊讶时的动画名称
var amazed_animation: String = "AMAZED"

## stunned_animation: 对玩家表现感到震惊时的动画名称
var stunned_animation: String = "STUNNED"

## go_fanatical_animation: 狂热状态动画名称（此状态下不可交互）
var go_fanatical_animation: String = "GOFANATICAL"

## 活动范围引用（在场景中手动指定）
## patrol_area: 指向场景中的 TextArea 实例，定义 NPC 的活动边界
@export var patrol_area: TextArea

## 挑战区域引用（在场景中手动指定）
## text_area: 指向场景中的 TextArea 实例，用于获取挑战区域的大小和位置
@export var challenge_area: TextArea

## 或者直接外部化大小参数（推荐）
## 活动范围宽度（如果没有设置 patrol_area）
@export var patrol_width: float = 200.0

## 残影系统相关参数
## 残影场景（在 Inspector 中拖拽 Afterimage.tscn）
@export var afterimage_scene: PackedScene
## 残影是否启用（可以在游戏中动态开关）
@export var afterimage_enabled: bool = true

## 挑战区域大小
@export var challenge_area_size: Vector2 = Vector2(300, 200)

## 移动配置
@export_category("Movement Settings")
## 巡逻移动速度（像素/秒）
@export var move_speed: float = 50.0

# 待机状态枚举
enum IdleState { IDLE, MOVE, GOFANATICAL }

# 交互状态枚举
enum InteractionState { TALK, IMPRESSED, AMAZED, STUNNED }

# 状态变量
var current_idle_state: IdleState = IdleState.IDLE
var state_timer: float = 0.0
var state_duration: float = 8.0
var initial_position: Vector2
var patrol_bounds: Rect2
var afterimage_trail: Node = null
var afterimage_timer: float = 0.0
var _last_afterimage_position: Vector2 = Vector2.ZERO
var _last_move_direction: Vector2 = Vector2.ZERO

func _ready():
	npc_id = "maniac_01"
	initial_position = position
	
	# 修复：从 NPC_Areas 获取区域
	if not patrol_area:
		patrol_area = get_node_or_null("../../NPC_Areas/Maniac_Patrol/PatrolArea")
	
	if not challenge_area:
		challenge_area = get_node_or_null("../../NPC_Areas/Maniac_Challenge/ChallengeArea")
	
	# 初始化 DialogueSystem 信号连接
	var dialogue_system = get_node_or_null("/root/DialogueSystem")
	if dialogue_system:
		if dialogue_system.has_signal("dialogue_started"):
			dialogue_system.dialogue_started.connect(_on_dialogue_started)
		if dialogue_system.has_signal("dialogue_ended"):
			dialogue_system.dialogue_ended.connect(_on_dialogue_ended)
	
	_play_default_idle()
	
	# 初始化残影系统（严格按照Player模式）
	ensure_afterimage_trail()
	_last_afterimage_position = global_position
	
	# 修复：延迟初始化区域，确保 global_transform 已经更新
	call_deferred("_init_patrol_bounds")
	
	# 创建挑战控制器
	if challenge_config:
		challenge_controller = ChallengeController.new()
		challenge_controller.config = challenge_config  # 默认使用第一阶段配置
		add_child(challenge_controller)
		
		# 连接信号
		challenge_controller.challenge_completed.connect(_on_challenge_completed)
		challenge_controller.challenge_failed.connect(_on_challenge_failed)
	else:
		push_warning("ManiacNPC: 没有配置挑战控制器（Stage1）")
		
	# 修复：重新连接 body_entered/body_exited 到 ManiacNPC 的方法
	body_entered.connect(_on_body_entered.bind())
	body_exited.connect(_on_body_exited.bind())
	
	# 初始隐藏交互提示
	if interaction_prompt:
		interaction_prompt.visible = false

## 身体进入信号处理（覆盖 BaseNPC 以支持狂热状态）
func _on_body_entered(body):
	if body.is_in_group("player"):
		player_in_range = true
		_update_interaction_prompt_visibility()

## 身体离开信号处理（覆盖 BaseNPC）
func _on_body_exited(body):
	if body.is_in_group("player"):
		player_in_range = false
		if interaction_prompt:
			interaction_prompt.visible = false

func _init_patrol_bounds():
	# 初始化活动范围
	if patrol_area:
		var rect = patrol_area.get_global_rect()
		patrol_bounds = rect

func _process(_delta):
	# 修复：先调用父类的 _process，处理交互检测
	super._process(_delta)
	
	# 修复 DialogueSystem
	var dialogue_system = get_node_or_null("/root/DialogueSystem")
	var in_dialogue = false
	if dialogue_system:
		in_dialogue = dialogue_system.is_dialogue_active
	
	# 修复：不再访问 ManiacChallenge，使用 challenge_controller
	var in_challenge = false
	if challenge_controller and challenge_controller.current_state == ChallengeController.State.ACTIVE:
		in_challenge = true
	
	if not in_dialogue and not in_challenge:
		_update_idle_state(_delta)
			
		# 处理残影效果
		if afterimage_enabled and afterimage_trail:
			handle_maniac_afterimages(_delta)

## 更新待机状态
func _update_idle_state(delta):
	state_timer += delta
	
	if state_timer >= state_duration:
		state_timer = 0.0
		_switch_idle_state()
	
	match current_idle_state:
		IdleState.IDLE:
			play_animation(idle_animation)
			# 修复：状态变化时立即更新交互提示
			_update_interaction_prompt_visibility()
		IdleState.MOVE:
			_patrol_movement(delta)  # 传递 delta
			play_animation(move_animation)
			# 修复：状态变化时立即更新交互提示
			_update_interaction_prompt_visibility()
		IdleState.GOFANATICAL:
			play_animation(go_fanatical_animation)
			# 修复：狂热状态立即隐藏交互提示
			if interaction_prompt:
				interaction_prompt.visible = false

## 修复：根据当前状态更新交互提示可见性
func _update_interaction_prompt_visibility():
	if not player_in_range:
		if interaction_prompt:
			interaction_prompt.visible = false
		return
	
	# 检查玩家是否在冲刺
	var player = get_tree().get_first_node_in_group("player")
	if player and player.current_state == player.PlayerState.DASH:
		if interaction_prompt:
			interaction_prompt.visible = false
		return
	
	# 非狂热状态且可以交互时才显示
	if current_idle_state != IdleState.GOFANATICAL:
		if !interact_once or (interact_once and !has_interacted):
			if interaction_prompt:
				interaction_prompt.visible = true
		else:
			if interaction_prompt:
				interaction_prompt.visible = false
	else:
		if interaction_prompt:
			interaction_prompt.visible = false

## 切换待机状态
func _switch_idle_state():
	var states = [IdleState.IDLE, IdleState.MOVE, IdleState.GOFANATICAL]
	states.erase(current_idle_state)
	current_idle_state = states[randi() % states.size()]

## 巡逻移动（限制在 patrol_area 范围内）
func _patrol_movement(delta):
	if not patrol_area:
		# 没有设置活动范围，自由移动
		var offset = sin(state_timer * 0.5) * (patrol_width / 2)
		position.x = initial_position.x + offset
		return
	
	# 修复：统一使用世界坐标计算
	var actual_patrol_size = patrol_area.get_actual_size()
	var target_x = global_position.x + sin(state_timer * 0.5) * (actual_patrol_size.x / 2)
	
	# 限制在活动范围内（世界坐标）
	var min_x = patrol_bounds.position.x
	var max_x = patrol_bounds.end.x
	
	target_x = clamp(target_x, min_x, max_x)
	
	# 使用 delta 独立的方式平滑移动
	var move_distance = move_speed * delta
	var direction = sign(target_x - global_position.x)
	var new_global_x = global_position.x + direction * move_distance
	
	# 确保不超过目标位置
	if direction > 0 and new_global_x > target_x:
		new_global_x = target_x
	elif direction < 0 and new_global_x < target_x:
		new_global_x = target_x
	
	# 转换回局部坐标
	global_position.x = new_global_x

## 尝试交互（覆盖 BaseNPC 的方法）
func try_interact():
	if current_idle_state == IdleState.GOFANATICAL:
		return
	
	# 使用 challenge_controller 检查
	if challenge_controller and challenge_controller.current_state == ChallengeController.State.ACTIVE:
		return
	
	# 调用 BaseNPC 的 try_interact
	super.try_interact()

## 开始交互
func _start_interaction():
	var dialogue_system = get_node_or_null("/root/DialogueSystem")
	var in_dialogue = false
	if dialogue_system:
		in_dialogue = dialogue_system.is_dialogue_active
	
	if in_dialogue:
		return
	
	if not dialogue_resource:
		push_error("ManiacNPC: 没有配置对话资源！请在检查器中指定")
		return
	
	# 修复：使用继承的 balloon_scene
	if not balloon_scene:
		push_error("ManiacNPC: balloon_scene 未配置！请在 Inspector 中拖拽 MyBalloon.tscn")
		return
	
	var balloon = balloon_scene.instantiate()
	get_tree().current_scene.add_child(balloon)
	
	# 传递 npc 引用，让对话文件可以调用 NPC 的方法
	var game_states = {
		"npc": self,
		"ManiacChallenge": challenge_controller,
		"Global": Global,
		"TaskManager": get_node_or_null("/root/TaskManager")
	}
	
	balloon.start(dialogue_resource, "start", [game_states])
	
	if animated_sprite and animated_sprite.sprite_frames:
		if animated_sprite.sprite_frames.has_animation(talk_animation):
			play_animation(talk_animation)

## 对话结束处理
func _on_dialogue_ended():
	await get_tree().process_frame
	super._on_dialogue_ended()
	_play_default_idle()

func _play_default_idle():
	if animated_sprite and animated_sprite.sprite_frames:
		if animated_sprite.sprite_frames.has_animation(idle_animation):
			play_animation(idle_animation)

## 确保存在 AfterimageTrail 节点（严格按照 Player 模式）
func ensure_afterimage_trail():
	if is_instance_valid(afterimage_trail):
		return
	afterimage_trail = get_node_or_null("AfterimageTrail")
	if afterimage_trail == null:
		push_error("ManiacNPC: 未找到 AfterimageTrail 节点，请确保场景中已添加")
		return
	
	# 检查残影场景是否配置
	if not afterimage_scene:
		push_warning("ManiacNPC: afterimage_scene 未配置，残影将无法生成")
	
	print("ManiacNPC: 已启用本地 AfterimageTrail")

## 处理 ManiacNPC 移动残影
func handle_maniac_afterimages(delta):
	# 只在 MOVE 状态生成残影
	if current_idle_state != IdleState.MOVE:
		afterimage_timer = 0.0
		_last_afterimage_position = global_position
		return

	# 静止时不生成残影
	var frame_move = global_position - _last_afterimage_position
	var moved_distance = frame_move.length()
	if moved_distance > 0.01:
		_last_move_direction = frame_move.normalized()
	_last_afterimage_position = global_position
	if moved_distance <= 0.01:
		afterimage_timer = 0.0
		return
	
	afterimage_timer += delta
	var interval = afterimage_trail.get_interval("maniac_move")
	
	if afterimage_timer >= interval:
		afterimage_timer = 0.0
		create_maniac_afterimage()

## 创建单个 ManiacNPC 残影
func create_maniac_afterimage():
	if afterimage_trail == null or not afterimage_scene:
		return
	
	# 获取当前帧纹理
	var current_texture = get_current_frame_texture()
	if current_texture == null:
		return
	
	# 按“使用者移动方向的反方向”设置残影漂移方向（与 Player 逻辑一致）
	var move_direction = Vector2.ZERO
	if _last_move_direction != Vector2.ZERO:
		move_direction = -_last_move_direction
	else:
		move_direction = Vector2(-1 if animated_sprite.flip_h else 1, 0)
	
	# 生成残影
	var afterimage = afterimage_trail.spawn(
		"maniac_move",
		global_position,
		current_texture,
		animated_sprite.flip_h,
		Vector2.ONE * 0.8,
		move_direction,
		-1.0,
		animated_sprite.z_index - 1
	)
	
	if afterimage:
		afterimage.npc_ref = self  # 建立反向引用
		print("ManiacNPC: 生成移动残影")

## 获取当前动画帧纹理
func get_current_frame_texture() -> Texture2D:
	if animated_sprite and animated_sprite.sprite_frames:
		var frame_count = animated_sprite.sprite_frames.get_frame_count(animated_sprite.animation)
		if frame_count > 0 and animated_sprite.frame < frame_count:
			return animated_sprite.sprite_frames.get_frame_texture(
				animated_sprite.animation, 
				animated_sprite.frame
			)
	return null

## 清理残影资源（当 NPC 被销毁时调用）
func cleanup_afterimages():
	if afterimage_trail:
		# 移除 AfterimageTrail 组件
		afterimage_trail.queue_free()
		afterimage_trail = null
	print("ManiacNPC: 已清理残影资源")

## 启动挑战（由对话文件调用）- 第一阶段
func launch_challenge():
	_create_challenge_controller_if_needed(1)
	if challenge_controller:
		# 传递 UI 场景给控制器
		challenge_controller.challenge_ui_scene = challenge_ui_scene
		challenge_controller.start_challenge()
	else:
		push_error("ManiacNPC: 无法创建挑战控制器")

## 挑战完成回调（由 ChallengeController 调用）
func _on_challenge_completed():
	print("DEBUG ManiacNPC: 挑战完成")
	
	# 根据当前阶段设置对应的完成标志
	if current_challenge_stage == 1:
		Global.maniac_challenge_completed = true
		Global.maniac_last_challenge_failed = false
		
		# 检查是否应该解锁二段跳
		if not Global.unlocked_abilities.has("double_jump"):
			Global.unlocked_abilities["double_jump"] = true
			print("DEBUG ManiacNPC: 解锁二段跳能力")
		
		# 修复：保存到存档
		if Global.current_save_slot >= 0:
			SaveManager.save_game(Global.current_save_slot, Global.get_save_data())
			print("DEBUG ManiacNPC: 第一阶段完成已保存到存档")
	
	elif current_challenge_stage == 2:
		Global.maniac_stage2_challenge_completed = true
		Global.maniac_stage2_last_challenge_failed = false
		
		# 修复：保存到存档
		if Global.current_save_slot >= 0:
			SaveManager.save_game(Global.current_save_slot, Global.get_save_data())
			print("DEBUG ManiacNPC: 第二阶段完成已保存到存档")
	
	elif current_challenge_stage == 3:
		Global.maniac_stage3_challenge_completed = true
		Global.maniac_stage3_last_challenge_failed = false
		if Global.current_save_slot >= 0:
			SaveManager.save_game(Global.current_save_slot, Global.get_save_data())
			print("DEBUG ManiacNPC: 第三阶段完成已保存到存档")

	# 重置失败标志
	Global.maniac_last_challenge_failed = false
	Global.maniac_stage2_last_challenge_failed = false
	Global.maniac_stage3_last_challenge_failed = false

## 挑战失败回调（由 ChallengeController 调用）
func _on_challenge_failed():
	print("DEBUG ManiacNPC: 挑战失败")
	
	# 根据当前阶段设置对应的失败标志
	if current_challenge_stage == 1:
		Global.maniac_challenge_completed = false
		Global.maniac_last_challenge_failed = true
	
	elif current_challenge_stage == 2:
		Global.maniac_stage2_challenge_completed = false
		Global.maniac_stage2_last_challenge_failed = true
	
	elif current_challenge_stage == 3:
		Global.maniac_stage3_challenge_completed = false
		Global.maniac_stage3_last_challenge_failed = true

## 启动第二阶段挑战（由对话文件调用）
func launch_stage2_challenge():
	_create_challenge_controller_if_needed(2)
	if challenge_controller:
		# 传递 UI 场景给控制器
		challenge_controller.challenge_ui_scene = challenge_ui_scene
		challenge_controller.start_challenge()
	else:
		push_error("ManiacNPC: 无法创建第二阶段挑战控制器")

## 启动第三阶段挑战（由对话文件调用）
func launch_stage3_challenge():
	_create_challenge_controller_if_needed(3)
	if challenge_controller:
		challenge_controller.challenge_ui_scene = challenge_ui_scene
		challenge_controller.start_challenge()
	else:
		push_error("ManiacNPC: 无法创建第三阶段挑战控制器")

## 根据需要创建 ChallengeController
func _create_challenge_controller_if_needed(stage: int):
	# 如果已经有控制器且阶段相同，直接返回
	if challenge_controller and current_challenge_stage == stage:
		return
	
	# 清理旧的控制器
	if challenge_controller:
		challenge_controller.queue_free()
		challenge_controller = null
	
	# 根据阶段选择配置
	var selected_config: ChallengeConfig = null
	if stage == 1:
		selected_config = challenge_config
	elif stage == 2:
		selected_config = stage2_challenge_config
	elif stage == 3:
		selected_config = stage3_challenge_config
	
	if not selected_config:
		push_error("ManiacNPC: 第", stage, "阶段配置为空！")
		return
	
	# 创建新的控制器
	challenge_controller = ChallengeController.new()
	challenge_controller.config = selected_config
	challenge_controller.challenge_ui_scene = challenge_ui_scene  # 传递 UI 场景
	add_child(challenge_controller)
	current_challenge_stage = stage
	
	# 连接信号
	challenge_controller.challenge_completed.connect(_on_challenge_completed)
	challenge_controller.challenge_failed.connect(_on_challenge_failed)
	
func _play_impressed_animation():
	if animated_sprite and animated_sprite.sprite_frames:
		if animated_sprite.sprite_frames.has_animation(impressed_animation):
			play_animation(impressed_animation)
