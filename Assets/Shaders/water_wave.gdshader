shader_type canvas_item;

// ========== 基础水波参数（由 GDScript 传递） ==========
// 波浪振幅（像素）- 控制波浪起伏的最大高度
// 取值范围：0.0 ~ 50.0，推荐 3.0 ~ 15.0
uniform float amplitude = 7.0;

// 波浪频率（弧度/像素）- 控制波浪密度
// 取值范围：0.01 ~ 20.0，推荐 0.1 ~ 1.0
uniform float frequency = 2.0;

// 波浪速度（弧度/秒）- 控制波浪移动速度
// 取值范围：0.0 ~ 10.0，推荐 0.5 ~ 3.0
uniform float speed = 2.0;

// 水面位置（Y 坐标）- 相对于多边形顶部
// 通常为 -surface_height / 2.0
uniform float water_surface_y = -50.0;

// 影响范围（像素）- 水面附近多大范围内有波浪效果
// 通常为 surface_height * 0.3（高度的 30%）
uniform float influence_range = 30.0;

void vertex() {
	vec2 position = VERTEX;
	
	// 计算顶点到水面的距离
	float distance_to_surface = abs(position.y - water_surface_y);
	
	// 计算衰减因子（距离越远影响越小）
	float falloff = 1.0 - smoothstep(0.0, influence_range, distance_to_surface);
	
	// 基础波浪（正弦曲线）
	float offset = sin(position.x * frequency + TIME * speed) * amplitude;
	
	// 应用衰减（只有水面附近有波动）
	position.y += offset * falloff;
	
	VERTEX = position;
}
