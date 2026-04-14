# AfterimagePool.gd
# 残影对象池（独立脚本，避免 Godot 4.x 内部类类型问题）
extends Node

## 残影实例池
var pool: Array[Node2D] = []
## 可用的残影实例
var available: Array[Node2D] = []
## 残影配置（动态类型，避免类型检查）
var config
## 父节点
var parent_node: Node
## 池大小
var pool_size: int = 0

## 初始化（不能使用 _init 带参数，改用普通方法）
func setup(cfg, parent, size: int):
	config = cfg
	parent_node = parent
	pool_size = size
	_initialize_pool()

func _initialize_pool():
	# 预创建残影实例
	for i in range(pool_size):
		var afterimage = _create_afterimage_instance()
		if afterimage:
			afterimage.visible = false
			parent_node.add_child(afterimage)
			pool.append(afterimage)
			available.append(afterimage)

func _create_afterimage_instance() -> Node2D:
	# 创建单个残影实例
	var scene_path: String = ScenePaths.PLAYER_AFTERIMAGE
	if ResourceLoader.exists(scene_path):
		var scene: PackedScene = load(scene_path)
		if scene:
			return scene.instantiate()
		push_error("残影场景加载失败：" + scene_path)
		return null
	else:
		push_error("残影场景不存在：" + scene_path)
		return null

func get_available() -> Node2D:
	# 获取可用的残影实例
	if available.is_empty():
		return null
	
	# ⭐ 关键修复：检查实例有效性，防止返回已释放的实例
	while not available.is_empty():
		var afterimage = available.pop_back()
		if is_instance_valid(afterimage):
			return afterimage
		else:
			pass  # 静默处理
	
	# 所有实例都失效了
	return null

func return_to_pool(afterimage: Node2D):
	# 回收到对象池
	if not afterimage:
		return
	
	var already_in_pool = false
	for item in available:
		if item == afterimage:
			already_in_pool = true
			break
	
	if not already_in_pool:
		available.append(afterimage)
		# 关键修复：确保残影被隐藏和重置
		if afterimage.has_method("reset_afterimage_force"):
			afterimage.reset_afterimage_force()

func expand_pool(additional_count: int):
	# ⭐ 动态扩展对象池大小
	pool_size += additional_count
	
	for i in range(additional_count):
		var afterimage = _create_afterimage_instance()
		if afterimage:
			afterimage.visible = false
			parent_node.add_child(afterimage)
			pool.append(afterimage)
			available.append(afterimage)
