shader_type canvas_item;
render_mode blend_mix;

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float inner_radius : hint_range(0.0, 1.0) = 0.3;
uniform float outer_radius : hint_range(0.0, 1.0) = 0.8;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

void fragment() {
    vec2 uv = SCREEN_UV;
    vec2 center = vec2(0.5, 0.5);
    float dist = distance(uv, center);
    
    // 计算渐变
    float vignette = smoothstep(inner_radius, outer_radius, dist);
    vignette = vignette * intensity;
    
    // 获取屏幕纹理
    vec4 screen_color = textureLod(screen_texture, uv, 0.0);
    
    // 混合屏幕颜色和Vignette颜色
    vec4 final_color = screen_color;
    final_color.rgb = mix(final_color.rgb, color.rgb, vignette * color.a);
    
    COLOR = final_color;
}