shader_type canvas_item;

// 残影颜色（包含透明度）
uniform vec4 color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
// 生命周期（秒）- ⭐ 由 Godot 传入
uniform float lifetime;
// ⭐ 淡出时长（秒）- ⭐ 新增
uniform float fade_duration = 0.4;
// ⭐ 淡入时长（秒）- ⭐ 新增
uniform float fade_in_duration = 0.1;
// 是否启用缩放效果 - ⭐ 由 Godot 传入
uniform bool scale_effect;
// ⭐ 是否使用纯色块 - ⭐ 由 Godot 传入
uniform bool solid_color;
// ⭐ 淡出缩放效果开关 - ⭐ 由 Godot 传入
uniform bool fade_scale_effect;
// 由脚本驱动的实例已过时间（秒）
uniform float elapsed_time = 0.0;
// ⭐ 新增：移动方向（归一化向量）
uniform vec2 move_direction = vec2(0.0, 0.0);
// ⭐ 新增：移动距离（像素）
uniform float move_distance = 50.0;

void vertex() {
	// 计算移动进度（覆盖显示+淡出全过程）
	float total_duration = max(0.001, lifetime + fade_duration);
	float move_progress = clamp(elapsed_time / total_duration, 0.0, 1.0);

	// 淡出期间执行顶点缩小：1.0 -> 0.0（与 fade_duration 同步）
	float vertex_scale = 1.0;
	if (scale_effect && fade_scale_effect) {
		vertex_scale = 1.0 - clamp((elapsed_time - lifetime) / fade_duration, 0.0, 1.0);
		vertex_scale = max(0.01, vertex_scale);
	}

	// 先按中心缩小，再施加位移
	VERTEX *= vertex_scale;
	VERTEX += move_direction * move_progress * move_distance;
}

void fragment() {
	// ⭐ 淡入进度计算（0 ~ fade_in_duration）
	float safe_fade_in = max(0.001, fade_in_duration);
	float fade_in_progress = clamp(elapsed_time / safe_fade_in, 0.0, 1.0);
	
	// ⭐ 关键修复：透明度控制逻辑（三阶段，全部在 Shader 中自动计算）
	// 阶段 1: 淡入 (0 ~ fade_in_duration): 透明度 0→1
	// 阶段 2: 正常显示 (fade_in_duration ~ lifetime): 透明度保持 1.0
	// 阶段 3: 淡出 (lifetime 之后): 自动计算 1→0
	float display_alpha;
	if (elapsed_time < fade_in_duration) {
		display_alpha = fade_in_progress;  // 淡入阶段：0→1
	} else if (elapsed_time < lifetime) {
		display_alpha = 1.0;  // 正常显示：保持 1.0
	} else {
		// 淡出阶段：自动计算 alpha
		display_alpha = 1.0 - clamp((elapsed_time - lifetime) / fade_duration, 0.0, 1.0);
	}
	
	vec4 tex_color = texture(TEXTURE, UV);

	// 根据 solid_color 决定是否使用纯色块
	vec3 final_color;
	if (solid_color) {
		final_color = color.rgb;  // 纯色块
	} else {
		final_color = tex_color.rgb * color.rgb;  // 完整纹理
	}
	
	// 输出最终颜色（透明度由 Shader 自动计算）
	// ⭐ 关键修复：纯色块时也叠乘纹理 alpha，以保留轮廓
	float final_alpha;
	if (solid_color) {
		// 使用纹理 alpha * 颜色 alpha，避免出现整块矩形
		final_alpha = tex_color.a * color.a * display_alpha;
	} else {
		final_alpha = tex_color.a * color.a * display_alpha;  // 完整纹理：两者相乘
	}
	COLOR = vec4(final_color, final_alpha);
}
