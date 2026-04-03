extends Node

# 能力解锁信号
signal dash_unlocked()
signal double_jump_unlocked() 
signal glide_unlocked()
signal black_dash_unlocked()  # 新增：强化冲刺解锁信号
signal wall_grip_unlocked()  # 新增攀墙能力解锁信号
signal super_dash_unlocked()

# 单例实例
static var instance: EventBus

func _ready():
	instance = self
	print("EventBus 初始化完成")
	
	# 添加这行来"使用"信号，消除警告
	_use_signals()

# 这个函数只是为了使用信号，避免警告
func _use_signals():
	# 这些调用不会执行，只是为了让Godot知道信号被"使用"了
	if false:
		dash_unlocked.emit()
		double_jump_unlocked.emit()
		glide_unlocked.emit()
		black_dash_unlocked.emit()
		wall_grip_unlocked.emit()
		super_dash_unlocked.emit()
