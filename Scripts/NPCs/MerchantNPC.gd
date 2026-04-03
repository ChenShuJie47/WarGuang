extends BaseNPC
class_name MerchantNPC

## ============================================
## MerchantNPC - 商人 NPC 专用类
## ============================================

## 动画状态配置
@export_category("Animation States")
## 待机动画
@export var idle_animation: String = "IDLE"
## 对话动画
@export var talk_animation: String = "TALK"
## 高兴动画
@export var happy_animation: String = "HAPPY"
## 生气动画
@export var angry_animation: String = "ANGRY"
## 生气对话动画
@export var angry_talk_animation: String = "ANGRY_TALK"

# 内部变量
var current_mood: Moods = Moods.IDLE  # 当前情绪（默认为待机）
var bought_items: Array[String] = []  # 已购买物品列表
var player_has_purchased: bool = false  # 本次交互是否购买过
var consecutive_no_purchase_count: int = 0  # 连续未购买次数

enum Moods {
	IDLE,    # 待机状态（对应 IDLE 动画）
	HAPPY,   # 高兴状态（对应 HAPPY 动画）
	ANGRY    # 生气状态（对应 ANGRY 动画）
}

# 商品列表配置
var inventory: Array[Dictionary] = [
	{"item_id": "potion_speed", "item_name": "加速药水", "price": 50, "quantity": 99},
	{"item_id": "potion_gravity", "item_name": "重力药水", "price": 100, "quantity": 99}
]

func _ready():
	npc_id = "merchant_01"
	super._ready()
	update_mood(Moods.IDLE)
	print("DEBUG: 商人 NPC 初始化完成 -", npc_id)

## 开始交互（覆盖基类）
func _start_interaction():
	player_has_purchased = false
	
	# 根据情绪决定初始对话
	match current_mood:
		Moods.HAPPY:
			_start_dialogue_with_mood("happy_greeting")
		Moods.ANGRY:
			_start_dialogue_with_mood("angry_greeting")
		Moods.IDLE:
			_start_dialogue_with_mood("normal_greeting")
	
	# 关键修复：交互开始时强制切换到对话动画
	if animated_sprite and animated_sprite.sprite_frames:
		if current_mood == Moods.ANGRY:
			# 生气状态使用 ANGRY_TALK
			if animated_sprite.sprite_frames.has_animation(angry_talk_animation):
				animated_sprite.play(angry_talk_animation)
		else:
			# 其他状态使用 TALK
			if animated_sprite.sprite_frames.has_animation(talk_animation):
				animated_sprite.play(talk_animation)

## 获取情绪名称（调试用）
func _get_mood_name() -> String:
	match current_mood:
		Moods.HAPPY:
			return "HAPPY"
		Moods.ANGRY:
			return "ANGRY"
		Moods.IDLE:
			return "IDLE"
	return "IDLE"

## 根据情绪开始对话
func _start_dialogue_with_mood(mood_state: String):
	var player = get_tree().get_first_node_in_group("player")
	var task_manager = get_node_or_null("/root/TaskManager")
	
	if not player:
		print("DEBUG: 找不到玩家节点")
		return
	
	if not dialogue_resource:
		print("DEBUG: 对话资源为空！请检查场景配置")
		return
	
	# 修复：使用继承的 balloon_scene
	if not balloon_scene:
		push_error("MerchantNPC: balloon_scene 未配置！请在 Inspector 中拖拽 MyBalloon.tscn")
		return
	
	var balloon = balloon_scene.instantiate()
	get_tree().current_scene.add_child(balloon)
	
	# 关键修复：传递 Global 引用而不是具体的钱币数量
	var game_states_dict = {
		"player": player,
		"task_manager": task_manager,
		"npc": self,
		"npc_type": "merchant",
		"mood": mood_state,
		"inventory": inventory,
		"bought_items": bought_items,
		"consecutive_no_purchase_count": consecutive_no_purchase_count,
		"global": Global  # 传递 Global 引用
	}
	
	balloon.start(dialogue_resource, "merchant_start", [game_states_dict])

## 更新商人情绪（公开方法，供对话文件调用）
func update_mood(new_mood: Moods):
	current_mood = new_mood
	
	if not animated_sprite or not animated_sprite.sprite_frames:
		return
	
	match new_mood:
		Moods.HAPPY:
			if animated_sprite.sprite_frames.has_animation(happy_animation):
				animated_sprite.play(happy_animation)
			else:
				animated_sprite.play(idle_animation)
		Moods.ANGRY:
			if animated_sprite.sprite_frames.has_animation(angry_animation):
				animated_sprite.play(angry_animation)
			else:
				animated_sprite.play(idle_animation)
		Moods.IDLE:
			if animated_sprite.sprite_frames.has_animation(idle_animation):
				animated_sprite.play(idle_animation)
			else:
				animated_sprite.play(idle_animation)

## 处理购买成功
func on_purchase_success(item_id: String):
	bought_items.append(item_id)
	player_has_purchased = true
	consecutive_no_purchase_count = 0

## 处理玩家离开（未购买）
func on_player_leave_without_purchase():
	consecutive_no_purchase_count += 1

## 覆盖对话结束处理
func _on_dialogue_ended():
	await get_tree().process_frame
	super._on_dialogue_ended()
	
	# 如果这次交互没有购买，增加计数并判断是否达到 3 次
	if not player_has_purchased:
		on_player_leave_without_purchase()
		
		# 如果达到 3 次，切换到生气状态
		if consecutive_no_purchase_count >= 3:
			update_mood(Moods.ANGRY)
	
	# 重置购买标志
	player_has_purchased = false
	
	_play_default_idle()
