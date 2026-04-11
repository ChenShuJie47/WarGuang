class_name Player
extends CharacterBody2D

## 状态枚举 
enum PlayerState {
	IDLE, MOVE, RUN, JUMP, DOWN, DASH, GLIDE, HURT, DIE, 
	SLEEP, LOOKUP, LOOKDOWN, INTERACTIVE, WALLGRIP, WALLJUMP,
	SUPERDASHSTART, SUPERDASH  # 新增超级冲刺状态
}
## 伤害类型枚举
enum DamageType {
	NORMAL,          # 普通伤害
	SHADOW,          # 阴影伤害
	WARP_NORMAL,     # 普通传送伤害
	WARP_SHADOW      # 阴影传送伤害
}

## 帧率标准化设置
const TARGET_FPS: float = 60.0                    # 目标帧率（与 physics_ticks_per_second 一致）
const FIXED_DELTA: float = 1.0 / TARGET_FPS       # 固定时间步长 = 0.01667 秒
const MAX_FRAME_TIME: float = 1.0 / 30.0          # 最大帧时间（30FPS 下限，防止卡顿时代码逻辑过快）
const CAMERA_LIMIT_DISABLED: int = 10000000       # 禁用相机限制时使用的极大边界值（与 PhantomCamera2D 默认值一致）
const CAMERA_TELEPORT_DEBUG: bool = false
const PlayerHitStopServiceScript = preload("res://Scripts/Player/PlayerHitStopService.gd")
const PlayerAirStateServiceScript = preload("res://Scripts/Player/PlayerAirStateService.gd")
const PlayerAirAbilityServiceScript = preload("res://Scripts/Player/PlayerAirAbilityService.gd")
const PlayerAirMotionServiceScript = preload("res://Scripts/Player/PlayerAirMotionService.gd")
const PlayerMovementServiceScript = preload("res://Scripts/Player/PlayerMovementService.gd")
const PlayerFeedbackServiceScript = preload("res://Scripts/Player/PlayerFeedbackService.gd")
const PlayerDamageServiceScript = preload("res://Scripts/Player/PlayerDamageService.gd")
const PlayerDamageOrchestratorServiceScript = preload("res://Scripts/Player/PlayerDamageOrchestratorService.gd")
const PlayerDamageStateServiceScript = preload("res://Scripts/Player/PlayerDamageStateService.gd")
const PlayerDamageFlowServiceScript = preload("res://Scripts/Player/PlayerDamageFlowService.gd")
const PlayerDoorTraversalServiceScript = preload("res://Scripts/Player/PlayerDoorTraversalService.gd")
const PlayerRoomTransitionServiceScript = preload("res://Scripts/Player/PlayerRoomTransitionService.gd")
const PlayerControlLockServiceScript = preload("res://Scripts/Player/PlayerControlLockService.gd")
const PlayerDialogueStateServiceScript = preload("res://Scripts/Player/PlayerDialogueStateService.gd")
const PlayerCameraBridgeServiceScript = preload("res://Scripts/Player/PlayerCameraBridgeService.gd")
const PlayerObserveStateServiceScript = preload("res://Scripts/Player/PlayerObserveStateService.gd")
const PlayerSleepStateServiceScript = preload("res://Scripts/Player/PlayerSleepStateService.gd")
const PlayerHurtStateServiceScript = preload("res://Scripts/Player/PlayerHurtStateService.gd")
const PlayerDieStateServiceScript = preload("res://Scripts/Player/PlayerDieStateService.gd")
const PlayerSpecialStateTimerServiceScript = preload("res://Scripts/Player/PlayerSpecialStateTimerService.gd")
const PlayerDeathFlowServiceScript = preload("res://Scripts/Player/PlayerDeathFlowService.gd")
const PlayerStateFlowServiceScript = preload("res://Scripts/Player/PlayerStateFlowService.gd")
const PlayerStateTransitionServiceScript = preload("res://Scripts/Player/PlayerStateTransitionService.gd")
const PlayerAnimationServiceScript = preload("res://Scripts/Player/PlayerAnimationService.gd")
const PlayerGlideStateServiceScript = preload("res://Scripts/Player/PlayerGlideStateService.gd")
const PlayerRuntimeTickServiceScript = preload("res://Scripts/Player/PlayerRuntimeTickService.gd")
const PlayerRuntimeFlowServiceScript = preload("res://Scripts/Player/PlayerRuntimeFlowService.gd")
const PlayerWarpFlowServiceScript = preload("res://Scripts/Player/PlayerWarpFlowService.gd")
const PlayerWarpFlightServiceScript = preload("res://Scripts/Player/PlayerWarpFlightService.gd")
const PlayerWarpResetServiceScript = preload("res://Scripts/Player/PlayerWarpResetService.gd")
const PlayerCameraDebugServiceScript = preload("res://Scripts/Player/PlayerCameraDebugService.gd")
const DEFAULT_HURT_HIT_STOP_DURATION: float = 0.1
const DEFAULT_HURT_HIT_STOP_INTENSITY: float = 1.2
const DEFAULT_JUMPBOX_HIT_STOP_DURATION: float = 0.25
const DEFAULT_JUMPBOX_HIT_STOP_INTENSITY: float = 0.8
## 独立的玩家 FX 控制器，用于状态单播与周期性特效。
const PlayerFXControllerScript = preload("res://Scripts/Player/PlayerFXController.gd")

## 节点引用
@onready var right_wall_ray = $WallRays/RightWallRay
@onready var left_wall_ray = $WallRays/LeftWallRay
@onready var animated_sprite = $AnimatedSprite2D
@onready var phantom_camera = $PhantomCamera2D
@onready var point_light = $PointLight2D  
@onready var timers = $Timers
@onready var camera_controller = $PlayerCameraController
## 统一管理跑步、冲刺、受伤、落地等一次性与周期性特效。
@onready var fx_controller = $PlayerFXController
@onready var canvas_modulate = get_tree().get_first_node_in_group("canvas_modulate")

##外部变量
#region Signals

## 残影场景（在 Inspector 中拖拽 Afterimage.tscn）
@export var afterimage_scene: PackedScene

## 移动设置
@export_category("移动设置")
## 基础移动速度（像素/秒）
@export var base_move_speed: float = 120.0
## 奔跑移动速度（像素/秒）
@export var run_move_speed: float = 240.0
## 地面加速度 (0-1，越大加速越快)
@export var ground_acceleration: float = 0.7
## 地面减速度 (0-1，越大减速越快)
@export var ground_deceleration: float = 0.8
## 空中移动控制力 (0-1，越小控制力越弱)
@export var air_control: float = 0.3
## 空中无输入时 JUMP 状态的基础衰减倍率（越大停得越快）
@export var air_no_input_deceleration_multiplier_jump: float = 1.2
## 空中无输入时 DOWN 状态的基础衰减倍率（越大停得越快）
@export var air_no_input_deceleration_multiplier_down: float = 1.8

## 跳跃设置
@export_category("跳跃设置")
## 跳跃移动速度（像素/秒）
@export var jump_move_speed: float = 140.0
## 一段跳初始速度
@export var jump_velocity: float = -140.0
## 二段跳初始速度
@export var double_jump_velocity: float = -120.0
## 最大跳跃按住时间（秒）
@export var max_jump_hold_time: float = 0.23
## 跳跃额外速度（长按期间每帧增加）
@export var jump_hold_boost: float = -35.0
## 重力
@export var gravity: float = 1300.0
## 最大下落速度
@export var max_fall_speed: float = 480.0
## 土狼时间（离开平台后仍可跳跃的时间）
@export var coyote_time: float = 0.2
## 跳跃缓冲时间（提前按跳跃的有效时间）
@export var jump_buffer_time: float = 0.15
## 触发落地抖动的最小DOWN状态持续时间
@export var land_shake_min_down_time: float = 0.9

## 滑翔设置
@export_category("滑翔设置")
## 进入滑翔的初始水平速度
@export var glide_init_h_speed: float = 0.0
## 滑翔目标水平速度
@export var glide_target_h_speed: float = 160.0
## 滑翔水平加速度（按住方向键时每秒逼近目标水平速度的最大变化率，单位近似 px/s^2）
@export var glide_horizontal_acceleration: float = 500.0
## 滑翔松开方向键时的水平减速（松手后的缓慢衰减速率）
@export var glide_release_deceleration: float = 80.0
## 滑翔最大下落速度乘数
@export var glide_max_fall_multiplier: float = 0.25
## 进入滑翔后的滞空时间（秒）- 期间下落速度上限为 0
@export var glide_hover_time: float = 0.3
## 滑翔下落倍率过渡时间（秒）- 进入滑翔后线性增加
@export var glide_fall_accel_time: float = 0.9

## 受伤设置
@export_category("受伤设置")
## 受伤击退速度
@export var hurt_knockback_speed: float = 100.0
## 受伤僵直时间（秒）
@export var hurt_stun_time: float = 0.5
## 受伤无敌时间（秒）
@export var hurt_invincible_time: float = 1.5
## 进入游戏开始时的禁用时间（秒）
@export var warp_control_lock_time: float = 1.0
## 传送伤害飞行峰值速度（像素/秒）
@export var warp_flight_peak_speed: float = 900.0
## 传送伤害飞行最低速度（像素/秒）
@export var warp_flight_min_speed: float = 50.0
## 传送伤害飞行第一段上升距离（像素）
@export var warp_flight_lift_distance: float = 60.0
## 传送伤害飞行第一段上升速度（像素/秒）
@export var warp_flight_lift_speed: float = 150.0
## 传送伤害分段停滞时间（秒）
@export var warp_flight_phase_pause_time: float = 0.5
## 传送伤害飞行目标点向上偏移（像素）
@export var warp_flight_target_height_offset: float = 50.0
## 传送伤害飞行抵达判定距离（像素）
@export var warp_flight_arrive_epsilon: float = 2.0

## 死亡设置
@export_category("死亡设置")
## 死亡动画持续时间（秒）
@export var die_animation_time: float = 1.5
## 重生后禁用时间（秒）
@export var respawn_invincible_time: float = 1.0
## 传送渐黑渐显持续时间（秒）
@export var fade_transition_time: float = 1.5
## 死亡慢动作时间（秒）
@export var slowly_die_time: float = 1

## 冲刺设置
@export_category("冲刺设置")
## 冲刺速度
@export var dash_speed: float = 450.0
## 冲刺持续时间（秒）
@export var dash_duration: float = 0.18
## 黑色冲刺持续时间（秒）
@export var black_dash_duration: float = 0.21
## 冲刺冷却时间（秒）
@export var dash_cooldown: float = 0.6
## 冲刺后惯性初速度
@export var dash_inertia_speed: float = 100.0
## 冲刺后惯性衰减系数 (0-1，越大衰减越快)
@export var dash_inertia_decay: float = 0.8

@export_category("超级冲刺设置")
## 超级冲刺充电时间（秒）
@export var super_dash_charge_time: float = 1.5
## 超级冲刺目标速度
@export var super_dash_speed: float = 550
## 超级冲刺加速时间（秒）
@export var super_dash_accel_time: float = 0.5
## 超级冲刺输入锁定时间（秒）
@export var super_dash_input_lock_time: float = 0.2
## 超级冲刺最大持续时间（秒）
@export var super_dash_max_duration: float = 5

## 奔跑设置
@export_category("奔跑设置")
## 快速按键时间窗口（秒）
@export var quick_tap_time_window: float = 0.3
## 撞墙反弹的X轴速度
@export var wall_bump_rebound_x: float = 180.0
## 撞墙反弹的Y轴速度  
@export var wall_bump_rebound_y: float = -130.0

## 奔跑跳跃设置
@export_category("奔跑跳跃设置")
## 奔跑跳跃水平速度加成
@export var run_jump_boost_speed: float = 140.0
## 奔跑跳跃加成持续时间（秒）
@export var run_jump_boost_duration: float = 0.5
## 奔跑跳跃衰减时间（秒）
@export var run_jump_decay_time: float = 0.3

## 二段跳旋转设置
@export_category("二段跳旋转设置")
## 二段跳旋转速度（度/秒）
@export var jump2_rotation_speed: float = 1080.0

@export_category("二段跳残影特殊效果设置")
## 水平速度加成（增加到基础移动速度上）
@export var jump2_horizontal_boost: float = 260.0
## 水平速度加成持续时间（秒）
@export var jump2_boost_duration: float = 0.5
## 水平速度加成减少过渡时间（秒）
@export var jump2_boost_decrease_time: float = 0.4
## 打断 JumpBox 持续二段跳后的垂直速度衰减时间（秒）
@export var jump2_interrupt_decay_time: float = 0.1
## JumpBox 重新触发锁定时间（毫秒）
@export var jumpbox_retrigger_lock_ms: int = 120
## JumpBox 单次触发的最大上抛力（像素/秒）
@export var jumpbox_max_vertical_force: float = 700.0
## JumpBox 水平速度上限（像素/秒）
@export var jumpbox_max_horizontal_speed: float = 420.0

@export_category("调试")
## 记录受伤后相机跳位相关状态
@export var camera_damage_debug: bool = false

@export_category("攀墙设置")
## 攀墙下滑速度（像素/秒）
@export var wall_slide_speed: float = 160.0
## 攀墙缓慢下滑速度（像素/秒）
@export var wall_slide_slow_speed: float = 30.0
## 按住向墙方向键的静止时间（秒）
@export var hold_toward_wall_time: float = 0.3
## 不按方向键的过渡时间（秒）  
@export var no_input_time: float = 0.8
## 攀墙反方向跳跃缓冲时间（秒）
@export var wall_grip_reverse_buffer_time: float = 0.25

@export_category("墙跳设置")
## 墙跳水平初速度（离开墙体的水平速度）
@export var wall_jump_h_speed: float = 360.0
## 墙跳垂直速度
@export var wall_jump_v_speed: float = -140.0
## 墙跳后重新附着延迟（秒）
@export var wall_jump_reattach_delay: float = 0.24
## 墙跳最大按住时间（秒）
@export var wall_jump_max_hold_time: float = 0.23
## 墙跳额外垂直速度（长按期间每帧增加）
@export var wall_jump_hold_boost: float = -60.0

@export_category("特殊状态设置")
## IDLE状态进入SLEEP状态的时间（秒）
@export var idle_to_sleep_time: float = 8.0
## IDLE状态进入LOOKUP/LOOKDOWN状态的时间（秒）
@export var idle_to_look_time: float = 0.8
## LOOKUP状态相机向上偏移距离
@export var lookup_camera_offset: float = 140.0
## LOOKDOWN状态相机向下偏移距离
@export var lookdown_camera_offset: float = 140.0

@export_category("相机观察设置")
## 相机偏移过渡时间（秒）
@export var camera_offset_transition_duration: float = 0.4
## 相机观察加速阶段占比（其余阶段为匀速），取值越大加速阶段越长
@export var camera_offset_accel_ratio: float = 0.1

@export_category("Hit Stop 设置")
## 是否启用Hit Stop
@export var hit_stop_enabled: bool = true

#endregion

##内部变量
#region Signals

## PlayerUI引用
var player_ui: CanvasLayer                      # 玩家UI的引用，用于更新血量、钱币等UI元素

## 动画管理相关
var current_animation: String = ""              # 当前播放的动画名称，用于防止重复播放同一动画

## 状态变量相关
var current_state: PlayerState = PlayerState.IDLE  # 玩家的当前状态（如站立、移动、跳跃等）
var is_facing_right: bool = true                # 标记玩家是否面朝右侧（用于控制朝向和动画翻转）

## 环境变量（由 EnvironmentManager 设置）
var env_horizontal_multiplier: float = 1.0      # 环境水平速度乘数
var env_vertical_multiplier: float = 1.0        # 环境垂直速度乘数
var env_gravity_multiplier: float = 1.0         # 环境重力乘数
var env_max_fall_multiplier: float = 1.0        # 环境最大下落速度乘数
var env_acceleration_multiplier: float = 1.0    # 环境加速度乘数

## 综合乘数（运行时自动计算）
var effective_horizontal_multiplier: float = 1.0      # 实际水平速度乘数 = global × env
var effective_vertical_multiplier: float = 1.0        # 实际垂直速度乘数 = global × env
var effective_gravity_multiplier: float = 1.0         # 实际重力乘数 = global × env
var effective_max_fall_multiplier: float = 1.0        # 实际最大下落速度乘数 = global × env
var effective_acceleration_multiplier: float = 1.0    # 实际加速度乘数 = global × env
var effective_max_fall_speed: float = 400.0           # 实际最大下落速度 = 基础值 × JumpBox × 环境

## 跳跃相关
var is_jumping: bool = false                    # 标记是否正在跳跃过程中
var jump_hold_timer: float = 0.0                # 跳跃键按住计时器，用于长按跳跃
var jump_count: int = 0                         # 跳跃次数计数
var has_double_jumped: bool = false             # 标记是否已经使用了二段跳
var can_double_jump: bool = false               # 标记当前是否可以执行二段跳
var last_double_jump_started_time_ms: int = -1000000

## 落地抖动相关
var down_state_entry_time: float = 0.0          # 记录进入DOWN状态的时间（基于游戏时间）
var is_game_paused: bool = false                # 标记游戏是否暂停
var last_delta_time: float = 0.0                # 上次的delta时间

## 补偿跳跃相关
var can_compensation_jump: bool = false         # 标记是否可以执行补偿跳跃（离开平台后的特殊跳跃）
var compensation_jump_used: bool = false        # 标记是否已经使用了补偿跳跃

## 土狼时间相关
var coyote_time_active: bool = false            # 标记土狼时间是否激活（离开平台后仍可跳跃的时间）
var was_on_floor: bool = true                   # 上一帧是否在地面上，用于检测地面状态变化

## 滑翔相关
var is_gliding: bool = false                    # 标记是否正在滑翔
var glide_timer: float = 0.0                    # 滑翔计时器，用于控制滑翔速度变化
var glide_direction: int = 1                    # 滑翔方向（1=右，-1=左）
var can_glide: bool = false                     # 标记当前是否可以进入滑翔状态
var is_double_jump_holding: bool = false        # 标记是否正在按住二段跳（影响滑翔触发）
var was_gliding_before_dash: bool = false       # 标记冲刺前是否在滑翔状态

## 受伤相关
var is_invincible: bool = false                 # 标记是否处于无敌状态
var hurt_timer: float = 0.0                     # 受伤僵直计时器
var invincible_timer: float = 0.0               # 无敌状态计时器
var hurt_direction: Vector2 = Vector2.ZERO      # 受伤击退方向
var is_warp_damage: bool = false                # 标记是否为传送伤害
var warp_precomputed_target_position: Vector2 = Vector2.ZERO  # 传送伤害预计算相机/传送目标
var warp_flight_active: bool = false            # 传送伤害飞行是否激活
var warp_flight_target_position: Vector2 = Vector2.ZERO  # 传送伤害飞行目标点
var warp_flight_target_source: String = "unknown"      # 目标点来源
var warp_flight_prev_collision_layer: int = 0   # 飞行前碰撞层备份
var warp_flight_prev_collision_mask: int = 0    # 飞行前碰撞掩码备份
var warp_flight_collision_backup_valid: bool = false  # 飞行前碰撞备份是否有效
var warp_flight_phase: int = 0                  # 飞行阶段：0上升 1停滞 2巡航 3停滞
var warp_flight_phase_timer: float = 0.0        # 分段停滞计时器
var warp_flight_lift_target_position: Vector2 = Vector2.ZERO  # 第一段上升目标点
var warp_flight_hover_target_position: Vector2 = Vector2.ZERO # 巡航目标点（检查点上方）
var is_about_to_be_hurt: bool = false           # 标记即将受到伤害

## 死亡重生相关
var is_dying: bool = false                      # 标记是否正在死亡过程中
var die_timer: float = 0.0                      # 死亡动画计时器
var is_in_death_process: bool = false           # 标记是否处于死亡流程中
var die_slow_motion_timer: Timer                # 死亡慢动作计时器引用
var die_slow_motion_active: bool = false        # 标记死亡慢动作是否激活
var is_respawn_invincible: bool = false         # 标记是否为重生无敌（不显示半透明）

## 内部禁用时间变量
var door_teleport_lock_time: float = 0.5        # 门传送后禁用时间（内部变量，由Door设置）
var control_lock_timer: float = 0.0             # 控制锁定计时器
var is_control_locked: bool = false             # 标记玩家控制是否被锁定
var door_autowalk_active: bool = false          # Door 传送后的自动走位是否激活
var door_autowalk_target_position: Vector2 = Vector2.ZERO  # Door 自动走位目标点
var door_autowalk_timeout: float = 0.0          # Door 自动走位超时时间
var door_autowalk_facing_right: bool = true     # 进入 Door 时的朝向
var door_autowalk_jump_used: bool = false       # Door 自动走位过程中是否已触发跳跃

## 奔跑检测相关
var last_move_input_time: float = 0.0           # 记录最后移动输入时间，用于快速双击检测
var move_input_count: int = 0                   # 移动输入计数
var last_move_direction: int = 0                # 最后移动方向（1=右，-1=左）
var is_run_ready: bool = false                  # 是否已准备好进入奔跑状态
var run_direction: int = 0                      # 奔跑方向
var is_running: bool = false                    # 当前是否正在奔跑
var was_running_before_coyote: bool = false     # 土狼时间前是否在奔跑状态

## 奔跑跳跃相关
var is_run_jumping: bool = false                # 标记是否正在进行奔跑跳跃
var run_jump_timer: float = 0.0                 # 奔跑跳跃速度加成计时器
var run_jump_original_direction: int = 0        # 奔跑跳跃原始方向
var is_wall_bump_stun: bool = false             # 标记是否处于撞墙僵直状态

## 冲刺相关
var can_dash: bool = true                       # 标记当前是否可以冲刺
var has_dashed_in_air: bool = false             # 标记是否已在空中冲刺过
var dash_duration_timer: float = 0.0            # 冲刺持续时间计时器
var dash_cooldown_timer: float = 0.0            # 冲刺冷却计时器

## 超级冲刺相关
var super_dash_charge_timer: float = 0.0        # 超级冲刺充电计时器
var super_dash_accel_timer: float = 0.0         # 超级冲刺加速计时器
var super_dash_input_lock_timer: float = 0.0    # 超级冲刺输入锁定计时器
var super_dash_afterimage_timer: float = 0.0    # 超级冲刺残影生成计时器
var super_dash_duration_timer: float = 0.0      # 超级冲刺持续时间计时器
var is_super_dash_charging: bool = false        # 标记是否正在为超级冲刺充电
var is_in_special_state = false                 # 标记是否处于特殊状态（用于禁用交互）

## 攀墙相关
var is_touching_wall: bool = false              # 标记是否接触到墙壁
var wall_direction: int = 0                     # 墙壁方向（1=右，-1=左）
var current_wall_slide_speed: float = 0.0       # 当前墙壁下滑速度
var wall_grip_reverse_timer_node: Timer         # 反方向跳跃缓冲计时器
var hold_toward_wall_timer: float = 0.0         # 按住向墙方向键的计时器
var no_input_timer: float = 0.0                 # 不按方向键的计时器

## 墙跳相关
var wall_jump_timer: float = 0.0                # 墙跳状态计时器
var can_reattach_to_wall: bool = true           # 标记是否可以重新附着到墙壁
var wall_jump_hold_timer: float = 0.0           # 墙跳按住计时器

## 特殊状态变量相关
var sleep_timer: float = 0.0                    # 进入睡眠状态的计时器
var look_timer: float = 0.0                     # 进入观察状态的计时器
var is_pressing_up: bool = false                # 标记是否按下上方向键
var is_pressing_down: bool = false              # 标记是否按下下方向键
var camera_observe_target_offset: Vector2 = Vector2.ZERO  # 当前观察偏移目标
var camera_observe_current_speed: float = 0.0   # 观察偏移当前速度（像素/秒）
var camera_observe_profile_max_speed: float = 0.0  # 当前段观察偏移最大速度（像素/秒）
var camera_observe_profile_acceleration: float = 0.0  # 当前段观察偏移加速度（像素/秒^2）
var camera_observe_profile_accel_time: float = 0.0  # 当前段观察偏移加速持续时间（秒）
var camera_observe_profile_elapsed: float = 0.0  # 当前段观察偏移已运行时间（秒）
var camera_observe_profile_start_offset: Vector2 = Vector2.ZERO  # 当前段观察偏移起点
var camera_observe_profile_distance: float = 0.0  # 当前段观察偏移总路程
var camera_observe_profile_direction: Vector2 = Vector2.ZERO  # 当前段观察偏移方向
var camera_observe_dead_zone_active: bool = false  # 观察偏移期间是否已接管 dead zone
var camera_observe_dead_zone_backup: Vector2 = Vector2.ZERO  # 观察偏移接管前 dead zone 备份
var camera_observe_zero_finalize_done: bool = true  # 回零收尾同步是否已执行（防止每帧重复同步）
var camera_observe_reset_phase: bool = false  # 当前观察轨迹是否为回零阶段（请求偏移为0）
var camera_observe_baseline_offset: Vector2 = Vector2.ZERO  # 观察开始前 follow_offset 基准
var camera_observe_baseline_valid: bool = false  # 观察基准是否有效
var camera_observe_baseline_center: Vector2 = Vector2.ZERO  # 观察开始前相机中心基准
var camera_observe_baseline_center_valid: bool = false  # 相机中心基准是否有效
var camera_observe_restore_wait_dead_zone: bool = false  # 回零后等待中心回基准再恢复死区
var camera_observe_restore_wait_timer: float = 0.0  # 回零后等待计时

## 残影相关
var afterimage_timer: float = 0.0               # 残影生成计时器
var afterimage_spawn_rate: float = 1.0          # 残影生成频率倍率
var afterimage_trail: Node = null
var feedback_hooks: Dictionary = {}

## JumpBox 残影独立管理
var has_jumpbox_afterimage: bool = false        # 标记是否激活了JumpBox残影效果
var jump2_afterimage_timer: float = 0.0         # 二段跳残影生成计时器
var jump2_rotation: float = 0.0                 # 二段跳旋转角度累计值
var is_jump2_boost_active: bool = false         # 标记是否激活了二段跳速度加成
var jump2_boost_timer: float = 0.0              # 二段跳速度加成计时器
var jump2_boost_direction: int = 1              # 二段跳速度加成的方向（1右，-1左）
var is_jumpbox_triggered: bool = false          # 标记是否触发了JumpBox效果
var jumpbox_force_applied: bool = false         # 标记是否已经应用了JumpBox的弹跳力
var jumpbox_last_bounce_time_ms: int = -1000000 # 上次接收 JumpBox 弹跳的时间戳（毫秒）
var jump2_boost_initial_speed: float = 0.0      # 二段跳速度加成的初始速度值
var jump2_boost_target_speed: float = 0.0       # 二段跳速度加成衰减后的目标速度值
var jumpbox_trigger_grade: String = "normal"   # 当前JumpBox触发等级（normal/perfect）
var jumpbox_afterimage_type: String = "jumpbox_perfect"
var jumpbox_horizontal_boost_multiplier: float = 1.0
var jumpbox_boost_duration_multiplier: float = 1.0
var jumpbox_max_vertical_force_multiplier: float = 1.0

## JumpBox持续二段跳打断相关
var is_jumpbox_continuous_jump: bool = false    # 标记是否处于JumpBox触发的持续二段跳状态
var is_jump_interrupt_decaying: bool = false    # 标记是否正在衰减
var jump_interrupt_decay_timer: float = 0.0     # 打断后的衰减计时器
## 是否允许打断 JumpBox 持续二段跳（内部变量，游戏设计选项）
var jump2_interrupt_enabled: bool = true        # true=可以打断，false=必须等到自然结束

## 跳跃缓冲相关
var jump_buffer_after_dash: bool = false         # 标记冲刺后是否有跳跃缓冲（用于处理冲刺后的跳跃衔接）
var jump_buffer_type: int = 0                    # 0=无, 1=一段跳, 2=二段跳

## 对话相关
var is_in_dialogue: bool = false                 # 标记玩家是否处于对话状态中

## 能力解锁状态相关
var dash_unlocked: bool = false                  # 标记基础冲刺能力是否已解锁
var double_jump_unlocked: bool = false           # 标记二段跳能力是否已解锁
var glide_unlocked: bool = false                 # 标记滑翔能力是否已解锁
var black_dash_unlocked: bool = false            # 标记强化冲刺能力是否已解锁
var wall_grip_unlocked: bool = false             # 标记攀墙能力是否已解锁
var super_dash_unlocked: bool = false            # 标记超级冲刺能力是否已解锁

## 计时器引用相关
var coyote_timer: Timer                          # 土狼时间计时器，用于检测离开平台后的可跳跃时间
var jump_buffer_timer: Timer                     # 跳跃缓冲计时器，用于处理提前按跳跃键的情况
var dash_duration_timer_node: Timer              # 冲刺持续时间计时器，控制冲刺的时长
var dash_cooldown_timer_node: Timer              # 冲刺冷却计时器，控制冲刺的冷却时间

## Hit Stop 相关
var is_hit_stop: bool = false                    # 标记是否处于Hit Stop状态（时间暂停）
var saved_time_scale: float = 1.0                # 保存的原始时间缩放，用于Hit Stop后恢复

##视觉效果相关
var vignette_effect: Node = null                 # Vignette效果引用
var is_low_health_effect_active: bool = false    # 标记低血量视觉效果是否激活
var low_health_tween: Tween                      # 低血量效果的Tween动画实例
var canvas_original_color: Color = Color.WHITE   # 画布原始颜色，用于效果后恢复
var is_hurt_visual_active: bool = false          # 标记受伤视觉效果是否激活
var hurt_visual_timer: float = 0.0               # 受伤视觉效果计时器
var camera_damage_debug_last_log_ms: int = -1000000  # 相机伤害调试日志节流时间戳

#endregion

##初始化相关函数集
#region Signals
## 场景初始化，设置玩家节点、能力状态、计时器和各种效果引用
func _ready():
	# 确保在 "player" 组中
	if not is_in_group("player"):
		add_to_group("player")
	
	# 从Global初始化能力状态 - 这是关键修复！
	dash_unlocked = Global.unlocked_abilities.get("dash", false)
	double_jump_unlocked = Global.unlocked_abilities.get("double_jump", false)
	glide_unlocked = Global.unlocked_abilities.get("glide", false)
	black_dash_unlocked = Global.unlocked_abilities.get("black_dash", false)
	wall_grip_unlocked = Global.unlocked_abilities.get("wall_grip", false)
	super_dash_unlocked = Global.unlocked_abilities.get("super_dash", false)
	
	if camera_controller and camera_controller.has_method("setup"):
		camera_controller.call_deferred("setup", self)
	if fx_controller and fx_controller.has_method("setup"):
		fx_controller.call_deferred("setup", self)
	
	# 查找VignetteEffect
	find_vignette_effect()
	
	# 初始化计时器
	initialize_timers()
	
	# 初始化墙体检测
	initialize_wall_detection()
	
	call_deferred("initialize_player_ui")
	
	initialize_afterimage_pool()
	
	DialogueSystem.dialogue_started.connect(_on_dialogue_started)
	DialogueSystem.dialogue_ended.connect(_on_dialogue_ended)
	
	# 连接RoomManager的低血量效果设置
	if RoomManager.has_method("set_low_health_effect"):
		print("Player: 已连接RoomManager颜色管理")
	
	# 连接能力解锁信号
	if EventBus and EventBus.instance:
		# 修复重复连接问题
		if EventBus.instance.dash_unlocked.is_connected(_on_dash_unlocked):
			EventBus.instance.dash_unlocked.disconnect(_on_dash_unlocked)
		EventBus.instance.dash_unlocked.connect(_on_dash_unlocked)
		
		if EventBus.instance.double_jump_unlocked.is_connected(_on_double_jump_unlocked):
			EventBus.instance.double_jump_unlocked.disconnect(_on_double_jump_unlocked)
		EventBus.instance.double_jump_unlocked.connect(_on_double_jump_unlocked)
		
		if EventBus.instance.glide_unlocked.is_connected(_on_glide_unlocked):
			EventBus.instance.glide_unlocked.disconnect(_on_glide_unlocked)
		EventBus.instance.glide_unlocked.connect(_on_glide_unlocked)
		
		if EventBus.instance.black_dash_unlocked.is_connected(_on_black_dash_unlocked):
			EventBus.instance.black_dash_unlocked.disconnect(_on_black_dash_unlocked)
		EventBus.instance.black_dash_unlocked.connect(_on_black_dash_unlocked)
		
		if EventBus.instance.super_dash_unlocked.is_connected(_on_super_dash_unlocked):
			EventBus.instance.super_dash_unlocked.disconnect(_on_super_dash_unlocked)
		EventBus.instance.super_dash_unlocked.connect(_on_super_dash_unlocked)
		
		if EventBus.instance.wall_grip_unlocked.is_connected(_on_wall_grip_unlocked):
			EventBus.instance.wall_grip_unlocked.disconnect(_on_wall_grip_unlocked)
		EventBus.instance.wall_grip_unlocked.connect(_on_wall_grip_unlocked)

## 初始化所有计时器节点，包括土狼时间、跳跃缓冲、冲刺等计时器
func initialize_timers():
	# 土狼时间计时器
	coyote_timer = Timer.new()
	coyote_timer.name = "CoyoteTimer"
	coyote_timer.one_shot = true
	timers.add_child(coyote_timer)
	coyote_timer.timeout.connect(_on_coyote_timeout)
	
	# 跳跃缓冲计时器
	jump_buffer_timer = Timer.new()
	jump_buffer_timer.name = "JumpBufferTimer"
	jump_buffer_timer.one_shot = true
	timers.add_child(jump_buffer_timer)
	jump_buffer_timer.timeout.connect(_on_jump_buffer_timeout)
	
	# 冲刺持续时间计时器
	dash_duration_timer_node = Timer.new()
	dash_duration_timer_node.name = "DashDurationTimer"
	dash_duration_timer_node.one_shot = true
	timers.add_child(dash_duration_timer_node)
	dash_duration_timer_node.timeout.connect(_on_dash_duration_timeout)
	
	# 冲刺冷却计时器
	dash_cooldown_timer_node = Timer.new()
	dash_cooldown_timer_node.name = "DashCooldownTimer"
	dash_cooldown_timer_node.one_shot = true
	timers.add_child(dash_cooldown_timer_node)
	dash_cooldown_timer_node.timeout.connect(_on_dash_cooldown_timeout)
	
	# 攀墙反方向跳跃缓冲计时器
	wall_grip_reverse_timer_node = Timer.new()
	wall_grip_reverse_timer_node.name = "WallGripReverseTimer"
	wall_grip_reverse_timer_node.one_shot = true
	timers.add_child(wall_grip_reverse_timer_node)
	wall_grip_reverse_timer_node.timeout.connect(_on_wall_grip_reverse_timeout)

## 初始化玩家UI引用，连接相关信号
func initialize_player_ui():
	var ui_nodes = get_tree().get_nodes_in_group("player_ui")
	if ui_nodes.size() > 0:
		player_ui = ui_nodes[0]
	# 最终检查
	if player_ui:
		# 连接信号 - 修复重复连接问题
		if player_ui.has_signal("player_died"):
			# 先断开可能存在的连接
			if player_ui.player_died.is_connected(_on_player_died):
				player_ui.player_died.disconnect(_on_player_died)
			# 然后重新连接
			player_ui.player_died.connect(_on_player_died)
		else:
			print("警告: PlayerUI没有player_died信号")
	else:
		print("=== PlayerUI查找失败 ===")

## 初始化残影对象池，预创建一定数量的残影实例以提高性能
func initialize_afterimage_pool():
	_ensure_afterimage_trail()
	if afterimage_trail == null:
		push_error("[Player] 未找到本地 AfterimageTrail")

func _ensure_afterimage_trail():
	if is_instance_valid(afterimage_trail):
		return
	afterimage_trail = get_node_or_null("AfterimageTrail")
	if afterimage_trail == null:
		var trail_script = load("res://Scripts/Components/AfterimageTrail.gd")
		afterimage_trail = trail_script.new()
		afterimage_trail.name = "AfterimageTrail"
		add_child(afterimage_trail)
	_sync_afterimage_trail_config_defaults()

func _sync_afterimage_trail_config_defaults():
	# 本地组件参数直接由自身导出字段驱动；此处保留为后续可选初始化入口
	if afterimage_trail == null:
		return

func _get_afterimage_interval(type_name: String) -> float:
	if afterimage_trail != null and afterimage_trail.has_method("get_interval"):
		return afterimage_trail.get_interval(type_name)
	return 0.05

## 初始化墙体检测系统，配置左右墙体检测射线
func initialize_wall_detection():
	# 只需要配置基础墙体检测射线
	if left_wall_ray and right_wall_ray:
		left_wall_ray.enabled = true
		right_wall_ray.enabled = true
		# 删除厚度检测相关代码
		left_wall_ray.collision_mask = 1 << 2
		right_wall_ray.collision_mask = 1 << 2
#endregion

## 主物理处理函数：每帧调用，处理玩家所有物理逻辑、状态更新和输入响应
func _physics_process(delta):
	# 关键修复：限制最大 delta 值，确保不同帧率下行为一致
	var fixed_delta = min(delta, MAX_FRAME_TIME)
	if camera_controller and camera_controller.has_method("physics_process"):
		camera_controller.physics_process(fixed_delta)
	else:
		PlayerCameraBridgeServiceScript.update_camera_transition_guard(self, fixed_delta)
	PlayerCameraBridgeServiceScript.tick_observe_offset(self, fixed_delta)
	var pre_input_result := PlayerRuntimeFlowServiceScript.handle_pre_input_pipeline(self, fixed_delta)
	var previous_was_on_floor: bool = pre_input_result.get("previous_was_on_floor", was_on_floor)
	if pre_input_result.get("handled", false):
		return
	# ========== 阶段6：获取输入 ==========
	var input_snapshot := PlayerRuntimeFlowServiceScript.collect_input_snapshot(self)
	var move_input: float = input_snapshot.get("move_input", 0.0)
	var jump_just_pressed: bool = input_snapshot.get("jump_just_pressed", false)
	var jump_pressed: bool = input_snapshot.get("jump_pressed", false)
	var jump_just_released: bool = input_snapshot.get("jump_just_released", false)
	var dash_just_pressed: bool = input_snapshot.get("dash_just_pressed", false)
	# ========== 阶段7：物理状态更新 ==========
	# 更新墙体检测
	update_wall_detection()
	# 更新无敌状态计时
	PlayerRuntimeTickServiceScript.tick_invincible(self, fixed_delta)
	# 更新水中效果和乘数（新增）
	update_effective_multipliers()
	# ========== 阶段8：状态处理前的逻辑 ==========
	# 检测奔跑输入
	detect_run_input(move_input)
	# 处理撞墙僵直
	if is_wall_bump_stun:
		handle_wall_bump_stun(fixed_delta)
	# 处理二段跳水平速度加成
	handle_jump2_boost(fixed_delta)
	# 处理跳跃缓冲
	if jump_just_pressed:
		jump_buffer_timer.start(jump_buffer_time)
	# 处理 DOWN 状态时间累计（放在状态处理之前，游戏暂停时不累计）
	if current_state == PlayerState.DOWN and abs(velocity.y) >= abs(max_fall_speed * 0.9) and not is_game_paused:
			down_state_entry_time += fixed_delta
	# 处理特殊状态计时器（放在状态处理之前）
	handle_special_state_timers(fixed_delta, move_input)
	# ========== 阶段9：主状态处理 ==========
	handle_state(fixed_delta, move_input, jump_just_pressed, jump_pressed, jump_just_released, dash_just_pressed)
	# ========== 阶段10：状态处理后的逻辑 ==========
	# 处理奔跑跳跃
	handle_run_jump(fixed_delta)
	# 处理冲刺计时器
	handle_dash_timers(fixed_delta)
	# ========== 阶段11：物理模拟 ==========
	# 应用重力（除了冲刺和受伤状态）
	if current_state != PlayerState.DASH and current_state != PlayerState.HURT:
		apply_gravity(fixed_delta)
	# 移动玩家
	move_and_slide()
	PlayerRuntimeFlowServiceScript.finalize_post_physics(self, fixed_delta, move_input, previous_was_on_floor)

## 检测游戏暂停状态
func _check_game_pause_state():
	# 检查是否在对话中
	if is_in_dialogue:
		return true
	
	# 检查是否在GameSettingScene中
	var game_setting_nodes = get_tree().get_nodes_in_group("game_setting_scene")
	if game_setting_nodes.size() > 0:
		for node in game_setting_nodes:
			if node.visible:
				return true
	
	# 检查游戏是否暂停
	if get_tree().paused:
		return true
	
	return false

## 统一的计时器更新函数（自动处理暂停）
func update_timer_with_pause(timer_ref: float, fixed_delta: float, is_paused: bool = false) -> float:
	## 如果游戏暂停，不更新时间
	if is_paused:
		return timer_ref
	
	## 否则正常更新时间
	return timer_ref + fixed_delta

## 重力应用函数
func apply_gravity(fixed_delta):
	# 关键修复：攀墙状态下不应用重力
	if current_state == PlayerState.WALLGRIP:
		return
	# 滑翔起始滞空期间不施加重力，确保垂直速度保持为 0。
	if current_state == PlayerState.GLIDE and glide_timer <= glide_hover_time:
		velocity.y = min(velocity.y, 0.0)
		return
	
	# 关键：打断衰减期间也不应用重力
	if is_jump_interrupt_decaying:
		return
		
	# 修改：使用有效重力乘数
	velocity.y += gravity * effective_gravity_multiplier * fixed_delta
	velocity.y = min(velocity.y, effective_max_fall_speed)

##时间控制函数集
#region Signals
## 更新土狼时间状态，检测地面状态变化，重置跳跃相关状态
func update_coyote_time():
	# 检查是否刚刚离开平台
	if was_on_floor and !is_on_floor() and velocity.y >= 0 and !is_jumping:
		coyote_time_active = true
		coyote_timer.start(coyote_time)
		# 离开平台时允许补偿跳跃
		if !is_jumping:
			can_compensation_jump = true
			compensation_jump_used = false
	# 如果接触到地面，重置所有状态
	if is_on_floor():
		coyote_time_active = false
		has_double_jumped = false
		can_double_jump = false
		can_compensation_jump = false
		compensation_jump_used = false
		is_jumping = false
		is_run_jumping = false
		has_dashed_in_air = false
		can_glide = false
		is_double_jump_holding = false
		was_gliding_before_dash = false
		wall_grip_reverse_timer_node.stop()
		jump_buffer_after_dash = false
		jump_buffer_type = 0
	# 更新地面状态
	was_on_floor = is_on_floor()
## 处理特殊状态（睡眠、观察）的计时器，只在IDLE状态下更新
func handle_special_state_timers(fixed_delta, _move_input):
	PlayerSpecialStateTimerServiceScript.handle_special_state_timers(self, fixed_delta)
## 处理冲刺相关的计时器，包括冲刺持续时间和冷却时间
func handle_dash_timers(fixed_delta):
	PlayerMovementServiceScript.handle_dash_timers(self, fixed_delta)
#endregion

##角色状态函数集
#region Signals

func handle_state(fixed_delta, move_input, jump_just_pressed, jump_pressed, jump_just_released, dash_just_pressed):
	PlayerStateFlowServiceScript.handle_state(self, fixed_delta, move_input, jump_just_pressed, jump_pressed, jump_just_released, dash_just_pressed)

func change_state(new_state: PlayerState):
	# 如果状态相同，不进行切换
	if current_state == new_state:
		return
	PlayerStateTransitionServiceScript.apply_exit_state(self, int(current_state))
	
	# 关键新增：提供死亡状态检查方法（供 Door.gd 使用）
	if new_state == PlayerState.DIE:
		is_in_death_process = true
	
	# 状态进入逻辑
	var previous_state = current_state
	PlayerStateTransitionServiceScript.apply_enter_state(self, int(new_state), int(current_state))
	
	# 更新当前状态
	current_state = new_state
	trigger_feedback_event(&"state_changed", {
		"from": previous_state,
		"to": new_state
	})

## 检查玩家是否处于死亡状态（供 Door.gd 调用）
func is_in_death_state() -> bool:
	return current_state == PlayerState.DIE or is_in_death_process

#endregion

## 更新动画函数
func update_animation():
	PlayerAnimationServiceScript.update_animation(self)

## 受伤处理函数集
#region Signals

func take_damage(damage_source_position: Vector2, damage: int = 1, damage_type: int = 0, knockback_force: Vector2 = Vector2.ZERO):
	PlayerDamageOrchestratorServiceScript.take_damage(self, damage_source_position, damage, damage_type, knockback_force)

func take_damage_with_type(damage_source_position: Vector2, damage: int = 1, damage_type: DamageType = DamageType.NORMAL, knockback_force: Vector2 = Vector2.ZERO):
	PlayerDamageOrchestratorServiceScript.take_damage_with_type(self, damage_source_position, damage, int(damage_type), knockback_force)

## 传送后状态重置
func reset_after_warp():
	PlayerDamageOrchestratorServiceScript.reset_after_warp(self)
#endregion

## 死亡处理函数集
#region Signals

func _on_player_died():
	PlayerDeathFlowServiceScript.on_player_died(self)

func _start_async_death_process():
	await PlayerDeathFlowServiceScript.start_async_death_process(self)

func start_death_process():
	await PlayerDeathFlowServiceScript.start_death_process(self)

func reset_player_for_respawn():
	PlayerDeathFlowServiceScript.reset_player_for_respawn(self)

func start_die_slow_motion():
	# 使用 TimerControlManager 的 medium 档位
	TimerControlManager.slow_motion("medium")

#endregion

## 奔跑冲刺超级冲刺相关函数集
#region Signals

func detect_run_input(move_input):
	PlayerMovementServiceScript.detect_run_input(self, move_input)

func handle_wall_bump():
	PlayerMovementServiceScript.handle_wall_bump(self)

func handle_wall_bump_stun(fixed_delta):
	PlayerMovementServiceScript.handle_wall_bump_stun(self, fixed_delta)

func handle_run_jump(fixed_delta):
	PlayerMovementServiceScript.handle_run_jump(self, fixed_delta)

func try_dash(dash_just_pressed: bool) -> bool:
	return PlayerMovementServiceScript.try_dash(self, dash_just_pressed)

func start_super_dash():
	PlayerMovementServiceScript.start_super_dash(self)

#endregion

## 跳跃滑翔相关函数集
#region Signals
## 尝试执行一段跳跃（地面或土狼时间），返回是否成功执行
func try_jump(jump_just_pressed: bool) -> bool:
	return PlayerAirAbilityServiceScript.try_jump(self, jump_just_pressed)
## 尝试执行二段跳跃（空中，包括补偿跳跃），返回是否成功执行
func try_double_jump(jump_just_pressed: bool) -> bool:
	return PlayerAirAbilityServiceScript.try_double_jump(self, jump_just_pressed)
## 处理二段跳期间按住跳跃键时的角色旋转效果
func handle_jump2_rotation(fixed_delta):
	if warp_flight_active:
		return
	# 二段跳期间按住跳跃键保持旋转，但在冲刺、受伤或死亡时停止旋转
	if current_state != PlayerState.DASH and current_state != PlayerState.HURT and current_state != PlayerState.DIE and has_double_jumped and is_double_jump_holding:
		# 在二段跳状态下旋转角色
		jump2_rotation += jump2_rotation_speed * fixed_delta
		animated_sprite.rotation_degrees = fmod(jump2_rotation, 360)
	else:
		# 不在二段跳按住状态时重置旋转
		if animated_sprite.rotation_degrees != 0:
			animated_sprite.rotation_degrees = 0
			jump2_rotation = 0

func can_accept_jumpbox_bounce() -> bool:
	if is_dying or current_state == PlayerState.DIE:
		return false

	var now_ms = Time.get_ticks_msec()
	return now_ms - jumpbox_last_bounce_time_ms >= jumpbox_retrigger_lock_ms

func mark_double_jump_started() -> void:
	last_double_jump_started_time_ms = Time.get_ticks_msec()

func is_recent_double_jump_start(window_sec: float = 0.12) -> bool:
	var now_ms = Time.get_ticks_msec()
	return now_ms - last_double_jump_started_time_ms <= int(window_sec * 1000.0)

func _apply_jumpbox_horizontal_speed(base_speed: float, direction: int) -> void:
	PlayerAirAbilityServiceScript._apply_jumpbox_horizontal_speed(self, base_speed, direction)
## 由JumpBox触发的弹跳，进入持续二段跳状态并获得水平速度加成
func start_jumpbox_bounce(vertical_force: float, trigger_grade: String = "normal", effect_overrides: Dictionary = {}):
	PlayerAirAbilityServiceScript.start_jumpbox_bounce(self, vertical_force, trigger_grade, effect_overrides)
## 处理JumpBox触发的二段跳水平速度加成，包括持续和衰减阶段
func handle_jump2_boost(fixed_delta):
	PlayerAirAbilityServiceScript.handle_jump2_boost(self, fixed_delta)
## 开始打断JumpBox持续二段跳，进入垂直速度衰减状态
func start_jump_interrupt():
	PlayerAirAbilityServiceScript.start_jump_interrupt(self)
## 处理打断后的垂直速度衰减，在指定时间内将垂直速度降为0
func handle_jump_interrupt_decay(fixed_delta):
	PlayerAirAbilityServiceScript.handle_jump_interrupt_decay(self, fixed_delta)
## 在 JumpBox 二段跳结束时调用
func end_jumpbox_continuous_jump():
	PlayerAirAbilityServiceScript.end_jumpbox_continuous_jump(self)
## 清除JumpBox触发的所有效果（包括速度加成、残影、旋转等）
func clear_jumpbox_effect():
	PlayerAirAbilityServiceScript.clear_jumpbox_effect(self)
## 进入滑翔状态，需要满足二段跳后且滑翔能力解锁
func start_glide():
	PlayerAirAbilityServiceScript.start_glide(self)
## 退出滑翔状态，根据当前速度切换到跳跃或下落状态
func exit_glide():
	PlayerAirAbilityServiceScript.exit_glide(self)
## 处理角色落地逻辑，重置跳跃、滑翔、冲刺等状态
func handle_landing():
	PlayerAirStateServiceScript.apply_landing_state(self)
	
	# 检查是否在 DOWN 状态下落地且持续时间足够，使用累计的游戏时间而不是系统时间
	if current_state == PlayerState.DOWN:
		if down_state_entry_time >= land_shake_min_down_time:
			CameraShakeManager.shake("y_strong", phantom_camera)
	
	var move_input_ground = Input.get_axis("left", "right")
	if move_input_ground == 0:
		change_state(PlayerState.IDLE)
	else:
		if is_running:
			change_state(PlayerState.RUN)
		else:
			change_state(PlayerState.MOVE)
#endregion

##攀墙墙跳相关函数集
#region Signals
func start_normal_jump_from_wall():
	# 从墙上进行普通跳跃
	velocity.y = jump_velocity
	jump_hold_timer = 0.0
	PlayerAirStateServiceScript.apply_wall_jump_ready_state(self)
	
	# 退出攀墙状态
	exit_wallgrip()
	change_state(PlayerState.JUMP)

func start_wall_jump():
	velocity.y = wall_jump_v_speed
	velocity.x = wall_jump_h_speed * -wall_direction
	
	wall_jump_timer = 0.0
	wall_jump_hold_timer = 0.0
	can_reattach_to_wall = false
	
	# 重置跳跃状态
	PlayerAirStateServiceScript.apply_wall_jump_ready_state(self)
	
	change_state(PlayerState.WALLJUMP)

func update_wall_detection():
	is_touching_wall = false
	wall_direction = 0
	
	if !can_reattach_to_wall:
		return
	# 简化检测：只需要两个射线
	if left_wall_ray.is_colliding():
		is_touching_wall = true
		wall_direction = -1
	elif right_wall_ray.is_colliding():
		is_touching_wall = true
		wall_direction = 1

func start_wallgrip():
	if wall_grip_unlocked and is_touching_wall and !is_on_floor() and can_reattach_to_wall:
		# 停止反方向跳跃缓冲计时器
		wall_grip_reverse_timer_node.stop()
		# 进入攀墙时同步清理滑翔标记，防止状态残留阻塞后续转移。
		is_gliding = false
		glide_timer = 0.0
		# 立即切换状态和动画
		change_state(PlayerState.WALLGRIP)
		velocity.y = 0
		velocity.x = 0
		has_double_jumped = false
		can_double_jump = true
		has_dashed_in_air = false
		can_glide = false
		is_double_jump_holding = false
		was_gliding_before_dash = false

func exit_wallgrip():
	if current_state == PlayerState.WALLGRIP:
		if velocity.y >= 0:
			change_state(PlayerState.DOWN)
		else:
			change_state(PlayerState.JUMP)

#endregion

## 残影函数集
#region Signals
func handle_afterimages(fixed_delta):
	PlayerFeedbackServiceScript.handle_afterimages(self, fixed_delta)

func register_feedback_hook(event_name: StringName, callback: Callable) -> void:
	if not callback.is_valid():
		return
	if not feedback_hooks.has(event_name):
		feedback_hooks[event_name] = []
	var callbacks: Array = feedback_hooks[event_name]
	for existing in callbacks:
		if existing == callback:
			return
	callbacks.append(callback)
	feedback_hooks[event_name] = callbacks

func unregister_feedback_hook(event_name: StringName, callback: Callable) -> void:
	if not feedback_hooks.has(event_name):
		return
	var callbacks: Array = feedback_hooks[event_name]
	callbacks = callbacks.filter(func(existing): return existing != callback)
	if callbacks.is_empty():
		feedback_hooks.erase(event_name)
	else:
		feedback_hooks[event_name] = callbacks

func trigger_feedback_event(event_name: StringName, payload: Dictionary = {}) -> void:
	if not feedback_hooks.has(event_name):
		return
	for callback in feedback_hooks[event_name]:
		if callback is Callable and callback.is_valid():
			callback.call(payload)

func return_afterimage(afterimage: Node, _type_name: String = "dash"):
	if is_instance_valid(afterimage) and afterimage.has_method("return_to_pool"):
		afterimage.return_to_pool()

# 新增：根据状态判断残影类型
func _get_afterimage_type_name(state: PlayerState, is_jumpbox: bool = false) -> String:
	match state:
		PlayerState.DASH:
			return "dash"
		PlayerState.SUPERDASH:
			return "super_dash"
		PlayerState.JUMP:
			return jumpbox_afterimage_type if is_jumpbox else "dash"
		_:
			return "dash"

func create_afterimage(state: PlayerState, is_jumpbox: bool = false, custom_type: String = ""):
	if Engine.get_frames_per_second() < 45:
		return
	
	if afterimage_trail == null:
		_ensure_afterimage_trail()
	if afterimage_trail != null:
		_create_afterimage_new(state, is_jumpbox, custom_type)
		trigger_feedback_event(&"afterimage_spawned", {
			"state": state,
			"is_jumpbox": is_jumpbox,
			"custom_type": custom_type
		})
	else:
		push_warning("[Player] 残影系统不可用，跳过残影生成")

func _create_afterimage_new(state: PlayerState, is_jumpbox: bool = false, custom_type: String = ""):
	# ⭐ 确定类型（支持自定义类型）
	var type_name = custom_type if custom_type != "" else _get_afterimage_type_name(state, is_jumpbox)
	
	# ⭐ 关键修复：严格控制残影生成位置（必须是 AnimatedSprite2D 位置）
	# ⭐ 额外验证：确保位置有效性
	var spawn_position = global_position
	if is_instance_valid(animated_sprite):
		spawn_position = animated_sprite.global_position
	else:
		push_warning("[Player] animated_sprite 节点无效，使用 Player 根节点位置")
	if not spawn_position.is_finite():
		spawn_position = global_position
	
	var current_texture = get_current_frame_texture()
	if not current_texture:
		push_error("[Player] 纹理为空！跳过生成")
		return
	
	# ⭐ 关键修复：计算残影移动方向和距离（统一：生成瞬间速度的反方向）
	var move_direction = Vector2.ZERO
	# ⭐ 获取玩家当前速度（用于计算残影方向）
	var player_velocity = get_velocity() if has_method("get_velocity") else Vector2.ZERO
	
	# ⭐ 统一规则：所有残影都沿当前速度的反方向漂移
	if player_velocity != Vector2.ZERO:
		move_direction = -player_velocity.normalized()
	else:
		move_direction = Vector2(-1 if is_facing_right else 1, 0)
	if not move_direction.is_finite() or move_direction.length_squared() < 0.0001:
		move_direction = Vector2(-1 if is_facing_right else 1, 0)
	
	# ⭐ 生成残影（传递移动参数）
	var afterimage = null
	if afterimage_trail != null and afterimage_trail.has_method("spawn"):
		afterimage = afterimage_trail.spawn(
			type_name,
			spawn_position,
			current_texture,
			animated_sprite.flip_h,
			Vector2.ONE * 0.8 if not is_jumpbox else Vector2.ONE,
			move_direction,
			-1.0,
			z_index
		)
	else:
		return
	
	if afterimage:
		afterimage.player_ref = self
		# ⭐ 关键修复：无需重复设置 Shader 参数（initialize 已设置）

func clear_jumpbox_afterimage_pool():
	# 本地池由 AfterimageTrail 统一管理，这里只重置状态标记。
	has_jumpbox_afterimage = false

func get_current_frame_texture() -> Texture2D:
	if animated_sprite.sprite_frames != null and animated_sprite.animation != "":
		var frame_count = animated_sprite.sprite_frames.get_frame_count(animated_sprite.animation)
		if frame_count > 0 and animated_sprite.frame < frame_count:
			return animated_sprite.sprite_frames.get_frame_texture(
				animated_sprite.animation, 
				animated_sprite.frame
			)
	return null

#endregion

##场景Timers节点回调函数集
#region Signals
func _on_coyote_timeout():
	coyote_time_active = false
	# 关键修复：土狼时间结束后，如果补偿跳跃还没有使用，强制设置为可用
	if !compensation_jump_used:
		can_compensation_jump = true

func _on_jump_buffer_timeout():
	pass

func _on_dash_duration_timeout():
	# 冲刺结束，检查是否有跳跃缓冲
	if jump_buffer_after_dash:
		jump_buffer_after_dash = false
		if jump_buffer_type == 1:
			try_jump(true)  # 执行一段跳
		elif jump_buffer_type == 2:
			try_double_jump(true)  # 执行二段跳
		return
	# 冲刺结束，恢复到之前的状态或下落状态
	if was_gliding_before_dash:
		# 如果冲刺前在滑翔，冲刺结束后应该回到下落状态
		was_gliding_before_dash = false
		# 重置二段跳按住状态，为可能的再次滑翔做准备
		is_double_jump_holding = false
		change_state(PlayerState.DOWN)
	elif is_on_floor() or coyote_time_active:
		var move_input = Input.get_axis("left", "right")
		if move_input == 0:
			change_state(PlayerState.IDLE)
		else:
			change_state(PlayerState.MOVE)
	else:
		if velocity.y < 0:
			change_state(PlayerState.JUMP)
		else:
			change_state(PlayerState.DOWN)

func _on_dash_cooldown_timeout():
	can_dash = true

func _on_wall_grip_reverse_timeout():
	pass

#endregion

##交互对话和锁定控制相关函数集
#region Signals

# 对话开始处理 
func _on_dialogue_started():
	PlayerDialogueStateServiceScript.on_dialogue_started(self)

# 对话期间处理
func handle_dialogue_physics(fixed_delta):
	PlayerDialogueStateServiceScript.handle_dialogue_physics(self, fixed_delta)

# 对话结束处理
func _on_dialogue_ended():
	await PlayerDialogueStateServiceScript.on_dialogue_ended(self)

# 锁定控制
func lock_control(duration: float, lock_type: String = "general"):
	PlayerControlLockServiceScript.lock_control(self, duration, lock_type)

#锁定控制回调
func _on_control_lock_timeout():
	PlayerControlLockServiceScript.unlock_control(self)

#endregion

##相机控制相关函数集
#region Signals
# 添加相机偏移函数
func reset_camera_position():
	PlayerCameraBridgeServiceScript.reset_camera_position(self)

func start_camera_transition_guard(duration: float = 0.18, max_duration: float = 1.0) -> void:
	PlayerCameraBridgeServiceScript.start_camera_transition_guard(self, duration, max_duration)

func _update_camera_transition_guard(fixed_delta: float) -> void:
	PlayerCameraBridgeServiceScript.update_camera_transition_guard(self, fixed_delta)


func sync_camera_after_room_teleport() -> void:
	PlayerRoomTransitionServiceScript.sync_camera_after_room_teleport(self)

## 门传送等瞬移后调用：同步 PhantomCamera2D 与 Camera2D，修复 FRAMED 死区与视口坐标一帧不一致
func sync_phantom_camera_after_teleport() -> void:
	PlayerRoomTransitionServiceScript.sync_phantom_camera_after_teleport(self)

## 强制同步相机位置到玩家位置，忽略限制用于传送后
func force_sync_camera_position_after_teleport() -> void:
	await PlayerRoomTransitionServiceScript.force_sync_camera_position_after_teleport(self)

## Door 传送测试路径：先解限再快速追镜，最后恢复目标房间限制。
func start_door_camera_catchup_after_teleport(catchup_duration: float = 0.20, unlock_duration: float = 0.32) -> void:
	PlayerRoomTransitionServiceScript.start_door_camera_catchup_after_teleport(self, catchup_duration, unlock_duration)

## Door 传送后的自动走位：锁定输入，只由脚本移动/跳跃到最近动态检查点。
func start_door_autowalk_to_dynamic_checkpoint(room_id: String, door_position: Vector2, facing_right: bool, allow_jump: bool = true, timeout: float = 1.4) -> bool:
	return PlayerRoomTransitionServiceScript.start_door_autowalk_to_dynamic_checkpoint(self, room_id, door_position, facing_right, allow_jump, timeout)

#endregion

##Hit Stop 相关函数集
#region Signals
# 受伤专用的Hit Stop
func start_hurt_hit_stop():
	PlayerHitStopServiceScript.start_hurt_hit_stop(self)

func _trigger_tier2_hit_stop_with_fallback(duration_fallback: float, intensity_fallback: float) -> void:
	PlayerHitStopServiceScript.trigger_tier2_with_fallback(self, duration_fallback, intensity_fallback)

func _trigger_tier3_hit_stop_with_fallback(duration_fallback: float, intensity_fallback: float) -> void:
	PlayerHitStopServiceScript.trigger_tier3_with_fallback(self, duration_fallback, intensity_fallback)

# JumpBox 专用的 Hit Stop（使用 tier2 档位）
func start_jumpbox_hit_stop(trigger_grade: String = "normal"):
	PlayerHitStopServiceScript.start_jumpbox_hit_stop(self, trigger_grade)

#endregion

##受伤与低血量视觉效果相关函数集
#region Signals

## 查找VignetteEffect节点
func find_vignette_effect():
	# 等待一帧确保所有节点都加载完成
	await get_tree().process_frame
	
	# 通过路径直接获取
	var vignette = get_node_or_null("/root/MainGameScene/VignetteEffect")
	if vignette:
		vignette_effect = vignette
	else:
		# 或者通过遍历子节点查找
		var main_scene = get_tree().current_scene
		if main_scene:
			for child in main_scene.get_children():
				if child.name == "VignetteEffect" or child.is_in_group("vignette_effect"):
					vignette_effect = child
					break
		if not vignette_effect:
			print("Player: 警告：未找到VignetteEffect节点")

## 开始普通受伤视觉效果
func start_normal_hurt_effect():
	start_hurt_hit_stop()
	start_vignette_hurt()
	CameraShakeManager.shake("general_weak", phantom_camera)

## 开始阴影受伤视觉效果
func start_shadow_hurt_effect():
	start_hurt_hit_stop()
	start_vignette_shadow_hurt()
	CameraShakeManager.shake("general_moderate", phantom_camera)

## 开始传送伤害视觉效果
func start_warp_hurt_effect(is_shadow: bool):
	start_hurt_hit_stop()
	if is_shadow:
		start_vignette_shadow_hurt()
	else:
		start_vignette_hurt()
	CameraShakeManager.shake("general_moderate", phantom_camera)

func _debug_camera_damage_state(stage: String, damage_source_position: Vector2, damage: int, damage_type: DamageType, knockback_force: Vector2) -> void:
	camera_damage_debug_last_log_ms = PlayerCameraDebugServiceScript.log_damage_state(
		self,
		stage,
		damage_source_position,
		damage,
		int(damage_type),
		knockback_force,
		camera_damage_debug_last_log_ms
	)

func _debug_camera_jumpbox_state(stage: String, trigger_grade: String, jumpbox_position: Vector2) -> void:
	PlayerCameraDebugServiceScript.log_jumpbox_state(self, stage, trigger_grade, jumpbox_position)

## 启动Vignette普通受伤效果
func start_vignette_hurt():
	if vignette_effect and vignette_effect.has_method("start_hurt_effect"):
		is_hurt_visual_active = true
		
		# 从VignetteEffect获取持续时间
		var duration = vignette_effect.hurt_darkness_duration
		vignette_effect.start_hurt_effect(duration)
		# 设置定时器，在受伤效果持续时间结束后处理
		get_tree().create_timer(duration).timeout.connect(
			func():
				# 清除即将受伤标记
				is_about_to_be_hurt = false
				_on_hurt_duration_end(false)
		)

## 启动Vignette阴影受伤效果
func start_vignette_shadow_hurt():
	if vignette_effect and vignette_effect.has_method("start_shadow_hurt_effect"):
		var duration = vignette_effect.hurt_shadow_darkness_duration
		vignette_effect.start_shadow_hurt_effect(duration)
		
		get_tree().create_timer(duration).timeout.connect(
			func():
				_on_hurt_duration_end(true)
		)

## 受伤效果持续时间结束后的处理
func _on_hurt_duration_end(_is_shadow_hurt: bool):
	if not vignette_effect:
		return
	# 检查血量状态
	if player_ui and player_ui.get_health() <= 1:
		# 血量≤1：从受伤效果过渡到低血量效果
		if vignette_effect.has_method("transition_hurt_to_low_health"):
			var transition_time = vignette_effect.hurt_to_low_health_transition
			
			# 关键修复：确保当前是受伤效果
			if vignette_effect.current_effect == "hurt":
				vignette_effect.transition_hurt_to_low_health(transition_time)
				is_low_health_effect_active = true
			else:
				_trigger_low_health_effect()
		else:
			# 回退到原来的方法
			if vignette_effect.has_method("transition_to_low_health"):
				var transition_time = vignette_effect.hurt_to_low_health_transition
				vignette_effect.transition_to_low_health(transition_time)
				is_low_health_effect_active = true
	else:
		# 血量>1：过渡到无效果
		if vignette_effect.has_method("transition_to_normal"):
			var transition_time = vignette_effect.hurt_to_normal_transition
			vignette_effect.transition_to_normal(transition_time)
	
	is_hurt_visual_active = false

## 触发低血量视觉效果
func _trigger_low_health_effect():
	if is_hurt_visual_active:
		# 如果正在显示受伤效果，等待受伤效果结束后再处理
		return
		
	if is_low_health_effect_active:
		return
	
	is_low_health_effect_active = true
	
	# 如果VignetteEffect已经有其他效果，先清除
	if vignette_effect and vignette_effect.has_method("clear_all_effects"):
		vignette_effect.clear_all_effects()
		await get_tree().process_frame
	
	# 开始低血量效果
	if vignette_effect and vignette_effect.has_method("start_low_health_effect"):
		vignette_effect.start_low_health_effect()

## 清除低血量视觉效果
func _clear_low_health_effect():
	if not is_low_health_effect_active:
		return
	
	is_low_health_effect_active = false
	
	if vignette_effect and vignette_effect.has_method("transition_low_health_to_normal"):
		var transition_time = vignette_effect.low_health_to_normal_transition
		vignette_effect.transition_low_health_to_normal(transition_time)

#endregion

##能力解锁相关函数集
#region Signals

func _on_dash_unlocked():
	dash_unlocked = true

func _on_double_jump_unlocked():
	double_jump_unlocked = true

func _on_glide_unlocked():
	glide_unlocked = true

func _on_black_dash_unlocked():  
	black_dash_unlocked = true

func _on_super_dash_unlocked():
	super_dash_unlocked = true

func _on_wall_grip_unlocked():
	wall_grip_unlocked = true

#endregion

## 公共方法接口函数集
#region Signals

## 由MainGameScene调用的设置函数
func set_canvas_original_color(color: Color):
	canvas_original_color = color
	canvas_modulate = get_tree().get_first_node_in_group("canvas_modulate")
	print("Player: CanvasModulate初始化完成，原始颜色:", canvas_original_color)

## 设置玩家状态（供外部调用）
func set_player_state(new_state: PlayerState) -> void:
	if new_state == PlayerState.SLEEP:
		velocity = Vector2.ZERO
	change_state(new_state)

## 获取当前状态
func get_player_state() -> PlayerState:
	return current_state

## 强制进入交互状态
func force_interactive_state() -> void:
	change_state(PlayerState.INTERACTIVE)

## 检查是否可被交互打断
func can_be_interrupted() -> bool:
	return current_state != PlayerState.DASH and current_state != PlayerState.HURT and current_state != PlayerState.DIE

## 获取能力解锁状态
func get_ability_status() -> Dictionary:
	return {
		"dash": dash_unlocked,
		"double_jump": double_jump_unlocked,
		"glide": glide_unlocked,
		"black_dash": black_dash_unlocked,
		"wall_grip": wall_grip_unlocked
	}

## 设置能力解锁状态（用于存档加载）
func set_abilities_from_save(abilities: Dictionary) -> void:
	dash_unlocked = abilities.get("dash", false)
	double_jump_unlocked = abilities.get("double_jump", false)
	glide_unlocked = abilities.get("glide", false)
	black_dash_unlocked = abilities.get("black_dash", false)
	wall_grip_unlocked = abilities.get("wall_grip", false)

## 进入睡眠状态（供外部调用）
func enter_sleep_state() -> void:
	velocity = Vector2.ZERO
	change_state(PlayerState.SLEEP)

## 退出睡眠状态（供外部调用）
func exit_sleep_state() -> void:
	if current_state == PlayerState.SLEEP:
		change_state(PlayerState.IDLE)

## 检查是否在睡眠状态
func is_sleeping() -> bool:
	return current_state == PlayerState.SLEEP

## 设置玩家控制状态
func set_player_control(enabled: bool) -> void:
	set_process_input(enabled)

## 立即传送到位置
func teleport_to(target_position: Vector2) -> void: 
	global_position = target_position
	velocity = Vector2.ZERO

## 由JumpBox调用的函数
func refresh_air_dash():
	has_dashed_in_air = false

## 由水面触碰触发的能力刷新（单次触碰只刷新一次）
func refresh_jump():
	# 重置跳跃次数，允许再次跳跃
	jump_count = 0

func refresh_dash():
	# 重置冲刺状态，允许再次冲刺
	can_dash = true
	has_dashed_in_air = false

## 更新所有有效乘数（在_physics_process 中调用）
func update_effective_multipliers():
	# 关键修复：先重置为默认值
	effective_horizontal_multiplier = env_horizontal_multiplier
	effective_vertical_multiplier = env_vertical_multiplier
	effective_gravity_multiplier = env_gravity_multiplier
	effective_max_fall_multiplier = env_max_fall_multiplier
	effective_acceleration_multiplier = env_acceleration_multiplier
	
	# 关键修复：最大下落速度直接使用基础值，不受 JumpBox 影响
	effective_max_fall_speed = max_fall_speed * effective_max_fall_multiplier

## 由 EnvironmentManager 调用，设置环境乘数
func set_environment_multipliers(horizontal: float, vertical: float, p_gravity: float, max_fall: float, acceleration: float):
	env_horizontal_multiplier = horizontal
	env_vertical_multiplier = vertical
	env_gravity_multiplier = p_gravity
	env_max_fall_multiplier = max_fall
	env_acceleration_multiplier = acceleration

## 更新低血量效果（供PlayerUI调用）
func update_low_health_effect():
	if not player_ui:
		return
	
	var current_health = player_ui.get_health()
	var is_low_health = current_health <= 1
	
	# 关键修复：如果即将受到伤害或正在受伤，推迟低血量效果的触发
	if is_about_to_be_hurt or is_hurt_visual_active:
		return
	
	if is_low_health and not is_low_health_effect_active:
		_trigger_low_health_effect()
	elif not is_low_health and is_low_health_effect_active:
		_clear_low_health_effect()

## 中断受伤视觉效果（供Door调用）
func interrupt_hurt_visual_effect():
	# 清除受伤视觉效果状态
	is_hurt_visual_active = false
	hurt_visual_timer = 0
	
	# 清除VignetteEffect中的所有效果
	if vignette_effect and vignette_effect.has_method("clear_all_effects"):
		vignette_effect.clear_all_effects()

## 只中断受伤视觉效果（不清除低血量效果）（供Door调用）
func interrupt_hurt_visual_only():
	# 只清除受伤效果相关状态
	is_hurt_visual_active = false
	hurt_visual_timer = 0
	
	# 如果VignetteEffect当前是受伤效果，清除它
	if vignette_effect and vignette_effect.has_method("clear_hurt_effect_only"):
		vignette_effect.clear_hurt_effect_only()

#endregion
