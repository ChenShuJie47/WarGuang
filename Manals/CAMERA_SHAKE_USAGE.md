# CameraShakeManager 使用指南

## 📋 预设类型说明

### Y 轴抖动（垂直方向为主）

#### `y_strong` - Y 轴强抖动
- **用途**：落地、重击、地震等强烈垂直冲击
- **默认参数**：
  - 强度：50.0
  - 时长：0.4s
  - 频率：40Hz
  - 方向：(0.2, 0.8) - 主要 Y 轴
  - 衰减：缓慢

#### `y_weak` - Y 轴弱抖动
- **用途**：JumpBox 触发、小跳跃等轻微垂直运动
- **默认参数**：
  - 强度：30.0
  - 时长：0.2s
  - 频率：90Hz
  - 方向：(0.3, 0.6) - 主要 Y 轴
  - 衰减：快速

---

### X 轴抖动（水平方向为主）

#### `x_strong` - X 轴强抖动
- **用途**：撞墙、水平冲击、击退
- **默认参数**：
  - 强度：40.0
  - 时长：0.3s
  - 频率：40Hz
  - 方向：(0.6, 0.3) - 主要 X 轴
  - 衰减：线性

#### `x_weak` - X 轴弱抖动
- **用途**：擦伤、轻微水平碰撞
- **默认参数**：
  - 强度：20.0
  - 时长：0.2s
  - 频率：60Hz
  - 方向：(0.7, 0.3) - 主要 X 轴
  - 衰减：快速

---

### 全方位抖动（通用）

#### `general_strong` - 全方位强抖动
- **用途**：重伤、爆炸、强烈冲击
- **默认参数**：
  - 强度：40.0
  - 时长：0.4s
  - 频率：60Hz
  - 方向：(1, 1) - 全方位
  - 衰减：快速

#### `general_weak` - 全方位弱抖动
- **用途**：普通受伤、一般冲击
- **默认参数**：
  - 强度：25.0
  - 时长：0.2s
  - 频率：80Hz
  - 方向：(1, 1) - 全方位
  - 衰减：缓慢

---

## 🎯 使用示例

### 基础用法

```gdscript
# Y 轴强抖动（落地）
CameraShakeManager.shake("y_strong", phantom_camera)

# Y 轴弱抖动（JumpBox）
CameraShakeManager.shake("y_weak", phantom_camera)

# X 轴强抖动（撞墙）
CameraShakeManager.shake("x_strong", phantom_camera)

# 全方位强抖动（重伤）
CameraShakeManager.shake("general_strong", phantom_camera)
```

### 多抖动叠加

```gdscript
# 玩家落地同时受到爆炸冲击
CameraShakeManager.shake("y_strong", phantom_camera)  # 落地抖动
CameraShakeManager.shake("general_strong", phantom_camera)  # 爆炸抖动
# 结果：两个抖动效果会叠加！
```

### 自定义参数

```gdscript
# 完全自定义抖动
CameraShakeManager.shake_custom({
	"intensity": 60.0,      # 强度
	"duration": 0.5,        # 时长（秒）
	"frequency": 50.0,      # 频率（Hz）
	"direction": Vector2(0.5, 0.5),  # 方向
	"falloff_type": 1       # 衰减：0=线性，1=快速，2=缓慢
}, phantom_camera)
```

---

## 🔧 参数调整

### 在 Inspector 中调整

1. 选中 `CameraShakeManager` 节点
2. 在 Inspector 中找到对应分类：
   - Y 轴抖动（垂直方向）
   - X 轴抖动（水平方向）
   - 全方位抖动（通用）
3. 修改参数：
   - `shake_y_strong_intensity`: Y 轴强抖动强度
   - `shake_y_strong_duration`: Y 轴强抖动时长
   - `shake_y_strong_frequency`: Y 轴强抖动频率
   - `shake_y_strong_falloff`: Y 轴强抖动衰减类型

### 衰减类型说明

- **0 - LINEAR（线性）**：匀速衰减，从强到弱均匀过渡
- **1 - FAST（快速）**：先快速衰减，后缓慢
- **2 - SLOW（缓慢）**：先缓慢衰减，后快速

---

## ✅ 优势

### 1. 高度复用
- 不同场景可以调用相同的抖动类型
- 例如：落地和重击都可以用 `y_strong`

### 2. 易于调整
- 所有参数在 Inspector 中可视化调整
- 无需修改代码

### 3. 支持叠加
- 多个抖动源同时调用会叠加
- 自动处理衰减和清理

### 4. 性能友好
- 无抖动时不运行计算
- 基于频率更新，避免每帧计算

---

## 📊 参数参考表

| 抖动类型 | 强度 | 时长 | 频率 | 方向 X | 方向 Y | 衰减 |
|---------|------|------|------|--------|--------|------|
| y_strong | 50 | 0.4s | 40Hz | 0.2 | 0.8 | SLOW |
| y_weak | 30 | 0.2s | 90Hz | 0.3 | 0.6 | FAST |
| x_strong | 40 | 0.3s | 40Hz | 0.6 | 0.3 | LINEAR |
| x_weak | 20 | 0.2s | 60Hz | 0.7 | 0.3 | FAST |
| general_strong | 40 | 0.4s | 60Hz | 1.0 | 1.0 | FAST |
| general_weak | 25 | 0.2s | 80Hz | 1.0 | 1.0 | SLOW |

---

## 🎮 实际应用场景

### 玩家受伤
```gdscript
# 普通受伤
CameraShakeManager.shake("general_weak", phantom_camera)

# 重伤/阴影伤害
CameraShakeManager.shake("general_strong", phantom_camera)
```

### 环境互动
```gdscript
# JumpBox 触发
CameraShakeManager.shake("y_weak", phantom_camera)

# 撞墙
CameraShakeManager.shake("x_strong", phantom_camera)

# 落地
if land_velocity > threshold:
	CameraShakeManager.shake("y_strong", phantom_camera)
```

### 敌人/BOSS
```gdscript
# 小怪死亡
CameraShakeManager.shake("general_weak", camera)

# BOSS 重击
CameraShakeManager.shake("y_strong", camera)
CameraShakeManager.shake("general_strong", camera)  # 叠加！
```
