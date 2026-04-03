# LightingManager.gd
extends Node

## UI点光源的分组名称
var point_light_group = "ui_point_lights"
## 存储活动的灯光tween动画
var active_tweens = {}
## 存储灯光的原始能量值，用于恢复
var original_light_energies = {}

## 初始化函数
func _ready():
	## 关键修复：设置为始终处理模式，不受游戏暂停影响
	process_mode = Node.PROCESS_MODE_ALWAYS

## 创建UI场景的灯光呼吸效果
func create_breathing_effect():
	stop_all_light_effects()
	
	## 等待一帧确保所有操作完成
	await get_tree().process_frame
	
	var lights = get_tree().get_nodes_in_group(point_light_group)
	for light in lights:
		if light is PointLight2D and is_instance_valid(light):
			## 保存原始能量值
			if not original_light_energies.has(light.get_instance_id()):
				original_light_energies[light.get_instance_id()] = light.energy
			## 创建呼吸效果
			var tween = create_tween()
			tween.set_loops()  # 关键：设置循环
			
			## 关键修复：使用不同的过渡和缓动类型使呼吸更自然
			tween.set_trans(Tween.TRANS_SINE)
			tween.set_ease(Tween.EASE_IN_OUT)
			
			tween.tween_property(light, "energy", 1.3, 1.5)
			tween.tween_property(light, "energy", 0.8, 1.5)
			
			active_tweens[light.get_instance_id()] = tween

## 停止所有灯光效果
func stop_all_light_effects():
	for instance_id in active_tweens:
		var tween = active_tweens[instance_id]
		if tween and is_instance_valid(tween):
			tween.kill()
	active_tweens.clear()

## 调暗灯光（用于对话框打开等场景）
func dim_lights(target_energy: float = 0.0, duration: float = 0.3):
	stop_all_light_effects()
	
	var lights = get_tree().get_nodes_in_group(point_light_group)
	for light in lights:
		if light is PointLight2D and is_instance_valid(light):
			if not original_light_energies.has(light.get_instance_id()):
				original_light_energies[light.get_instance_id()] = light.energy
			
			var tween = create_tween()
			tween.tween_property(light, "energy", target_energy, duration)

## 恢复灯光到原始状态
func restore_lights(duration: float = 0.3):
	stop_all_light_effects()
	
	var lights = get_tree().get_nodes_in_group(point_light_group)
	for light in lights:
		if light is PointLight2D and is_instance_valid(light):
			var original_energy = original_light_energies.get(light.get_instance_id(), 1.0)
			var tween = create_tween()
			tween.tween_property(light, "energy", original_energy, duration)

## 重置灯光到默认状态
func reset_lights():
	stop_all_light_effects()
	
	var lights = get_tree().get_nodes_in_group(point_light_group)
	for light in lights:
		if light is PointLight2D and is_instance_valid(light):
			light.energy = 1.0
			original_light_energies[light.get_instance_id()] = 1.0

## 设置UI场景的灯光呼吸效果（统一函数）
func setup_ui_breathing_effect(root_node: Node):
	## 查找场景中的所有PointLight2D节点
	var point_lights = _find_nodes_by_type(root_node, "PointLight2D")
	
	for light in point_lights:
		if light is PointLight2D:
			## 确保灯光能量为默认值
			light.energy = 1.0
			## 如果灯光不在ui_point_lights组中，则添加到组中
			if not light.is_in_group("ui_point_lights"):
				light.add_to_group("ui_point_lights")
	
	## 停止所有现有灯光效果
	stop_all_light_effects()
	
	## 等待一帧确保灯光分组更新
	await get_tree().process_frame
	
	## 恢复灯光到原始状态
	restore_lights(0.1)
	
	## 创建呼吸效果
	create_breathing_effect()

## 辅助函数 - 递归查找指定类型的节点
func _find_nodes_by_type(root: Node, type: String) -> Array:
	var result = []
	
	## 检查当前节点是否为目标类型
	if root.get_class() == type:
		result.append(root)
	
	## 递归检查所有子节点
	for child in root.get_children():
		result.append_array(_find_nodes_by_type(child, type))
	
	return result
