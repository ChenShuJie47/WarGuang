extends BaseNPC
class_name MasterNPC

## 动画状态配置
@export_category("Animation States")
@export var idle_animation: String = "IDLE"
@export var talk_animation: String = "TALK"

func _ready():
	npc_id = "master_01"
	super._ready()
	_play_default_idle()

## 开始交互
func _start_interaction():
	print("DEBUG MasterNPC: 开始交互:", npc_id)
	
	var player = get_tree().get_first_node_in_group("player")
	var task_manager = get_node_or_null("/root/TaskManager")
	
	if not player:
		return
	
	if not dialogue_resource:
		return
	
	# 切换到对话动画
	if animated_sprite and animated_sprite.sprite_frames:
		if animated_sprite.sprite_frames.has_animation(talk_animation):
			play_animation(talk_animation)
	
	# 根据对话次数播放不同内容
	var dialogue_count = TaskManager.get_npc_dialogue_count(npc_id)
	print("DEBUG MasterNPC: 当前对话次数:", dialogue_count)
	
	# 修复：使用继承的 balloon_scene
	if not balloon_scene:
		push_error("MasterNPC: balloon_scene 未配置！请在 Inspector 中拖拽 MyBalloon.tscn")
		return
	
	var balloon = balloon_scene.instantiate()
	get_tree().current_scene.add_child(balloon)
	
	if dialogue_count == 0:
		# 第一次：授予除暗影冲刺外的所有能力
		_grant_abilities_except_black_dash(player)
		balloon.start(dialogue_resource, "first_meeting", [])
	elif dialogue_count == 1:
		# 第二次：授予暗影冲刺能力
		_grant_black_dash_ability(player)
		balloon.start(dialogue_resource, "second_meeting", [])
	else:
		# 后续：直接结束
		balloon.start(dialogue_resource, "no_more_teachings", [])
	
	# 记录对话次数
	if task_manager:
		task_manager.record_npc_dialogue(npc_id)

## 授予除暗影冲刺外的所有能力
func _grant_abilities_except_black_dash(player):
	if player.has_method("unlock_ability"):
		player.unlock_ability("dash")
		player.unlock_ability("double_jump")
		player.unlock_ability("glide")
		player.unlock_ability("wall_grip")
		player.unlock_ability("super_dash")
	
	# 更新全局数据
	Global.unlock_ability("dash")
	Global.unlock_ability("double_jump")
	Global.unlock_ability("glide")
	Global.unlock_ability("wall_grip")
	Global.unlock_ability("super_dash")
	
	print("DEBUG MasterNPC: 授予除暗影冲刺外的所有能力")

## 授予暗影冲刺能力
func _grant_black_dash_ability(player):
	if player.has_method("unlock_ability"):
		player.unlock_ability("black_dash")
	
	# 更新全局数据
	Global.unlock_ability("black_dash")
	
	print("DEBUG MasterNPC: 授予暗影冲刺能力")

## 对话结束处理
func _on_dialogue_ended():
	await get_tree().process_frame
	super._on_dialogue_ended()
	_play_default_idle()
