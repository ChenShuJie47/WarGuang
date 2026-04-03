extends Node
## 环境管理器 - 管理所有环境效果和乘数配置
## 作为 Autoload 使用，在 project.godot 中注册
## 
## 功能说明:
## 1. 存储当前环境的乘数配置（由场景脚本提供）
## 2. 通知 Player 更新乘数
## 3. 处理环境切换时的过渡效果
## 
## 数据流向：
## WaterSurface.gd (场景脚本) → set_environment_multipliers() → Player.gd

## 当前环境的乘数字典
var current_multipliers: Dictionary = {
	"horizontal": 1.0,
	"vertical": 1.0,
	"gravity": 1.0,
	"max_fall": 1.0,
	"acceleration": 1.0
}

## 设置环境乘数（由场景脚本调用，如 WaterSurface.gd）
## horizontal: 水平速度乘数
## vertical: 垂直速度乘数
## gravity: 重力乘数
## max_fall: 最大下落速度乘数
## acceleration: 加速度乘数
func set_environment_multipliers(horizontal: float, vertical: float, gravity: float, max_fall: float, acceleration: float):
	current_multipliers = {
		"horizontal": horizontal,
		"vertical": vertical,
		"gravity": gravity,
		"max_fall": max_fall,
		"acceleration": acceleration
	}
	
	print("EnvironmentManager: 环境乘数更新 - 水平:", horizontal, ", 垂直:", vertical, ", 重力:", gravity)
	
	# 通知所有玩家
	_notify_players()

## 清除环境效果（恢复默认值）
func clear_environment():
	set_environment_multipliers(1.0, 1.0, 1.0, 1.0, 1.0)
	print("EnvironmentManager: 环境效果已清除")

## 通知玩家更新乘数
func _notify_players():
	var players = get_tree().get_nodes_in_group("player")
	for player in players:
		if player.has_method("set_environment_multipliers"):
			player.set_environment_multipliers(
				current_multipliers["horizontal"],
				current_multipliers["vertical"],
				current_multipliers["gravity"],
				current_multipliers["max_fall"],
				current_multipliers["acceleration"]
			)

## 获取当前环境乘数（用于调试）
func get_current_multipliers() -> Dictionary:
	return current_multipliers

## 获取环境状态描述（用于调试）
func get_environment_status() -> String:
	if current_multipliers["horizontal"] == 1.0 and \
	   current_multipliers["vertical"] == 1.0 and \
	   current_multipliers["gravity"] == 1.0:
		return "无环境效果"
	else:
		return "环境效果生效中"
