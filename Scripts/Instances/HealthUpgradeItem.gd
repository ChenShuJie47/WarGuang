extends Area2D

@onready var animated_sprite = $AnimatedSprite2D
@onready var collision_shape = $CollisionShape2D

@export var health_increase: int = 1
@export var item_id: String = ""

func _ready():
	body_entered.connect(_on_body_entered)
	
	# 如果已经收集过，则销毁
	if Global.is_item_collected(item_id):
		queue_free()
		return
	
	animated_sprite.play("IDLE")

func _on_body_entered(body):
	if body.is_in_group("player"):
		print("HealthUpgradeItem: 玩家接触道具")
		
		# 禁用碰撞（使用 deferred）
		collision_shape.set_deferred("disabled", true)
		
		# 修复：延迟增加血量，避免物理查询冲突
		var player_ui = get_tree().get_first_node_in_group("player_ui")
		if player_ui:
			# 记录增加前的血量和最大血量
			var old_max_health = Global.player_max_health
			var current_health = player_ui.get_health()
			
			# 修复：使用 call_deferred 延迟调用
			player_ui.call_deferred("increase_max_health", health_increase)
			
			# 等待一帧确保血量单位已创建
			await get_tree().process_frame
			
			# 关键修复：为所有需要恢复的血量单位播放 ADD 动画
			# 新增的血量单位已经在 increase_max_health 中处理了
			# 现在需要为之前受伤的血量单位也播放 ADD 动画
			if current_health < old_max_health:
				# 为之前受伤但现在恢复的血量单位播放 ADD 动画
				for i in range(current_health, old_max_health):
					if i < player_ui.health_units.size():
						var health_unit = player_ui.health_units[i]
						if is_instance_valid(health_unit) and health_unit.has_method("set_state"):
							health_unit.set_state(HealthUnit.HealthState.ADD)
		
		# 在上限更新后再写入“已收集”状态，避免存档落入旧血量上限。
		Global.mark_item_collected(item_id)
		
		# 播放收集动画
		animated_sprite.play("COLLECT")
		
		# 等待动画播放完毕
		await animated_sprite.animation_finished
		
		# 销毁道具
		queue_free()
