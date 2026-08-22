shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 color : source_color = vec4(0.55, 0.32, 0.12, 0.16);

void fragment() {
	float fx = smoothstep(0.0, 0.22, UV.x) * smoothstep(1.0, 0.78, UV.x);
	float fy = smoothstep(0.0, 0.18, UV.y) * smoothstep(1.0, 0.45, UV.y);
	float a = color.a * fx * fy;
	ALBEDO = color.rgb;
	EMISSION = color.rgb * 0.35;
	ALPHA = a;
}
