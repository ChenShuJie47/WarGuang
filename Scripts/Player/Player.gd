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

## 节点引用
@onready var right_wall_ray = $WallRays/RightWallRay
@onready var left_wall_ray = $WallRays/LeftWallRay
@onready var animated_sprite = $AnimatedSprite2D
@onready var phantom_camera = $PhantomCamera2D
@onready var point_light = $PointLight2D  
@onready var timers = $Timers
@onready var canvas_modulate = get_tree().get_first_node_in_group("canvas_modulate")

##外部变量
#region Signals

## 残影场景（在 Inspector 中拖拽 Afterimage.tscn）
@export var afterimage_scene: PackedScene

## 移动设置
@export_category("移动设置")
## 基础移动速度（像素/秒）
@export var base_move_speed: float = 110.0
## 奔跑移动速度（像素/秒）
@export var run_move_speed: float = 220.0
## 地面加速度 (0-1，越大加速越快)
@export var ground_acceleration: float = 0.6
## 地面减速度 (0-1，越大减速越快)
@export var ground_deceleration: float = 0.6
## 空中移动控制力 (0-1，越小控制力越弱)
@export var air_control: float = 0.28

## 跳跃设置
@export_category("跳跃设置")
## 跳跃移动速度（像素/秒）
@export var jump_move_speed: float = 120.0
## 一段跳初始速度
@export var jump_velocity: float = -160.0
## 二段跳初始速度
@export var double_jump_velocity: float = -130.0
## 最大跳跃按住时间（秒）
@export var max_jump_hold_time: float = 0.22
## 跳跃额外速度（长按期间每帧增加）
@export var jump_hold_boost: float = -30.0
## 重力
@export var gravity: float = 1300.0
## 最大下落速度
@export var max_fall_speed: float = 400.0
## 土狼时间（离开平台后仍可跳跃的时间）
@export var coyote_time: float = 0.2
## 跳跃缓冲时间（提前按跳跃的有效时间）
@export var jump_buffer_time: float = 0.15
## 触发落地抖动的最小DOWN状态持续时间
@export var land_shake_min_down_time: float = 1

## 滑翔设置
@export_category("滑翔设置")
## 进入滑翔的初始水平速度
@export var glide_init_h_speed: float = 30.0
## 滑翔目标水平速度
@export var glide_target_h_speed: float = 130.0
## 滑翔最大下落速度乘数
@export var glide_max_fall_multiplier: float = 0.25
## 滑翔加速时间（秒）- 控制从初始到目标下落速度的过渡时间
@export var glide_accel_time: float = 0.5

## 受伤设置
@export_category("受伤设置")
## 受伤击退速度
@export var hurt_knockback_speed: float = 200.0
## 受伤僵直时间（秒）
@export var hurt_stun_time: float = 0.5
## 受伤无敌时间（秒）
@export var hurt_invincible_time: float = 1.5
## 传送伤害僵直淡化时间
@export var warp_stun_and_teleport_time: float = 1 
## 传送伤害后禁用时间（秒）- 传送伤害后及存档进入游戏开始时的禁用时间
@export var warp_control_lock_time: float = 1
## 传送伤害后无敌时间（秒）
@export var warp_invincible_time: float = 1.5

## 死亡设置
@export_category("死亡设置")
## 死亡动画持续时间（秒）
@export var die_animation_time: float = 3.0
## 重生后禁用时间（秒）
@export var respawn_invincible_time: float = 2.0
## 传送渐黑渐显持续时间（秒）
@export var fade_transition_time: float = 1.5
## 死亡慢动作时间（秒）
@export var slowly_die_time: float = 1

## 冲刺设置
@export_category("冲刺设置")
## 冲刺速度
@export var dash_speed: float = 450.0
## 冲刺持续时间（秒）
@export var dash_duration: float = 0.2
## 黑色冲刺持续时间（秒）
@export var black_dash_duration: float = 0.22
## 冲刺冷却时间（秒）
@export var dash_cooldown: float = 0.5
## 冲刺后惯性初速度
@export var dash_inertia_speed: float = 125.0
## 冲刺后惯性衰减系数 (0-1，越大衰减越快)
@export var dash_inertia_decay: float = 0.8

@export_category("超级冲刺设置")
## 超级冲刺充电时间（秒）
@export var super_dash_charge_time: float = 1.5
## 超级冲刺目标速度
@export var super_dash_speed: float = 400
## 超级冲刺加速时间（秒）
@export var super_dash_accel_time: float = 0.2
## 超级冲刺输入锁定时间（秒）
@export var super_dash_input_lock_time: float = 0.2
## 超级冲刺最大持续时间（秒）
@export var super_dash_max_duration: float = 3.5

## 奔跑设置
@export_category("奔跑设置")
## 快速按键时间窗口（秒）
@export var quick_tap_time_window: float = 0.3
## 撞墙反弹的X轴速度
@export var wall_bump_rebound_x: float = 175.0
## 撞墙反弹的Y轴速度  
@export var wall_bump_rebound_y: float = -125.0

## 奔跑跳跃设置
@export_category("奔跑跳跃设置")
## 奔跑跳跃水平速度加成
@export var run_jump_boost_speed: float = 120.0
## 奔跑跳跃加成持续时间（秒）
@export var run_jump_boost_duration: float = 0.3
## 奔跑跳跃衰减时间（秒）
@export var run_jump_decay_time: float = 0.5

## 二段跳旋转设置
@export_category("二段跳旋转设置")
## 二段跳旋转速度（度/秒）
@export var jump2_rotation_speed: float = 1080.0

@export_category("二段跳残影特殊效果设置")
## 水平速度加成（增加到基础移动速度上）
@export var jump2_horizontal_boost: float = 250.0
## 水平速度加成持续时间（秒）
@export var jump2_boost_duration: float = 0.25
## 水平速度加成减少过渡时间（秒）
@export var jump2_boost_decrease_time: float = 0.4
## 打断 JumpBox 持续二段跳后的垂直速度衰减时间（秒）
@export var jump2_interrupt_decay_time: float = 0.1

@export_category("攀墙设置")
## 墙体检测距离（像素）
@export var wall_detection_distance: float = 15.0 #可能多余
## 攀墙下滑速度（像素/秒）
@export var wall_slide_speed: float = 120.0
## 攀墙缓慢下滑速度（像素/秒）
@export var wall_slide_slow_speed: float = 30.0
## 按住向墙方向键的静止时间（秒）
@export var hold_toward_wall_time: float = 0.4
## 不按方向键的过渡时间（秒）  
@export var no_input_time: float = 0.8
## 攀墙反方向跳跃缓冲时间（秒）
@export var wall_grip_reverse_buffer_time: float = 0.2

@export_category("墙跳设置")
## 墙跳水平初速度（离开墙体的水平速度）
@export var wall_jump_h_speed: float = 320.0
## 墙跳垂直速度
@export var wall_jump_v_speed: float = -150.0
## 墙跳后重新附着延迟（秒）
@export var wall_jump_reattach_delay: float = 0.2
## 墙跳最大按住时间（秒）
@export var wall_jump_max_hold_time: float = 0.24
## 墙跳额外垂直速度（长按期间每帧增加）
@export var wall_jump_hold_boost: float = -60.0

@export_category("特殊状态设置")
## IDLE状态进入SLEEP状态的时间（秒）
@export var idle_to_sleep_time: float = 8.0
## IDLE状态进入LOOKUP/LOOKDOWN状态的时间（秒）
@export var idle_to_look_time: float = 0.8
## LOOKUP状态相机向上偏移距离
@export var lookup_camera_offset: float = 180.0
## LOOKDOWN状态相机向下偏移距离
@export var lookdown_camera_offset: float = 210.0

@export_category("相机观察设置")
## 相机偏移过渡时间（秒）
@export var camera_offset_transition_duration: float = 0.2
## 相机偏移过渡类型：Tween.TransitionType
## - TRANS_LINEAR: 线性过渡（匀速）
## - TRANS_SINE: 正弦曲线（平滑波动）
## - TRANS_QUAD: 二次方（简单加速/减速）
## - TRANS_CUBIC: 三次方（更明显的加速/减速）
## - TRANS_QUART: 四次方
## - TRANS_QUINT: 五次方
## - TRANS_EXPO: 指数曲线（快速变化）
## - TRANS_CIRC: 圆形曲线
## - TRANS_BOUNCE: 弹跳效果（超过目标后反弹）
## - TRANS_BACK: 回弹效果（先反向移动再正向）
@export var camera_offset_transition_type: Tween.TransitionType = Tween.TRANS_LINEAR
## 相机偏移缓动类型：Tween.EaseType
## - EASE_IN: 开始慢，结束快（加速）
## - EASE_OUT: 开始快，结束慢（减速）
## - EASE_IN_OUT: 开始和结束都慢，中间快（先加速后减速）
## - EASE_OUT_IN: 开始和结束都快，中间慢（先减速后加速）
@export var camera_offset_ease_type: Tween.EaseType = Tween.EASE_OUT_IN

@export_category("残影全局设置")
## 残影统一缩放倍数
@export var afterimage_scale_multiplier: float = 1

# ==================== 残影配置（已迁移到 AfterimageTrail 组件） ====================
# - dash_afterimage_interval
# - dash_afterimage_lifetime
# - dash_afterimage_color
# - black_dash_afterimage_color
# - super_dash_afterimage_interval
# - super_dash_afterimage_lifetime
# - super_dash_afterimage_color
# - jump2_afterimage_interval
# - jump2_afterimage_lifetime
# - jump2_afterimage_color
# ====================================================================

@export_category("Hit Stop 设置")
## 是否启用Hit Stop
@export var hit_stop_enabled: bool = true
## 受伤Hit Stop设置
@export var hurt_hit_stop_duration: float = 0.1
@export var hurt_hit_stop_intensity: float = 1.2
## JumpBox Hit Stop设置
@export var jumpbox_hit_stop_duration: float = 0.25
@export var jumpbox_hit_stop_intensity: float = 0.8

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
var warp_damage_timer: float = 0.0              # 传送伤害计时器
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

## 相机相关
var original_camera_position: Vector2 = Vector2.ZERO  # 相机原始位置，用于重置
var camera_transition_guard_timer: float = 0.0
var camera_transition_guard_active: bool = false
var camera_transition_dead_zone_backup: Vector2 = Vector2(0.125, 0.1)
var camera_transition_guard_elapsed: float = 0.0
var camera_transition_guard_min_duration: float = 0.12

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

## 残影相关
var afterimage_timer: float = 0.0               # 残影生成计时器
var afterimage_spawn_rate: float = 1.0          # 残影生成频率倍率
var afterimage_trail: Node = null

## JumpBox 残影独立管理
var has_jumpbox_afterimage: bool = false        # 标记是否激活了JumpBox残影效果
var jump2_afterimage_timer: float = 0.0         # 二段跳残影生成计时器
var jump2_rotation: float = 0.0                 # 二段跳旋转角度累计值
var is_jump2_boost_active: bool = false         # 标记是否激活了二段跳速度加成
var jump2_boost_timer: float = 0.0              # 二段跳速度加成计时器
var jump2_boost_direction: int = 1              # 二段跳速度加成的方向（1右，-1左）
var is_jumpbox_triggered: bool = false          # 标记是否触发了JumpBox效果
var jumpbox_force_applied: bool = false         # 标记是否已经应用了JumpBox的弹跳力
var jump2_boost_initial_speed: float = 0.0      # 二段跳速度加成的初始速度值
var jump2_boost_target_speed: float = 0.0       # 二段跳速度加成衰减后的目标速度值

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
var hit_stop_timer: float = 0.0                  # Hit Stop计时器，记录已暂停时间
var hit_stop_duration_current: float = 0.0       # 当前Hit Stop的持续时间
var saved_time_scale: float = 1.0                # 保存的原始时间缩放，用于Hit Stop后恢复

##视觉效果相关
var vignette_effect: Node = null                 # Vignette效果引用
var is_low_health_effect_active: bool = false    # 标记低血量视觉效果是否激活
var low_health_tween: Tween                      # 低血量效果的Tween动画实例
var canvas_original_color: Color = Color.WHITE   # 画布原始颜色，用于效果后恢复
var is_hurt_visual_active: bool = false          # 标记受伤视觉效果是否激活
var hurt_visual_timer: float = 0.0               # 受伤视觉效果计时器

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
	
	# 保存相机原始位置
	if phantom_camera:
		original_camera_position = phantom_camera.position
	
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
	if afterimage_trail != null:
		print("[Player] 已启用本地 AfterimageTrail")
	else:
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
	_update_camera_transition_guard(fixed_delta)
	# ========== 阶段 0：游戏暂停状态处理 ==========
	# 检测游戏暂停状态
	is_game_paused = _check_game_pause_state()
	# ========== 阶段1：特殊状态强制处理 ==========
	# DIE状态需要完全独占处理
	if current_state == PlayerState.DIE:
		# 在DIE状态下强制更新受伤视觉效果计时器
		if is_hurt_visual_active:
			hurt_visual_timer -= fixed_delta
			if hurt_visual_timer <= 0:
				is_hurt_visual_active = false
		
		handle_die_state(fixed_delta)
		move_and_slide()
		# DIE状态下不处理其他逻辑
		return
	# ========== 阶段2：通用状态计时器更新 ==========
	# 更新受伤视觉效果计时器
	if is_hurt_visual_active:
		hurt_visual_timer -= fixed_delta
		if hurt_visual_timer <= 0:
			is_hurt_visual_active = false
	# 保存上一帧的地面状态
	var previous_was_on_floor = was_on_floor
	# 更新控制锁定计时器
	if is_control_locked:
		control_lock_timer -= fixed_delta
		if control_lock_timer <= 0:
			is_control_locked = false
			set_process_input(true)
	# ========== 阶段3：特殊系统处理 ==========
	# Hit Stop期间跳过物理处理
	if is_hit_stop:
		return
	# JumpBox 特殊效果状态切换检测
	if has_jumpbox_afterimage:
		# 检测状态切换：如果不在 JUMP2 动画，结束残影效果
		if current_animation != "JUMP2":
			has_jumpbox_afterimage = false
	# ========== 阶段 4：对话和交互状态处理 ==========
	# 如果在对话中或交互状态，跳过所有输入处理
	if is_in_dialogue or current_state == PlayerState.INTERACTIVE:
		handle_dialogue_physics(fixed_delta)
		move_and_slide()
		update_animation()
		return
	# ========== 阶段5：控制锁定处理 ==========
	# 如果控制被锁定，只处理物理不处理输入
	if is_control_locked:
		# 应用重力
		apply_gravity(fixed_delta)
		# 移动玩家
		move_and_slide()
		# 更新动画
		update_animation()
		return
	# ========== 阶段6：获取输入 ==========
	var move_input = Input.get_axis("left", "right")
	var jump_just_pressed = Input.is_action_just_pressed("jump")
	var jump_pressed = Input.is_action_pressed("jump")
	var jump_just_released = Input.is_action_just_released("jump")
	var dash_just_pressed = Input.is_action_just_pressed("dash")
	is_pressing_up = Input.is_action_pressed("up")
	is_pressing_down = Input.is_action_pressed("down")
	# ========== 阶段7：物理状态更新 ==========
	# 更新墙体检测
	update_wall_detection()
	# 更新无敌状态计时
	if is_invincible:
		invincible_timer -= fixed_delta
		if invincible_timer <= 0:
			is_invincible = false
			animated_sprite.modulate.a = 1.0  # 恢复不透明度
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
	# ========== 阶段12：状态更新 ==========
	# 更新当前帧的地面状态
	was_on_floor = is_on_floor()
	# 使用上一帧的状态检测土狼时间
	if previous_was_on_floor and !was_on_floor and velocity.y >= 0 and !is_jumping:
		coyote_time_active = true
		coyote_timer.start(coyote_time)
	# 更新土狼时间
	update_coyote_time()
	# ========== 阶段13：视觉效果更新 ==========
	# 更新动画
	update_animation()
	# 处理残影效果
	handle_afterimages(fixed_delta)
	# 处理二段跳旋转
	handle_jump2_rotation(fixed_delta)
	# ========== 阶段14：角色朝向更新 ==========
	# 处理转向 - 修复：死亡和受伤状态不能转向
	if move_input != 0 and current_state != PlayerState.DIE and current_state != PlayerState.HURT:
		if current_state == PlayerState.SUPERDASHSTART or current_state == PlayerState.SUPERDASH:
			pass
		else:
			is_facing_right = move_input > 0
			animated_sprite.flip_h = !is_facing_right

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
	# 只在IDLE状态下更新特殊状态计时器
	if current_state == PlayerState.IDLE:
		# 更新睡眠计时器
		sleep_timer += fixed_delta
		
		# 更新观察计时器（只有按下上下方向键时）
		if is_pressing_up and !is_pressing_down:
			look_timer += fixed_delta
		elif is_pressing_down and !is_pressing_up:
			look_timer += fixed_delta
		else:
			look_timer = 0.0
		
		# 检查是否触发SLEEP状态
		if sleep_timer >= idle_to_sleep_time:
			change_state(PlayerState.SLEEP)
			sleep_timer = 0.0
			return
		
		# 检查是否触发LOOKUP状态
		if is_pressing_up and !is_pressing_down and look_timer >= idle_to_look_time:
			change_state(PlayerState.LOOKUP)
			look_timer = 0.0
			return
		
		# 检查是否触发LOOKDOWN状态
		if is_pressing_down and !is_pressing_up and look_timer >= idle_to_look_time:
			change_state(PlayerState.LOOKDOWN)
			look_timer = 0.0
	else:
		# 不在IDLE状态时重置计时器
		sleep_timer = 0.0
		look_timer = 0.0
## 处理冲刺相关的计时器，包括冲刺持续时间和冷却时间
func handle_dash_timers(fixed_delta):
	# 冲刺持续时间计时器 - 修复黑色冲刺持续时间
	if current_state == PlayerState.DASH:
		
		dash_duration_timer += fixed_delta
		# 关键修复：根据是否黑色冲刺使用不同的持续时间
		var current_dash_duration = black_dash_duration if black_dash_unlocked else dash_duration
		if dash_duration_timer >= current_dash_duration:
			dash_duration_timer = 0
			# 恢复到之前的状态或下落状态
			if was_gliding_before_dash:
				was_gliding_before_dash = false
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
#endregion

##角色状态函数集
#region Signals

func handle_state(fixed_delta, move_input, jump_just_pressed, jump_pressed, jump_just_released, dash_just_pressed):
	# 在所有空中状态中检查是否可以攀墙
	if (current_state == PlayerState.JUMP or current_state == PlayerState.DOWN) and \
	   !is_on_floor() and is_touching_wall and wall_grip_unlocked:
		
		# 检查是否按住向墙方向
		var toward_wall = (move_input > 0 and wall_direction == 1) or (move_input < 0 and wall_direction == -1)
		if toward_wall:
			start_wallgrip()
			return
	
	if wall_grip_reverse_timer_node.time_left > 0 and jump_just_pressed:
		# 在缓冲时间内按跳跃键，触发普通完整二段跳
		start_normal_jump_from_wall()
		wall_grip_reverse_timer_node.stop()  # 使用后立即停止
		return
	
	match current_state:
		PlayerState.IDLE:
			handle_idle_state(fixed_delta, move_input, jump_just_pressed, dash_just_pressed)
		PlayerState.MOVE:
			handle_move_state(fixed_delta, move_input, jump_just_pressed, dash_just_pressed)
		PlayerState.RUN:
			handle_run_state(fixed_delta, move_input, jump_just_pressed, dash_just_pressed)
		PlayerState.JUMP:
			handle_jump_state(fixed_delta, move_input, jump_just_pressed, jump_pressed, jump_just_released, dash_just_pressed)
		PlayerState.GLIDE:
			handle_glide_state(fixed_delta, move_input, jump_pressed, dash_just_pressed)
		PlayerState.DOWN:
			handle_down_state(fixed_delta, move_input, jump_just_pressed, jump_pressed, jump_just_released, dash_just_pressed)
		PlayerState.DASH:
			handle_dash_state()
		PlayerState.SUPERDASHSTART:
			handle_super_dash_start_state(fixed_delta, move_input, jump_just_pressed, dash_just_pressed)
		PlayerState.SUPERDASH:
			handle_super_dash_state(fixed_delta, move_input, jump_just_pressed, dash_just_pressed)
		PlayerState.HURT:
			handle_hurt_state(fixed_delta)
		PlayerState.DIE:
			handle_die_state(fixed_delta)
		PlayerState.SLEEP:
			handle_sleep_state(fixed_delta, move_input, jump_just_pressed, dash_just_pressed)
		PlayerState.LOOKUP:
			handle_lookup_state(fixed_delta, move_input, jump_just_pressed, dash_just_pressed)
		PlayerState.LOOKDOWN:
			handle_lookdown_state(fixed_delta, move_input, jump_just_pressed, dash_just_pressed)
		PlayerState.INTERACTIVE:
			handle_interactive_state(fixed_delta)
		PlayerState.WALLGRIP:
			handle_wallgrip_state(fixed_delta, move_input, jump_just_pressed, jump_pressed, jump_just_released, dash_just_pressed)
		PlayerState.WALLJUMP:
			handle_walljump_state(fixed_delta, move_input, jump_just_pressed, jump_pressed, jump_just_released, dash_just_pressed)

func handle_idle_state(_delta, move_input, jump_just_pressed, dash_just_pressed):
	# 首先检查是否可以切换到特殊状态
	if sleep_timer >= idle_to_sleep_time:
		change_state(PlayerState.SLEEP)
		return
	
	if is_pressing_up and !is_pressing_down and look_timer >= idle_to_look_time:
		change_state(PlayerState.LOOKUP)
		return
	
	if is_pressing_down and !is_pressing_up and look_timer >= idle_to_look_time:
		change_state(PlayerState.LOOKDOWN)
		return
	
	# 超级冲刺充电检测（在地面且不在冲刺状态时）
	if super_dash_unlocked and Input.is_action_pressed("super_dash") and current_state != PlayerState.DASH:
		is_super_dash_charging = true
		change_state(PlayerState.SUPERDASHSTART)
		return
	
	if !is_on_floor() and !coyote_time_active:
		if velocity.y < 0:
			change_state(PlayerState.JUMP)
		else:
			change_state(PlayerState.DOWN)
		return
	
	# 冲刺检测（最高优先级）
	if try_dash(dash_just_pressed):
		return
	
	# 跳跃检测
	if try_jump(jump_just_pressed):
		return
	
	if move_input != 0:
		if is_running:
			change_state(PlayerState.RUN)
		else:
			change_state(PlayerState.MOVE)
	else:
		# 减速到停止
		var target_speed = move_input * base_move_speed * effective_horizontal_multiplier
		velocity.x = move_toward(velocity.x, target_speed, ground_acceleration * base_move_speed * effective_horizontal_multiplier)

func handle_move_state(_delta, move_input, jump_just_pressed, dash_just_pressed):
	if !is_on_floor() and !coyote_time_active:
		if velocity.y < 0:
			change_state(PlayerState.JUMP)
		else:
			change_state(PlayerState.DOWN)
		return
	
	# 冲刺检测（最高优先级）
	if try_dash(dash_just_pressed):
		return
	
	# 跳跃检测
	if try_jump(jump_just_pressed):
		return
	
	# 超级冲刺充电检测（在地面且不在冲刺状态时）
	if super_dash_unlocked and Input.is_action_pressed("super_dash") and current_state != PlayerState.DASH:
		is_super_dash_charging = true
		change_state(PlayerState.SUPERDASHSTART)
		return
	
	# 撞墙检测 - 在RUN状态下就触发
	if current_state == PlayerState.RUN and is_on_wall():
		var wall_normal = get_wall_normal()
		if wall_normal.dot(Vector2(move_input, 0)) < 0:  # 移动方向朝向墙壁
			# 触发撞墙效果
			handle_wall_bump()
			return
	
	if move_input == 0:
		change_state(PlayerState.IDLE)
	else:
		if is_running:
			change_state(PlayerState.RUN)
		
		# 移动逻辑
		var target_speed = move_input * base_move_speed * effective_horizontal_multiplier
		velocity.x = move_toward(velocity.x, target_speed, ground_acceleration * base_move_speed * effective_horizontal_multiplier)

func handle_run_state(_delta, move_input, jump_just_pressed, dash_just_pressed):
	if !is_on_floor() and !coyote_time_active:
		if velocity.y < 0:
			change_state(PlayerState.JUMP)
		else:
			change_state(PlayerState.DOWN)
		return
	
	# 冲刺检测（最高优先级）
	if try_dash(dash_just_pressed):
		return
	
	# 跳跃检测
	if try_jump(jump_just_pressed):
		return
	
	# 超级冲刺充电检测（在地面且不在冲刺状态时）
	if super_dash_unlocked and Input.is_action_pressed("super_dash") and current_state != PlayerState.DASH:
		is_super_dash_charging = true
		change_state(PlayerState.SUPERDASHSTART)
		return
	
	# 撞墙检测 - 在 RUN 状态下就触发
	if current_state == PlayerState.RUN and is_on_wall():
		var wall_normal = get_wall_normal()
		if wall_normal.dot(Vector2(move_input, 0)) < 0:  # 移动方向朝向墙壁
			# 触发撞墙效果
			handle_wall_bump()
			return
	
	if move_input == 0:
		change_state(PlayerState.IDLE)
	else:
		if !is_running:
			change_state(PlayerState.MOVE)
		else:
			# 奔跑移动逻辑
			# 关键修改：水中也会应用 effective_horizontal_multiplier (0.5)
			var target_speed = move_input * run_move_speed * effective_horizontal_multiplier
			velocity.x = move_toward(velocity.x, target_speed, ground_acceleration * run_move_speed * effective_horizontal_multiplier)

func handle_jump_state(fixed_delta, move_input, jump_just_pressed, jump_pressed, jump_just_released, dash_just_pressed):
	# 首先检查落地
	if is_on_floor():
		handle_landing()
		return
	
	# JumpBox触发状态下，不处理跳跃键释放（保持JUMP2动画）
	if jump_just_released and is_double_jump_holding and !is_jumpbox_triggered:
		is_double_jump_holding = false
	
	# 简化：按下跳跃键时立即打断JumpBox持续二段跳
	if is_jumpbox_continuous_jump and jump2_interrupt_enabled and jump_just_pressed:
		
		start_jump_interrupt()
		return
	
	# 首先检查是否可以进入攀墙状态
	if is_touching_wall and wall_grip_unlocked and move_input != 0 and sign(move_input) == wall_direction:
		start_wallgrip()
		return
	
	# 冲刺检测（最高优先级）
	if try_dash(dash_just_pressed):
		return
	
	# 二段跳检测
	if try_double_jump(jump_just_pressed):
		return
	
	# 滑翔检测：二段跳后，任何跳跃键按下都进入滑翔
	if can_glide and !is_gliding and jump_just_pressed and !is_double_jump_holding and glide_unlocked:
		start_glide()
		return
	
	# 跳跃保持逻辑
	if jump_pressed and jump_hold_timer < max_jump_hold_time:
		velocity.y += jump_hold_boost
		jump_hold_timer += fixed_delta
	
	# 水平移动控制
	if move_input != 0 and !is_run_jumping and !is_gliding and !is_jump2_boost_active:
		var target_speed = move_input * jump_move_speed * effective_horizontal_multiplier
		velocity.x = move_toward(velocity.x, target_speed, air_control * ground_acceleration * jump_move_speed * effective_horizontal_multiplier)
	
	# 状态转换条件：垂直速度>=0且不在滑翔状态时切换到DOWN
	if velocity.y >= 0 and !is_gliding:
		change_state(PlayerState.DOWN)

func handle_down_state(fixed_delta, move_input, jump_just_pressed, jump_pressed, jump_just_released, dash_just_pressed):
	# 首先检查落地
	if is_on_floor():
		handle_landing()
		return
	
	# JumpBox触发状态下，不处理跳跃键释放
	if jump_just_released and is_double_jump_holding and !is_jumpbox_triggered:
		is_double_jump_holding = false
	
	# 简化：按下跳跃键时立即打断JumpBox持续二段跳
	if is_jumpbox_continuous_jump and jump2_interrupt_enabled and jump_just_pressed:
		
		start_jump_interrupt()
		return
	
	# 首先检查是否可以进入攀墙状态
	if is_touching_wall and wall_grip_unlocked and move_input != 0 and sign(move_input) == wall_direction:
		start_wallgrip()
		return
	
	# 冲刺检测（最高优先级）
	if try_dash(dash_just_pressed):
		return
	
	# 处理二段跳按键释放
	if has_double_jumped and jump_just_released and !is_jumpbox_triggered:
		is_double_jump_holding = false
	
	# 二段跳检测
	if try_double_jump(jump_just_pressed):
		return
	
	# 滑翔检测：二段跳后，任何跳跃键按下都进入滑翔
	if can_glide and !is_gliding and jump_just_pressed and !is_double_jump_holding and glide_unlocked:
		start_glide()
		return
	
	# 跳跃保持逻辑（二段跳也可以长按）
	if jump_pressed and jump_hold_timer < max_jump_hold_time and has_double_jumped:
		velocity.y += jump_hold_boost
		jump_hold_timer += fixed_delta
	
	# 水平移动控制
	if move_input != 0 and !is_run_jumping and !is_gliding and !is_jump2_boost_active:
		var target_speed = move_input * jump_move_speed * effective_horizontal_multiplier
		velocity.x = move_toward(velocity.x, target_speed, air_control * ground_acceleration * jump_move_speed * effective_horizontal_multiplier)

func handle_glide_state(fixed_delta, move_input, jump_pressed, dash_just_pressed):
	# 冲刺检测（最高优先级，可打断滑翔）
	if try_dash(dash_just_pressed):
		return
	
	# 松开跳跃键时退出滑翔
	if !jump_pressed:
		exit_glide()
		return
	
	# 落地时退出滑翔
	if is_on_floor():
		exit_glide()
		return
	
	# 更新滑翔速度
	glide_timer += fixed_delta
	var progress = min(glide_timer / glide_accel_time, 1.0)
	
	# 根据输入方向更新滑翔方向
	if move_input != 0:
		glide_direction = 1 if move_input > 0 else -1
		is_facing_right = glide_direction > 0
	
	# 计算水平速度
	var target_horizontal_speed = 0.0
	if move_input != 0:
		target_horizontal_speed = glide_direction * lerp(glide_init_h_speed, glide_target_h_speed, progress)
	else:
		target_horizontal_speed = move_toward(velocity.x, 0, glide_init_h_speed * fixed_delta)
	
	# 关键修改：应用水平速度乘数
	velocity.x = target_horizontal_speed * effective_horizontal_multiplier
	
	# 只限制最大下落速度，不手动应用重力（由阶段 11 统一处理）
	var current_max_fall = max_fall_speed * lerp(0.0, glide_max_fall_multiplier, progress)
	velocity.y = min(velocity.y, current_max_fall * effective_max_fall_multiplier)

func handle_dash_state():
	# 冲刺期间保持固定速度
	var dash_direction = 1 if is_facing_right else -1
	velocity.x = dash_direction * dash_speed
	velocity.y = 0
	
	# 检测跳跃缓冲
	if Input.is_action_pressed("jump"):
		if can_double_jump and !has_double_jumped:
			jump_buffer_after_dash = true
			jump_buffer_type = 2  # 二段跳
		else:
			jump_buffer_after_dash = true
			jump_buffer_type = 1  # 一段跳

func handle_super_dash_start_state(fixed_delta, _move_input, _jump_just_pressed, _dash_just_pressed):
	# 检查是否松开 O 键
	var super_dash_pressed = Input.is_action_pressed("super_dash")
	
	# 关键修复：在超级冲刺充电期间禁用交互
	is_in_special_state = true
	
	# 修改：充电完成后等待松开按键
	if super_dash_charge_timer >= super_dash_charge_time:
		# 充电完成，等待松开 O 键
		if not super_dash_pressed:
			start_super_dash()
			return
	else:
		# 充电未完成
		if not super_dash_pressed:
			# 打断充电
			is_super_dash_charging = false
			super_dash_charge_timer = 0.0
			is_in_special_state = false  # 恢复交互能力
			change_state(PlayerState.IDLE)
			return
	
	# 更新充电计时器
	super_dash_charge_timer += fixed_delta
	
	# 充电期间水平速度归零，但应用重力
	# 关键修改：应用加速度乘数
	velocity.x = move_toward(velocity.x, 0, ground_deceleration * base_move_speed * effective_acceleration_multiplier)
	apply_gravity(fixed_delta)

func handle_super_dash_state(fixed_delta, _move_input, jump_just_pressed, dash_just_pressed):
	# 更新持续时间计时器
	super_dash_duration_timer += fixed_delta
	if super_dash_duration_timer >= super_dash_max_duration:
		is_in_special_state = false
		# 关键修复：正确重置跳跃状态
		is_jumping = false
		jump_count = 0
		has_double_jumped = false
		can_double_jump = true
		can_glide = false  # 重置滑翔状态
		change_state(PlayerState.DOWN)
		return
	
	# 更新输入锁定计时器
	if super_dash_input_lock_timer > 0:
		super_dash_input_lock_timer -= fixed_delta
	
	# 更新加速计时器
	if super_dash_accel_timer < super_dash_accel_time:
		super_dash_accel_timer += fixed_delta
		var progress = super_dash_accel_timer / super_dash_accel_time
		# 修复：将 0 改为 0.0，确保是浮点数
		var current_speed = lerp(0.0, super_dash_speed, progress)
		
		# 计算 45 度角方向
		var dash_direction = Vector2(1 if is_facing_right else -1, -1).normalized()
		# 关键修改：应用水平速度乘数
		velocity = dash_direction * current_speed * effective_horizontal_multiplier
	else:
		# 达到最大速度
		var dash_direction = Vector2(1 if is_facing_right else -1, -1).normalized()
		# 关键修改：应用水平速度乘数
		velocity = dash_direction * super_dash_speed * effective_horizontal_multiplier
	
	# 处理残影
	super_dash_afterimage_timer += fixed_delta
	if super_dash_afterimage_timer >= _get_afterimage_interval("super_dash"):
		super_dash_afterimage_timer = 0
		create_afterimage(PlayerState.SUPERDASH)
	
	# 检查碰撞
	if is_on_wall() or is_on_ceiling():
		# 撞到碰撞体，触发抖动并切换到 DOWN 状态
		CameraShakeManager.shake("x_strong", phantom_camera)
		is_in_special_state = false
		# 重置二段跳状态，允许后续跳跃
		has_double_jumped = false
		can_double_jump = true
		change_state(PlayerState.DOWN)
		return
	
	# 输入锁定结束后可以接受跳跃和冲刺输入
	if super_dash_input_lock_timer <= 0:
		if jump_just_pressed:
			is_in_special_state = false
			# 关键修复：正确重置跳跃状态
			is_jumping = false
			jump_count = 0
			has_double_jumped = false
			can_double_jump = true
			can_glide = false
			change_state(PlayerState.JUMP)
			return
		if dash_just_pressed:
			is_in_special_state = false
			is_jumping = false
			jump_count = 0
			has_double_jumped = false
			can_double_jump = true
			can_glide = false
			# 关键修复：超级冲刺打断后使用冲刺，应该消耗空中冲刺次数
			if not is_on_floor() and not coyote_time_active:
				has_dashed_in_air = true
			change_state(PlayerState.DASH)
			return

func handle_hurt_state(fixed_delta):
	# 基础半透明设置
	if !is_warp_damage:  # 只有非传送伤害才设置半透明
		animated_sprite.modulate.a = 0.5
	
	# 受伤期间应用重力
	# 关键修改：应用重力乘数和最大下落乘数
	velocity.y += gravity * effective_gravity_multiplier * fixed_delta
	velocity.y = min(velocity.y, effective_max_fall_speed)
	
	# 水平速度衰减（关键修改：应用加速度乘数）
	velocity.x = move_toward(velocity.x, 0, dash_inertia_decay * base_move_speed * fixed_delta * effective_acceleration_multiplier)
	
	# 确保在HURT状态下保持正确的动画
	if current_animation != "HURT":
		current_animation = "HURT"
		animated_sprite.play("HURT")
	
	# 处理传送伤害淡化效果和计时
	if is_warp_damage and not is_in_death_process:
		warp_damage_timer -= fixed_delta
		
		# 计算淡化进度
		var fade_progress = 1.0 - (warp_damage_timer / warp_stun_and_teleport_time)
		
		# 从0.5线性淡化到0
		var target_alpha = 0.5 * (1.0 - fade_progress)
		animated_sprite.modulate.a = target_alpha
		
		# 同时淡化灯光
		if point_light:
			point_light.energy = 1.0 * (1.0 - fade_progress)
		
		# 传送伤害时间结束，执行传送
		if warp_damage_timer <= 0:
			perform_warp_teleport()
			return
	
	# 受伤僵直时间处理
	hurt_timer -= fixed_delta
	
	# 普通伤害僵直时间结束
	if hurt_timer <= 0 and not is_warp_damage:
		# 僵直结束，开始无敌时间
		is_invincible = true
		invincible_timer = hurt_invincible_time
		
		# 回到适当状态
		if is_on_floor():
			change_state(PlayerState.IDLE)
		else:
			change_state(PlayerState.DOWN)

func handle_die_state(fixed_delta):
	# 如果还没有开始死亡流程，则开始
	if not is_in_death_process:
		
		start_death_process()
	
	# 关键修复：确保低血量效果在死亡流程中保持
	if player_ui and player_ui.get_health() <= 1 and not is_low_health_effect_active and not is_hurt_visual_active:
		_trigger_low_health_effect()
	
	# 应用完整重力（关键修改：应用重力乘数和最大下落乘数）
	velocity.y += gravity * effective_gravity_multiplier * fixed_delta
	velocity.y = min(velocity.y, effective_max_fall_speed)
	
	# 水平速度衰减（关键修改：应用加速度乘数）
	if abs(velocity.x) > 0:
		velocity.x = move_toward(velocity.x, 0, dash_inertia_decay * base_move_speed * fixed_delta * effective_acceleration_multiplier)
	
	# 更新死亡计时器
	die_timer -= fixed_delta
	
	# 关键修复：确保DIE动画播放
	if animated_sprite.animation != "DIE":
		animated_sprite.play("DIE")
		
	# 关键修复：强制每帧执行淡化逻辑
	if die_timer > 0:
		# 计算淡化进度 (从1到0)
		var progress = die_timer / die_animation_time
		
		# 角色透明度：从0.5线性淡化到0
		animated_sprite.modulate.a = 0.5 * progress
		
		# PointLight2D能量：从当前值线性淡化到0
		if point_light:
			point_light.energy = 1.0 * progress  # 从1.0淡化到0
	else:
		# 确保完全透明和灯光关闭
		animated_sprite.modulate.a = 0.0
		if point_light:
			point_light.energy = 0.0

func handle_interactive_state(fixed_delta):
	# 水平速度归零，但保留重力
	velocity.x = 0
	if not is_on_floor():
		apply_gravity(fixed_delta)

func handle_sleep_state(fixed_delta, move_input, jump_just_pressed, dash_just_pressed):
	# 任何输入都会打断睡眠状态
	if (move_input != 0 or jump_just_pressed or dash_just_pressed or 
		is_pressing_up or is_pressing_down):
		change_state(PlayerState.IDLE)
		return
	
	# 受伤或死亡也会打断
	if is_invincible or is_dying:
		change_state(PlayerState.IDLE)
		return
	
	# 关键修复：确保重力被正确应用
	if not is_on_floor():
		# 应用重力
		velocity.y += gravity * fixed_delta
		velocity.y = min(velocity.y, max_fall_speed)
	else:
		# 如果在地面上，确保垂直速度为零
		velocity.y = 0
	
	# 水平速度归零
	# 关键修改：应用加速度乘数
	velocity.x = move_toward(velocity.x, 0, ground_deceleration * base_move_speed * effective_acceleration_multiplier)

func handle_lookup_state(_delta, move_input, jump_just_pressed, dash_just_pressed):
	# 任何移动、跳跃、冲刺输入都会打断向上看状态
	if move_input != 0 or jump_just_pressed or dash_just_pressed:
		reset_camera_position()
		change_state(PlayerState.IDLE)
		return
	
	# 松开上键也会退出
	if !is_pressing_up:
		reset_camera_position()
		change_state(PlayerState.IDLE)
		return
	
	# 受伤或死亡也会打断
	if is_invincible or is_dying:
		reset_camera_position()
		change_state(PlayerState.IDLE)
		return
	
	# 向上看状态下保持静止，并平滑移动相机
	# 关键修改：应用加速度乘数
	velocity.x = move_toward(velocity.x, 0, ground_deceleration * base_move_speed * effective_acceleration_multiplier)
	
	# 使用Tween平滑过渡相机偏移
	if phantom_camera:
		var tween = create_tween()
		tween.set_trans(camera_offset_transition_type)
		tween.set_ease(camera_offset_ease_type)
		tween.tween_property(phantom_camera, "follow_offset", Vector2(0, -lookup_camera_offset), camera_offset_transition_duration)

func handle_lookdown_state(_delta, move_input, jump_just_pressed, dash_just_pressed):
	# 任何移动、跳跃、冲刺输入都会打断向下看状态
	if move_input != 0 or jump_just_pressed or dash_just_pressed:
		reset_camera_position()
		change_state(PlayerState.IDLE)
		return
	
	# 松开下键也会退出
	if !is_pressing_down:
		reset_camera_position()
		change_state(PlayerState.IDLE)
		return
	
	# 受伤或死亡也会打断
	if is_invincible or is_dying:
		reset_camera_position()
		change_state(PlayerState.IDLE)
		return
	
	# 向下看状态下保持静止，并平滑移动相机
	# 关键修改：应用加速度乘数
	velocity.x = move_toward(velocity.x, 0, ground_deceleration * base_move_speed * effective_acceleration_multiplier)
	
	# 使用Tween平滑过渡相机偏移
	if phantom_camera:
		var tween = create_tween()
		tween.set_trans(camera_offset_transition_type)
		tween.set_ease(camera_offset_ease_type)
		tween.tween_property(phantom_camera, "follow_offset", Vector2(0, lookdown_camera_offset), camera_offset_transition_duration)

func handle_wallgrip_state(fixed_delta, move_input, jump_just_pressed, _jump_pressed, _jump_just_released, dash_just_pressed):
	# 冲刺检测（最高优先级）
	if try_dash(dash_just_pressed):
		return
	
	# 检查是否还在墙上
	if !is_touching_wall or is_on_floor():
		exit_wallgrip()
		return
	
	# 检查按键方向
	var toward_wall = (move_input > 0 and wall_direction == 1) or (move_input < 0 and wall_direction == -1)
	var away_from_wall = (move_input < 0 and wall_direction == 1) or (move_input > 0 and wall_direction == -1)
	
	# 处理动画状态重叠：如果受伤，强制退出攀墙状态
	if is_invincible and current_state == PlayerState.HURT:
		exit_wallgrip()
		return
	
	if toward_wall:
		# 规则：按住向墙方向键
		# 重置 no_input_timer，因为输入状态改变
		no_input_timer = 0.0
		
		hold_toward_wall_timer += fixed_delta
		
		if hold_toward_wall_timer < hold_toward_wall_time:
			# a 时间内：静止不下滑
			velocity.y = 0
			current_wall_slide_speed = 0
			
			# 调试输出
			if Engine.is_editor_hint():
				pass  # 占位符
		else:
			# a 时间后：缓慢下滑（关键修改：应用重力乘数）
			velocity.y = wall_slide_slow_speed * effective_gravity_multiplier
			current_wall_slide_speed = wall_slide_slow_speed * effective_gravity_multiplier
			
			# 调试输出
			if Engine.is_editor_hint():
				pass  # 占位符
		velocity.x = 0
		
	elif away_from_wall:
		# 按反方向键，启动缓冲计时器
		wall_grip_reverse_timer_node.start(wall_grip_reverse_buffer_time)
		exit_wallgrip()
		return
	else:
		# 规则：没有按方向键
		no_input_timer += fixed_delta
		
		# 计算线性变化进度（0 到 1）
		var progress = min(no_input_timer / no_input_time, 1.0)
		
		# 从 wall_slide_slow_speed 线性变化到 wall_slide_speed（关键修改：应用重力乘数）
		current_wall_slide_speed = lerp(wall_slide_slow_speed, wall_slide_speed, progress) * effective_gravity_multiplier
		velocity.y = current_wall_slide_speed
		velocity.x = 0
	
	# 跳跃处理
	if jump_just_pressed:
		if toward_wall:
			start_wall_jump()
		else:
			start_normal_jump_from_wall()
		return
	
	# 二段跳检测
	if try_double_jump(jump_just_pressed):
		return

func handle_walljump_state(fixed_delta, move_input, _jump_just_pressed, jump_pressed, _jump_just_released, dash_just_pressed):
	# 删除未使用的参数
	
	# 冲刺检测
	if try_dash(dash_just_pressed):
		return
	
	wall_jump_timer += fixed_delta
	
	# 第一阶段：墙跳初速度（0.1 秒内）
	if wall_jump_timer < 0.1:
		# 关键修改：应用水平和垂直乘数
		velocity.x = wall_jump_h_speed * -wall_direction * effective_horizontal_multiplier  # 向墙外跳
		velocity.y = wall_jump_v_speed * effective_vertical_multiplier
	else:
		# 第二阶段：允许玩家控制
		if move_input != 0:
			var target_speed = move_input * base_move_speed
			# 关键修改：应用加速度乘数
			velocity.x = move_toward(velocity.x, target_speed, air_control * ground_acceleration * base_move_speed * effective_acceleration_multiplier)
	
	# 跳跃保持
	if jump_pressed and wall_jump_hold_timer < wall_jump_max_hold_time:
		velocity.y += wall_jump_hold_boost
		wall_jump_hold_timer += fixed_delta
	
	# 关键修改：应用重力乘数（之前是直接调用 apply_gravity，但现在统一使用乘数）
	apply_gravity(fixed_delta)
	
	# 墙跳结束后可以重新附着
	if wall_jump_timer >= wall_jump_reattach_delay:
		can_reattach_to_wall = true
		
		# 检查是否可以回到墙上
		if is_touching_wall and move_input != 0 and sign(move_input) == wall_direction:
			start_wallgrip()
		elif velocity.y >= 0:
			change_state(PlayerState.DOWN)

func change_state(new_state: PlayerState):
	# 如果状态相同，不进行切换
	if current_state == new_state:
		return
	# 状态退出逻辑
	match current_state:
		PlayerState.DASH:
			if is_facing_right:
				# 关键修改：应用水平速度乘数
				velocity.x = dash_inertia_speed * effective_horizontal_multiplier
			else:
				# 关键修改：应用水平速度乘数
				velocity.x = -dash_inertia_speed * effective_horizontal_multiplier
			can_reattach_to_wall = true
		
		PlayerState.JUMP:
			# 如果正在打断衰减，清除衰减状态
			if is_jump_interrupt_decaying:
				is_jump_interrupt_decaying = false
				jump_interrupt_decay_timer = 0.0
		
		PlayerState.WALLGRIP:
			hold_toward_wall_timer = 0.0
			no_input_timer = 0.0
			current_wall_slide_speed = 0.0
		
		PlayerState.WALLJUMP:
			can_reattach_to_wall = true
		
		PlayerState.LOOKUP, PlayerState.LOOKDOWN:
			reset_camera_position()
		
		PlayerState.SLEEP:
			sleep_timer = 0.0
	
	# 关键新增：提供死亡状态检查方法（供 Door.gd 使用）
	if new_state == PlayerState.DIE:
		is_in_death_process = true
	
	# 状态进入逻辑
	match new_state:
		PlayerState.DOWN:
			down_state_entry_time = 0.0  ## 重置为0，我们将在_physics_process中累计
		
		PlayerState.LOOKUP:
			if phantom_camera:
				phantom_camera.position = original_camera_position + Vector2(0, -lookup_camera_offset)
		
		PlayerState.LOOKDOWN:
			if phantom_camera:
				phantom_camera.position = original_camera_position + Vector2(0, lookdown_camera_offset)
		
		PlayerState.SLEEP:
			sleep_timer = 0.0
		
		PlayerState.DIE:
			die_timer = die_animation_time
			is_invincible = true
			animated_sprite.rotation_degrees = 0
			jump2_rotation = 0
			# 确保从半透明开始
			animated_sprite.modulate.a = 0.5
		
		PlayerState.HURT:
			is_invincible = true
			invincible_timer = hurt_invincible_time
			animated_sprite.rotation_degrees = 0
			jump2_rotation = 0
			# 受伤时设置为半透明
			animated_sprite.modulate.a = 0.5
		
		PlayerState.DASH:
			if current_state == PlayerState.WALLJUMP:
				can_reattach_to_wall = false
		
		PlayerState.WALLGRIP:
			# 进入攀墙状态时，重置计时器
			hold_toward_wall_timer = 0.0
			no_input_timer = 0.0
			current_wall_slide_speed = 0.0
			# 重置二段跳状态，允许后续跳跃
			has_double_jumped = false
			can_double_jump = true
			has_dashed_in_air = false
			can_dash = true
			# 修复：进入攀墙时强制设置正确的动画状态
			current_animation = "WALLGRIP"
			animated_sprite.play("WALLGRIP")
	
	# 更新当前状态
	current_state = new_state

## 检查玩家是否处于死亡状态（供 Door.gd 调用）
func is_in_death_state() -> bool:
	return current_state == PlayerState.DIE or is_in_death_process

#endregion

## 更新动画函数
func update_animation():
	# 关键修复：死亡流程强制DIE动画
	if is_in_death_process:
		if current_animation != "DIE":
			current_animation = "DIE"
			animated_sprite.play("DIE")
		return
	
	# 如果当前动画不是JUMP2但JumpBox效果还在，立即清除
	if current_animation != "JUMP2" and is_jumpbox_triggered:
		clear_jumpbox_effect()
	
	# 正常动画逻辑
	var target_animation_val = ""
	
	match current_state:
		PlayerState.IDLE:
			target_animation_val = "IDLE"
		PlayerState.MOVE:
			target_animation_val = "MOVE"
		PlayerState.RUN:
			target_animation_val = "RUN"
		PlayerState.JUMP:
			if has_double_jumped:
				# JumpBox触发：强制保持JUMP2
				if is_jumpbox_triggered:
					target_animation_val = "JUMP2"
				elif is_double_jump_holding:
					target_animation_val = "JUMP2"
				else:
					target_animation_val = "JUMP1"
			else:
				target_animation_val = "JUMP1"
		PlayerState.DOWN:
			if has_double_jumped:
				# JumpBox触发：强制保持JUMP2
				if is_jumpbox_triggered:
					target_animation_val = "JUMP2"
				elif is_double_jump_holding:
					target_animation_val = "JUMP2"
				else:
					target_animation_val = "DOWN"
			else:
				target_animation_val = "DOWN"
		PlayerState.DASH:
			if black_dash_unlocked:
				target_animation_val = "BLACKDASH"
			else:
				target_animation_val = "DASH"
		PlayerState.GLIDE:
			target_animation_val = "GLIDE"
		PlayerState.HURT:
			target_animation_val = "HURT"
		PlayerState.DIE:
			target_animation_val = "DIE"
		PlayerState.SLEEP:
			target_animation_val = "SLEEP"
		PlayerState.LOOKUP:
			target_animation_val = "LOOKUP"
		PlayerState.LOOKDOWN:
			target_animation_val = "LOOKDOWN"
		PlayerState.INTERACTIVE:
			target_animation_val = "INTERACTIVE"
		PlayerState.WALLGRIP:
			target_animation_val = "WALLGRIP"
		PlayerState.WALLJUMP:
			target_animation_val = "WALLJUMP"
		PlayerState.SUPERDASHSTART:
			target_animation_val = "SUPERDASHSTART"
		PlayerState.SUPERDASH:
			target_animation_val = "SUPERDASH"
	
	# 关键优化：动画切换时检查是否需要清除JumpBox效果
	if target_animation_val != current_animation and target_animation_val != "":
		# 如果从JUMP2动画切换到其他动画，且是JumpBox触发的，清除效果
		if current_animation == "JUMP2" and is_jumpbox_triggered:
			clear_jumpbox_effect()
		
		current_animation = target_animation_val
		animated_sprite.play(target_animation_val)
	
	if is_invincible and current_state != PlayerState.HURT and current_state != PlayerState.DIE and not is_respawn_invincible:
		animated_sprite.modulate.a = 0.5
	elif current_state != PlayerState.HURT and current_state != PlayerState.DIE:
		animated_sprite.modulate.a = 1.0

## 受伤处理函数集
#region Signals

func take_damage(damage_source_position: Vector2, damage: int = 1, damage_type: int = 0, knockback_force: Vector2 = Vector2.ZERO):
	# 将int转换为DamageType枚举
	var actual_damage_type = DamageType.NORMAL
	match damage_type:
		0: actual_damage_type = DamageType.NORMAL
		1: actual_damage_type = DamageType.SHADOW
		2: actual_damage_type = DamageType.WARP_NORMAL
		3: actual_damage_type = DamageType.WARP_SHADOW
	
	# 调用新的伤害处理方法
	take_damage_with_type(damage_source_position, damage, actual_damage_type, knockback_force)

func take_damage_with_type(damage_source_position: Vector2, damage: int = 1, damage_type: DamageType = DamageType.NORMAL, knockback_force: Vector2 = Vector2.ZERO):
	# 死亡状态下不受伤害
	if current_state == PlayerState.DIE:
		return
	
	# 黑色冲刺无敌
	if current_state == PlayerState.DASH and black_dash_unlocked:
		return
	
	# 无敌状态下不受伤害
	if is_invincible:
		return
	
	# 如果当前是冲刺状态，强制退出冲刺
	if current_state == PlayerState.DASH:
		# 关键修复：立即停止冲刺相关计时器
		dash_duration_timer = 0
		dash_duration_timer_node.stop()
		can_dash = true
		was_gliding_before_dash = false
		# 关键修复：立即切换到HURT状态，避免状态冲突
		change_state(PlayerState.HURT)
	
	# 如果当前是特殊状态，先退出到IDLE
	if current_state == PlayerState.SLEEP or current_state == PlayerState.LOOKUP or current_state == PlayerState.LOOKDOWN:
		reset_camera_position()
		change_state(PlayerState.IDLE)
	
	# 设置击退方向
	if knockback_force != Vector2.ZERO:
		hurt_direction = knockback_force.normalized()
	else:
		hurt_direction = (global_position - damage_source_position).normalized()
		hurt_direction.y = -0.5
	
	# 设置击退速度
	velocity = hurt_direction * hurt_knockback_speed
	
	# 设置即将受伤标记
	is_about_to_be_hurt = true
	
	# 减少血量
	var _old_health = player_ui.get_health()
	player_ui.take_damage(damage)
	var new_health = player_ui.get_health()
	
	# 致命伤害处理 - 恢复立即死亡
	if new_health <= 0 and not is_in_death_process:
		is_in_death_process = true
		change_state(PlayerState.DIE)
		start_die_slow_motion()
		return  # 直接返回，不执行后续代码
	
	# 非致命伤害处理 - 所有伤害类型都需要检查
	match damage_type:
		DamageType.NORMAL, DamageType.SHADOW, DamageType.WARP_NORMAL, DamageType.WARP_SHADOW:
			# 关键修复：统一处理所有伤害类型
			is_invincible = true
			
			# 触发 Hit Stop（tier2 - 0.2s）
			TimerControlManager.hit_stop(2)
			
			# 根据伤害类型设置不同时间
			if damage_type == DamageType.NORMAL or damage_type == DamageType.WARP_NORMAL:
				hurt_timer = hurt_stun_time
				invincible_timer = hurt_invincible_time
			else:  # SHADOW类型
				hurt_timer = hurt_stun_time
				invincible_timer = hurt_invincible_time  # 阴影伤害可能需要更长无敌时间
			
			# 伤害导致低血量的处理
			if new_health <= 1:
				# 从VignetteEffect获取受伤效果持续时间
				var hurt_duration = 0.8  # 默认值
				if vignette_effect and vignette_effect.has_method("get_hurt_duration"):
					hurt_duration = vignette_effect.get_hurt_duration(damage_type == DamageType.SHADOW or damage_type == DamageType.WARP_SHADOW)
				
				# 推迟低血量效果的触发
				get_tree().create_timer(0.05).timeout.connect(func():
					is_about_to_be_hurt = false
					# 等受伤效果开始后再检查低血量
					get_tree().create_timer(hurt_duration * 0.8).timeout.connect(func():
						if player_ui and player_ui.get_health() <= 1:
							print("Player: 受伤效果播放中，检测到低血量，准备过渡")
					)
				)
	
	# 切换到HURT状态（仅非致命伤害）
	change_state(PlayerState.HURT)
	
	# 根据伤害类型处理视觉效果
	match damage_type:
		DamageType.NORMAL:
			start_normal_hurt_effect()
		DamageType.SHADOW:
			start_shadow_hurt_effect()
		DamageType.WARP_NORMAL:
			start_warp_hurt_effect(false)
		DamageType.WARP_SHADOW:
			start_warp_hurt_effect(true)
	
	# 检查死亡
	if new_health <= 0 and not is_in_death_process:
		is_in_death_process = true
	elif damage_type == DamageType.WARP_NORMAL or damage_type == DamageType.WARP_SHADOW:
		# 非致命传送伤害启动传送流程
		is_warp_damage = true
		warp_damage_timer = warp_stun_and_teleport_time

func perform_warp_teleport():
	var safe_spot = Vector2.ZERO
	
	# 关键修复：使用最近一次激活的检查点（动态或静态）
	safe_spot = Global.get_last_checkpoint_position()
	
	if safe_spot != Vector2.ZERO:
		pass  # 占位符，原本有调试输出已删除
	else:
		# 如果连最后检查点都没有，降级到静态存档点
		safe_spot = Global.get_save_point_position()
		
	# 传送到安全位置
	global_position = safe_spot
	velocity = Vector2.ZERO
	
	# 重置角色状态
	reset_after_warp()
	
	# 传送后设置为半透明
	animated_sprite.modulate.a = 0.5
	if point_light:
		point_light.energy = 0.5
	
	# 设置无敌和控制锁定
	is_invincible = true
	invincible_timer = warp_invincible_time
	
	control_lock_timer = warp_control_lock_time
	is_control_locked = true
	
	print("传送伤害处理完成：位置=", safe_spot, " 无敌时间=", warp_invincible_time, " 控制锁定=", warp_control_lock_time)

## 传送后状态重置
func reset_after_warp():
	# 重置物理状态
	velocity = Vector2.ZERO
	
	# 只重置必要的临时状态，不重置能力状态和生命值
	is_jumping = false
	jump_count = 0
	has_double_jumped = false
	can_double_jump = false
	
	# 重置滑翔状态
	is_gliding = false
	can_glide = false
	is_double_jump_holding = false
	was_gliding_before_dash = false
	
	# 重置冲刺状态
	has_dashed_in_air = false
	can_dash = true
	
	# 重置传送伤害状态
	is_warp_damage = false
	warp_damage_timer = 0.0
	
	# 重置其他临时状态
	is_run_jumping = false
	is_wall_bump_stun = false
	is_jump2_boost_active = false
#endregion

## 死亡处理函数集
#region Signals

func _on_player_died():
	if current_state == PlayerState.DIE or is_in_death_process:
		return
	is_in_death_process = true
	
	# 立即锁定控制
	lock_control(999)
	
	# 启动异步死亡流程
	_start_async_death_process()

func _start_async_death_process():
	# 使用 TimerControlManager 触发 Hit Stop（tier2 - 0.2s）
	TimerControlManager.hit_stop(2)
	
	# 等待 Hit Stop 结束后开始死亡效果
	await get_tree().create_timer(0.2).timeout
	
	if not is_in_death_process:
		return
		
	# 切换到死亡状态
	change_state(PlayerState.DIE)
	
	# 开始死亡慢动作（medium 档位：1.0s, time_scale=0.5）
	TimerControlManager.slow_motion("medium")
	
	# 在慢动作结束后开始正式死亡流程
	await get_tree().create_timer(slowly_die_time).timeout
	
	if not is_in_death_process:
		return
		
	await start_death_process()

func start_death_process():
	if not is_in_death_process:
		return
	# 停止当前 BGM（淡出效果）
	AudioManager.stop_bgm(1.0)
	# 等待死亡动画播放完毕
	await get_tree().create_timer(die_animation_time).timeout
	# 清除低血量视觉效果
	if is_low_health_effect_active:
		_clear_low_health_effect()
	# 开始渐黑转场
	await FadeManager.fade_out(fade_transition_time / 2)
	# 在转场中间时刻传送玩家到存档点
	global_position = Global.get_save_point_position()
	# 重置玩家状态
	reset_player_for_respawn()
	# 继续转场的后半部分（渐显）
	await FadeManager.fade_in(fade_transition_time / 2)
	# 恢复BGM（在重生流程结束后）
	get_tree().create_timer(0.5).timeout.connect(func():
		if RoomManager.current_room != "":
			RoomManager.switch_room_bgm(RoomManager.current_room)
	)
	# 重生后不可操控时间
	lock_control(respawn_invincible_time)
	# 等待不可操控时间结束
	await get_tree().create_timer(respawn_invincible_time).timeout
	# 恢复控制
	set_process_input(true)
	# 如果还在SLEEP状态，切换到IDLE
	if current_state == PlayerState.SLEEP:
		change_state(PlayerState.IDLE)
	is_in_death_process = false

func reset_player_for_respawn():
	# 强制恢复所有状态
	Engine.time_scale = 1.0
	
	# 关键修复：完全重置死亡流程状态
	is_in_death_process = false
	is_dying = false
	die_timer = 0.0
	
	# 关键修复：重置动画状态
	current_animation = ""
	
	# 重置物理状态
	velocity = Vector2.ZERO
	
	# 重置能力状态
	is_jumping = false
	jump_count = 0
	has_double_jumped = false
	can_double_jump = false
	is_gliding = false
	can_glide = false
	is_double_jump_holding = false
	was_gliding_before_dash = false
	has_dashed_in_air = false
	can_dash = true
	
	# 关键修复：重置传送伤害状态
	is_warp_damage = false
	warp_damage_timer = 0.0
	is_about_to_be_hurt = false  # 同时重置即将受伤标记
	
	# 关键修复：使用重生无敌标记，避免半透明
	is_respawn_invincible = true
	is_invincible = true
	
	# 强制恢复不透明
	animated_sprite.modulate.a = 1.0
	if point_light:
		point_light.energy = 1.0
	
	# 关键修复：在重生时清除低血量效果
	if is_low_health_effect_active:
		_clear_low_health_effect()
	
	# 设置为睡眠状态
	change_state(PlayerState.SLEEP)
	
	# 恢复生命值
	if player_ui:
		player_ui.set_health(Global.player_max_health)
	
	# 关键修复：在无敌时间结束后取消重生无敌
	get_tree().create_timer(respawn_invincible_time).timeout.connect(func():
		is_invincible = false
		is_respawn_invincible = false
		# 确保保持不透明
		animated_sprite.modulate.a = 1.0
	)

func start_die_slow_motion():
	# 使用 TimerControlManager 的 medium 档位
	TimerControlManager.slow_motion("medium")

#endregion

## 奔跑冲刺超级冲刺相关函数集
#region Signals

func detect_run_input(move_input):
	if move_input != 0 and (is_on_floor() or coyote_time_active):
		var current_time = Time.get_unix_time_from_system()
		var move_direction = 1 if move_input > 0 else -1
		
		# 检测快速点击
		if Input.is_action_just_pressed("right") or Input.is_action_just_pressed("left"):
			if move_direction == last_move_direction:
				var time_since_last_input = current_time - last_move_input_time
				if time_since_last_input < quick_tap_time_window:
					# 快速点击同一方向，准备奔跑
					is_run_ready = true
					run_direction = move_direction
			else:
				# 方向改变，重置
				is_run_ready = false
			
			last_move_input_time = current_time
			last_move_direction = move_direction
		
		# 检查是否满足奔跑条件
		if is_run_ready and run_direction == move_direction:
			is_running = true
			
			# 记录奔跑状态用于土狼时间
			if is_on_floor():
				was_running_before_coyote = true
		else:
			is_running = false
			
	else:
		# 没有移动输入或不在平台上
		is_running = false
		is_run_ready = false
		
	# 如果在地面上，重置土狼时间前的奔跑状态
	if is_on_floor():
		was_running_before_coyote = is_running

func handle_wall_bump():
	# 触发相机抖动
	CameraShakeManager.shake("x_strong", phantom_camera)
	
	# 施加反弹力
	velocity.x = wall_bump_rebound_x * (-1 if is_facing_right else 1)
	velocity.y = wall_bump_rebound_y
	
	# 设置僵直时间，但不切换状态
	hurt_timer = hurt_stun_time
	is_wall_bump_stun = true

func handle_wall_bump_stun(fixed_delta):
	# 应用重力
	apply_gravity(fixed_delta)
	
	# 水平速度衰减
	velocity.x = move_toward(velocity.x, 0, dash_inertia_decay * base_move_speed * fixed_delta)
	
	# 僵直时间处理
	hurt_timer -= fixed_delta
	
	if hurt_timer <= 0:
		# 僵直结束
		is_wall_bump_stun = false
		
		# 回到适当状态
		if is_on_floor():
			change_state(PlayerState.IDLE)
		else:
			change_state(PlayerState.DOWN)

func handle_run_jump(fixed_delta):
	if is_run_jumping:
		run_jump_timer -= fixed_delta
		
		# 检查是否反向输入
		var move_input = Input.get_axis("left", "right")
		if move_input != 0 and sign(move_input) != run_jump_original_direction:
			# 反向输入，立即结束奔跑跳跃加成
			is_run_jumping = false
		elif run_jump_timer > 0:
			# 关键修改：应用水平速度乘数
			velocity.x = run_jump_original_direction * (base_move_speed + run_jump_boost_speed) * effective_horizontal_multiplier
		else:
			# 加成时间结束，开始衰减
			var target_speed = run_jump_original_direction * base_move_speed
			velocity.x = move_toward(velocity.x, target_speed, run_jump_boost_speed * fixed_delta / run_jump_decay_time)
			
			# 如果已经衰减到基础速度，结束奔跑跳跃状态
			if abs(velocity.x) <= base_move_speed:
				is_run_jumping = false

func try_dash(dash_just_pressed: bool) -> bool:
	if dash_just_pressed and can_dash and dash_unlocked:
		# 记录冲刺前是否在滑翔
		was_gliding_before_dash = (current_state == PlayerState.GLIDE)
		
		# 如果是从滑翔状态进入冲刺，需要正确退出滑翔状态
		if was_gliding_before_dash:
			is_gliding = false
			glide_timer = 0.0
			is_double_jump_holding = false
		
		# 检查空中冲刺限制
		if not is_on_floor() and not coyote_time_active:
			if has_dashed_in_air:
				return false
			has_dashed_in_air = true
		
		change_state(PlayerState.DASH)
		can_dash = false
		dash_duration_timer = 0
		var current_dash_duration = black_dash_duration if black_dash_unlocked else dash_duration
		dash_duration_timer_node.start(current_dash_duration)
		dash_cooldown_timer_node.start(dash_cooldown)  # 使用节点计时器
		return true
	elif dash_just_pressed and !dash_unlocked:
		print("冲刺能力尚未解锁！")
	return false

func start_super_dash():
	is_super_dash_charging = false
	super_dash_charge_timer = 0.0
	super_dash_accel_timer = 0.0
	super_dash_input_lock_timer = super_dash_input_lock_time
	super_dash_duration_timer = 0.0  # 重置持续时间计时器
	is_in_special_state = true  # 超级冲刺期间也禁用交互
	change_state(PlayerState.SUPERDASH)

#endregion

## 跳跃滑翔相关函数集
#region Signals
## 尝试执行一段跳跃（地面或土狼时间），返回是否成功执行
func try_jump(jump_just_pressed: bool) -> bool:
	# 在地面或土狼时间时
	if is_on_floor() or coyote_time_active:
		if jump_just_pressed or jump_buffer_timer.time_left > 0:
			# 第一次跳跃
			velocity.y = jump_velocity
			jump_hold_timer = 0.0
			is_jumping = true
			jump_count = 1
			
			# 重置双重跳跃状态
			has_double_jumped = false
			can_double_jump = true
			
			# 重置滑翔状态
			can_glide = false
			is_double_jump_holding = false
			was_gliding_before_dash = false
			
			# 检查是否是奔跑跳跃
			if current_state == PlayerState.RUN or (coyote_time_active and was_running_before_coyote):
				is_run_jumping = true
				run_jump_timer = run_jump_boost_duration
				run_jump_original_direction = 1 if is_facing_right else -1
			
			change_state(PlayerState.JUMP)
			jump_buffer_timer.stop()
			return true
	
	return false
## 尝试执行二段跳跃（空中，包括补偿跳跃），返回是否成功执行
func try_double_jump(jump_just_pressed: bool) -> bool:
	# 首先检查能力是否解锁
	if !double_jump_unlocked:
		return false
	
	# 补偿跳跃检测
	if can_compensation_jump and !compensation_jump_used and jump_just_pressed and !is_on_floor() and !coyote_time_active:
		velocity.y = double_jump_velocity
		jump_hold_timer = 0.0
		jump_count = 2
		
		has_double_jumped = true
		can_double_jump = false
		compensation_jump_used = true
		
		can_glide = true
		is_double_jump_holding = true
		
		change_state(PlayerState.JUMP)
		return true
	
	# 正常二段跳检测
	if jump_just_pressed and can_double_jump and !has_double_jumped and !is_on_floor() and !coyote_time_active:
		velocity.y = double_jump_velocity
		jump_hold_timer = 0.0
		jump_count = 2
		
		has_double_jumped = true
		can_double_jump = false
		
		can_glide = true
		is_double_jump_holding = true
		
		change_state(PlayerState.JUMP)
		return true
	
	return false
## 处理二段跳期间按住跳跃键时的角色旋转效果
func handle_jump2_rotation(fixed_delta):
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
## 由JumpBox触发的弹跳，进入持续二段跳状态并获得水平速度加成
func start_jumpbox_bounce(vertical_force: float):
	# 原有的弹跳处理逻辑保持不变
	velocity.y = -vertical_force
	
	# 刷新空中冲刺限制
	has_dashed_in_air = false
	can_dash = true
	
	# 设置 JumpBox 触发标记
	is_jumpbox_triggered = true
	jumpbox_force_applied = true
	
	# 强制设置二段跳状态
	has_double_jumped = true
	is_double_jump_holding = true
	
	# 设置 JumpBox 持续二段跳状态
	is_jumpbox_continuous_jump = true
	is_jump_interrupt_decaying = false
	
	# 激活速度加成系统
	is_jump2_boost_active = true
	jump2_boost_timer = 0.0
	
	# 立即应用初始速度（如果有输入）
	var move_input = Input.get_axis("left", "right")
	jump2_boost_direction = 1 if move_input > 0 else -1 if move_input < 0 else (1 if is_facing_right else -1)
	if move_input != 0:
		# 关键修改：JumpBox 水平速度保持加法，但应用环境乘数
		velocity.x = (jump_move_speed + jump2_horizontal_boost) * effective_horizontal_multiplier * jump2_boost_direction
	
	# 激活残影效果
	has_jumpbox_afterimage = true
	
	# 确保在 JUMP 状态
	change_state(PlayerState.JUMP)
## 处理JumpBox触发的二段跳水平速度加成，包括持续和衰减阶段
func handle_jump2_boost(fixed_delta):
	if not is_jump2_boost_active:
		return
	
	# 关键修复：只在JUMP2动画期间保持速度加成
	if current_animation == "JUMP2":
		# 更新计时器
		jump2_boost_timer += fixed_delta
		
		var move_input = Input.get_axis("left", "right")
		var current_direction = 1 if move_input > 0 else -1 if move_input < 0 else jump2_boost_direction
		
		# 只在有移动输入时更新方向
		if move_input != 0:
			jump2_boost_direction = current_direction
		
		var total_duration = jump2_boost_duration + jump2_boost_decrease_time
		
		if jump2_boost_timer <= jump2_boost_duration:
			# 持续阶段：保持最大加成速度
			if move_input != 0:
				# 关键修改：应用环境乘数
				velocity.x = (jump_move_speed + jump2_horizontal_boost) * effective_horizontal_multiplier * jump2_boost_direction
			else:
				# 无输入时自然减速（关键修改：应用加速度乘数）
				velocity.x = move_toward(velocity.x, 0, air_control * ground_deceleration * (jump_move_speed + jump2_horizontal_boost) * effective_acceleration_multiplier)
			
		elif jump2_boost_timer <= total_duration:
			# 衰减阶段：线性衰减到基础跳跃速度
			var progress = (jump2_boost_timer - jump2_boost_duration) / jump2_boost_decrease_time
			var current_boost = jump2_horizontal_boost * (1.0 - progress)
			
			if move_input != 0:
				# 应用环境乘数
				velocity.x = (jump_move_speed + current_boost) * effective_horizontal_multiplier * jump2_boost_direction
			else:
				# 无输入时自然减速（应用加速度乘数）
				velocity.x = move_toward(velocity.x, 0, air_control * ground_deceleration * (jump_move_speed + current_boost) * effective_acceleration_multiplier)
			
		else:
			# 加成结束
			is_jump2_boost_active = false
	else:
		# 不在JUMP2动画时，立即结束速度加成
		is_jump2_boost_active = false
## 开始打断JumpBox持续二段跳，进入垂直速度衰减状态
func start_jump_interrupt():
	# 清除JumpBox持续二段跳状态
	is_jumpbox_continuous_jump = false
	
	# 停止旋转
	is_double_jump_holding = false
	animated_sprite.rotation_degrees = 0
	jump2_rotation = 0
	
	# 停止速度加成
	is_jump2_boost_active = false
	
	# 停止残影效果
	has_jumpbox_afterimage = false
	
	# 设置衰减状态
	is_jump_interrupt_decaying = true
	jump_interrupt_decay_timer = 0.0
	
	# 重置二段跳状态，允许再次二段跳
	has_double_jumped = false
	can_double_jump = true
	
	# 刷新空中冲刺限制
	has_dashed_in_air = false
	can_dash = true
## 处理打断后的垂直速度衰减，在指定时间内将垂直速度降为0
func handle_jump_interrupt_decay(fixed_delta):
	if not is_jump_interrupt_decaying:
		return
	
	# 如果在衰减期间被其他状态中断，立即退出
	if current_state == PlayerState.DASH or current_state == PlayerState.HURT or current_state == PlayerState.DIE:
		is_jump_interrupt_decaying = false
		return
	
	# 更新计时器
	jump_interrupt_decay_timer += fixed_delta
	
	# 计算衰减进度
	var progress = min(jump_interrupt_decay_timer / jump2_interrupt_decay_time, 1.0)
	
	# 垂直速度衰减到0
	velocity.y = lerp(velocity.y, 0.0, progress)
	
	# 检测是否衰减完成
	if jump_interrupt_decay_timer >= jump2_interrupt_decay_time:
		is_jump_interrupt_decaying = false
## 在 JumpBox 二段跳结束时调用
func end_jumpbox_continuous_jump():
	is_jumpbox_continuous_jump = false
	is_jumpbox_triggered = false
## 清除JumpBox触发的所有效果（包括速度加成、残影、旋转等）
func clear_jumpbox_effect():
	if is_jumpbox_triggered:
		# 关键修复：彻底刷新二段跳状态
		has_double_jumped = false
		can_double_jump = true
		jump_count = 1  # 重置跳跃计数
		
		
		is_jumpbox_triggered = false
		is_jump2_boost_active = false
		has_jumpbox_afterimage = false
		is_double_jump_holding = false
		
		# 重置JumpBox持续二段跳状态
		is_jumpbox_continuous_jump = false
		is_jump_interrupt_decaying = false  # 注意：这里也需要重置
## 进入滑翔状态，需要满足二段跳后且滑翔能力解锁
func start_glide():
	is_gliding = true
	glide_timer = 0.0
	glide_direction = 1 if is_facing_right else -1
	
	# 设置初始滑翔速度
	velocity.x = glide_direction * glide_init_h_speed
	velocity.y = 0
	
	change_state(PlayerState.GLIDE)
## 退出滑翔状态，根据当前速度切换到跳跃或下落状态
func exit_glide():
	is_gliding = false
	glide_timer = 0.0
	
	# 滑翔退出后，仍然可以再次进入滑翔
	is_double_jump_holding = false
	
	# 根据当前垂直速度决定状态
	if velocity.y < 0:
		change_state(PlayerState.JUMP)
	else:
		change_state(PlayerState.DOWN)
## 处理角色落地逻辑，重置跳跃、滑翔、冲刺等状态
func handle_landing():
	is_jumping = false
	jump_count = 0
	is_gliding = false
	
	# 重置所有跳跃状态
	has_double_jumped = false
	can_double_jump = false
	
	# 关键修改：重置JumpBox相关标记
	is_double_jump_holding = false
	jumpbox_force_applied = false
	
	# 重置打断相关状态
	is_jumpbox_continuous_jump = false
	is_jump_interrupt_decaying = false
	
	# 重置滑翔状态
	can_glide = false
	was_gliding_before_dash = false
	
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
	is_jumping = true
	jump_count = 1
	
	# 重置双重跳跃状态
	has_double_jumped = false
	can_double_jump = true
	
	is_double_jump_holding = Input.is_action_pressed("jump")
	
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
	is_jumping = true
	jump_count = 1
	has_double_jumped = false
	can_double_jump = true
	
	is_double_jump_holding = Input.is_action_pressed("jump")
	
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
	var current_fps = Engine.get_frames_per_second()
	if current_fps < 45:
		afterimage_spawn_rate = lerp(afterimage_spawn_rate, 2.0, fixed_delta * 2.0)
	elif current_fps > 55:
		afterimage_spawn_rate = lerp(afterimage_spawn_rate, 0.8, fixed_delta * 2.0)
	
	afterimage_spawn_rate = clamp(afterimage_spawn_rate, 0.5, 2.0)
	
	match current_state:
		PlayerState.DASH:
			afterimage_timer += fixed_delta
			var dash_type = "black_dash" if black_dash_unlocked else "dash"
			var interval = _get_afterimage_interval(dash_type) * afterimage_spawn_rate
			if afterimage_timer >= interval:
				afterimage_timer = 0
				# ⭐ 关键修复：检查是否是暗影冲刺
				if black_dash_unlocked:
					create_afterimage(PlayerState.DASH, false, "black_dash")  # ⭐ 使用 black_dash 池
				else:
					create_afterimage(PlayerState.DASH, false)  # 普通 dash 池
		PlayerState.SUPERDASH:
			super_dash_afterimage_timer += fixed_delta
			var interval = _get_afterimage_interval("super_dash") * afterimage_spawn_rate
			if super_dash_afterimage_timer >= interval:
				super_dash_afterimage_timer = 0
				create_afterimage(PlayerState.SUPERDASH, false)  # super_dash 池
		_:
			afterimage_timer = 0
	
	# JumpBox 残影（使用独立池）
	if has_jumpbox_afterimage and current_animation == "JUMP2":
		jump2_afterimage_timer += fixed_delta
		var interval = _get_afterimage_interval("jumpbox") * afterimage_spawn_rate
		if jump2_afterimage_timer >= interval:
			jump2_afterimage_timer = 0
			create_afterimage(PlayerState.JUMP, true)  # 标记为 JumpBox 残影
	elif has_jumpbox_afterimage and current_animation != "JUMP2":
		
		has_jumpbox_afterimage = false
		jump2_afterimage_timer = 0
		# 关键修复：JumpBox 残影结束后清理专用池
		clear_jumpbox_afterimage_pool()

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
			return "jumpbox" if is_jumpbox else "dash"
		_:
			return "dash"

func create_afterimage(state: PlayerState, is_jumpbox: bool = false, custom_type: String = ""):
	if Engine.get_frames_per_second() < 45:
		return
	
	if afterimage_trail == null:
		_ensure_afterimage_trail()
	if afterimage_trail != null:
		_create_afterimage_new(state, is_jumpbox, custom_type)
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
	# 无论当前是什么状态，都强制切换到INTERACTIVE状态
	change_state(PlayerState.INTERACTIVE)
	is_in_dialogue = true
	
	# 立即停止水平移动，但保留垂直速度
	velocity.x = 0
	
	# 确保动画立即更新
	update_animation()

# 对话期间处理
func handle_dialogue_physics(fixed_delta):
	velocity.x = 0
	apply_gravity(fixed_delta)

# 对话结束处理
func _on_dialogue_ended():
	is_in_dialogue = false
	
	# 延迟一帧处理，确保所有状态更新完成
	await get_tree().process_frame
	
	if current_state == PlayerState.INTERACTIVE:
		print("Player: 从 INTERACTIVE 状态退出")
		if is_on_floor():
			change_state(PlayerState.IDLE)
		else:
			change_state(PlayerState.DOWN)

# 锁定控制
func lock_control(duration: float, lock_type: String = "general"):
	is_control_locked = true
	control_lock_timer = duration
	set_process_input(false)
	print("玩家控制锁定: 类型=", lock_type, " 持续时间=", duration, "秒")

#锁定控制回调
func _on_control_lock_timeout():
	set_process_input(true)

#endregion

##相机控制相关函数集
#region Signals
# 添加相机偏移函数
func reset_camera_position():
	if phantom_camera:
		var tween = create_tween()
		tween.set_trans(camera_offset_transition_type)
		tween.set_ease(camera_offset_ease_type)
		tween.tween_property(phantom_camera, "follow_offset", Vector2.ZERO, camera_offset_transition_duration)

func start_camera_transition_guard(duration: float = 0.18, max_duration: float = 1.0) -> void:
	# 兼容旧调用：当前改为无副作用保护窗，避免 dead-zone 来回切换引发边界抖动
	if not phantom_camera:
		return
	camera_transition_guard_active = true
	camera_transition_guard_elapsed = 0.0
	camera_transition_guard_min_duration = maxf(duration, 0.01)
	camera_transition_guard_timer = maxf(max_duration, camera_transition_guard_min_duration)

func _update_camera_transition_guard(fixed_delta: float) -> void:
	if not camera_transition_guard_active:
		return
	camera_transition_guard_elapsed += fixed_delta
	camera_transition_guard_timer -= fixed_delta
	if camera_transition_guard_elapsed < camera_transition_guard_min_duration and camera_transition_guard_timer > 0.0:
		return
	camera_transition_guard_active = false


func sync_camera_after_room_teleport() -> void:
	if not phantom_camera:
		return

	var camera := get_viewport().get_camera_2d()
	# 传送前清理残余震动，避免 camera.offset 在新房间首帧造成“抖一下”
	if CameraShakeManager and CameraShakeManager.has_method("stop_shake"):
		CameraShakeManager.stop_shake(phantom_camera)
	if camera:
		camera.offset = Vector2.ZERO

	var desired_center: Vector2 = global_position + phantom_camera.follow_offset
	var clamped_center := _clamp_camera_center_by_limits(desired_center, phantom_camera, camera)

	phantom_camera.global_position = clamped_center
	if phantom_camera.has_method("teleport_position"):
		phantom_camera.teleport_position()

	if camera:
		camera.global_position = clamped_center
		if camera.has_method("reset_smoothing"):
			camera.reset_smoothing()
		if camera.has_method("reset_physics_interpolation"):
			camera.reset_physics_interpolation()

	if CAMERA_TELEPORT_DEBUG:
		print("[CameraTeleportSync] desired=", desired_center, " clamped=", clamped_center)


func _clamp_camera_center_by_limits(target_center: Vector2, pcam: Node, camera: Camera2D) -> Vector2:
	if pcam == null:
		return target_center

	var limit_left: float = float(int(pcam.get("limit_left")))
	var limit_top: float = float(int(pcam.get("limit_top")))
	var limit_right: float = float(int(pcam.get("limit_right")))
	var limit_bottom: float = float(int(pcam.get("limit_bottom")))

	if limit_left <= -CAMERA_LIMIT_DISABLED + 1 and limit_right >= CAMERA_LIMIT_DISABLED - 1 and limit_top <= -CAMERA_LIMIT_DISABLED + 1 and limit_bottom >= CAMERA_LIMIT_DISABLED - 1:
		return target_center

	var viewport_size: Vector2 = get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return target_center

	var zoom: Vector2 = Vector2.ONE
	if camera:
		zoom = camera.zoom
	elif pcam.has_method("get_zoom"):
		zoom = pcam.get_zoom()

	var half_w: float = viewport_size.x * 0.5 / zoom.x
	var half_h: float = viewport_size.y * 0.5 / zoom.y

	var min_x: float = limit_left + half_w
	var max_x: float = limit_right - half_w
	var min_y: float = limit_top + half_h
	var max_y: float = limit_bottom - half_h

	# 当房间可视范围小于屏幕时，锁到中点，避免 clamp 反转导致抖动
	if min_x > max_x:
		min_x = (limit_left + limit_right) * 0.5
		max_x = min_x
	if min_y > max_y:
		min_y = (limit_top + limit_bottom) * 0.5
		max_y = min_y

	return Vector2(clampf(target_center.x, min_x, max_x), clampf(target_center.y, min_y, max_y))

func _is_player_inside_normal_camera_dead_zone() -> bool:
	if not phantom_camera:
		return true
	var target: Node2D = phantom_camera.follow_target
	if not target:
		target = self
	var viewport_size: Vector2 = get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return true

	var viewport_position: Vector2 = (target.get_global_transform_with_canvas().get_origin() + phantom_camera.follow_offset) / viewport_size
	var half_w := camera_transition_dead_zone_backup.x * 0.5
	var half_h := camera_transition_dead_zone_backup.y * 0.5
	var inside_x := viewport_position.x >= (0.5 - half_w) and viewport_position.x <= (0.5 + half_w)
	var inside_y := viewport_position.y >= (0.5 - half_h) and viewport_position.y <= (0.5 + half_h)
	if CAMERA_TELEPORT_DEBUG:
		print("[CameraGuard] viewport=", viewport_position, " inside=", inside_x and inside_y)
	return inside_x and inside_y

## 门传送等瞬移后调用：同步 PhantomCamera2D 与 Camera2D，修复 FRAMED 死区与视口坐标一帧不一致
func sync_phantom_camera_after_teleport() -> void:
	sync_camera_after_room_teleport()

## 强制同步相机位置到玩家位置，忽略限制用于传送后
func force_sync_camera_position_after_teleport() -> void:
	var camera = get_viewport().get_camera_2d()
	if not camera or not phantom_camera:
		return
	
	# 计算期望的相机位置（Camera2D 的 global_position 就是中心点）
	var desired_center = global_position + phantom_camera.follow_offset
	var desired_position = desired_center
	
	# 保存原始限制
	var original_left = camera.limit_left
	var original_top = camera.limit_top
	var original_right = camera.limit_right
	var original_bottom = camera.limit_bottom
	
	if CAMERA_TELEPORT_DEBUG:
		print("DEBUG: 传送后强制同步相机 - 玩家位置:", global_position, " 期望相机位置:", desired_position, " 限制:", original_left, ",", original_top, ",", original_right, ",", original_bottom)
	
	# 临时设置极大限制范围，使相机可以自由移动到目标位置
	camera.limit_left = -CAMERA_LIMIT_DISABLED
	camera.limit_top = -CAMERA_LIMIT_DISABLED
	camera.limit_right = CAMERA_LIMIT_DISABLED
	camera.limit_bottom = CAMERA_LIMIT_DISABLED
	camera.global_position = desired_position
	
	# 等待一帧应用
	await get_tree().process_frame
	
	# 恢复限制（这会clamp相机位置）
	camera.limit_left = original_left
	camera.limit_top = original_top
	camera.limit_right = original_right
	camera.limit_bottom = original_bottom
	
	if CAMERA_TELEPORT_DEBUG:
		print("DEBUG: 相机位置设置后:", camera.global_position)

#endregion

##Hit Stop 相关函数集
#region Signals
# Hit Stop函数
func start_hit_stop(duration: float, intensity: float = 1.0):
	if not hit_stop_enabled or is_hit_stop:
		return
	
	# 设置持续时间
	var actual_duration = duration * intensity
	
	# 开始Hit Stop
	is_hit_stop = true
	hit_stop_timer = 0.0
	saved_time_scale = Engine.time_scale
	Engine.time_scale = 0.0
	
	# 使用真实时间计算Hit Stop结束
	var start_time = Time.get_ticks_msec()
	
	# 创建一个处理Hit Stop结束的函数
	var check_hit_stop_end = func():
		while is_hit_stop:
			var current_time = Time.get_ticks_msec()
			var elapsed = (current_time - start_time) / 1000.0  # 转换为秒
			
			if elapsed >= actual_duration:
				Engine.time_scale = saved_time_scale
				is_hit_stop = false
				break
			
			# 每帧检查一次
			await get_tree().process_frame
	
	# 启动检查协程
	check_hit_stop_end.call()

# Hit Stop结束回调
func _on_hit_stop_timeout():
	if is_hit_stop:
		Engine.time_scale = saved_time_scale
		is_hit_stop = false

# 处理Hit Stop
func handle_hit_stop(fixed_delta):
	if not is_hit_stop:
		return
	
	# 使用真实时间（不受time_scale影响）
	hit_stop_timer += fixed_delta
	
	if hit_stop_timer >= hit_stop_duration_current:
		# 结束Hit Stop
		Engine.time_scale = 1.0
		is_hit_stop = false

# 受伤专用的Hit Stop
func start_hurt_hit_stop():
	start_hit_stop(hurt_hit_stop_duration, hurt_hit_stop_intensity)

# JumpBox 专用的 Hit Stop（使用 tier2 档位）
func start_jumpbox_hit_stop():
	TimerControlManager.hit_stop(2)

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
