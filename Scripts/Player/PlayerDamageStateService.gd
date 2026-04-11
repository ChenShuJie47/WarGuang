extends RefCounted
class_name PlayerDamageStateService

const DAMAGE_NORMAL := 0
const DAMAGE_SHADOW := 1
const DAMAGE_WARP_NORMAL := 2
const DAMAGE_WARP_SHADOW := 3

# 非致命受伤的通用状态设置：无敌、Hit Stop、僵直与低血量延迟检查。
static func apply_nonlethal_damage_state(player: Node, damage_type: int, new_health: int) -> void:
	player.is_invincible = true
	player.start_hurt_hit_stop()
	player.hurt_timer = player.hurt_stun_time
	player.invincible_timer = player.hurt_invincible_time
	
	if new_health <= 1:
		_schedule_low_health_debug(player, damage_type)

# 按伤害类型播放受伤视觉反馈。
static func play_hurt_visual(player: Node, damage_type: int) -> void:
	match damage_type:
		DAMAGE_NORMAL:
			player.start_normal_hurt_effect()
		DAMAGE_SHADOW:
			player.start_shadow_hurt_effect()
		DAMAGE_WARP_NORMAL:
			player.start_warp_hurt_effect(false)
		DAMAGE_WARP_SHADOW:
			player.start_warp_hurt_effect(true)

# 传送伤害是否需要进入传送倒计时。
static func should_start_warp_timer(damage_type: int) -> bool:
	return damage_type == DAMAGE_WARP_NORMAL or damage_type == DAMAGE_WARP_SHADOW

static func _schedule_low_health_debug(player: Node, damage_type: int) -> void:
	var hurt_duration := 0.8
	if player.vignette_effect and player.vignette_effect.has_method("get_hurt_duration"):
		var is_shadow_hurt := damage_type == DAMAGE_SHADOW or damage_type == DAMAGE_WARP_SHADOW
		hurt_duration = player.vignette_effect.get_hurt_duration(is_shadow_hurt)
	
	player.get_tree().create_timer(0.05).timeout.connect(func():
		player.is_about_to_be_hurt = false
		player.get_tree().create_timer(hurt_duration * 0.8).timeout.connect(func():
			if player.player_ui and player.player_ui.get_health() <= 1:
				print("Player: 受伤效果播放中，检测到低血量，准备过渡")
		)
	)
