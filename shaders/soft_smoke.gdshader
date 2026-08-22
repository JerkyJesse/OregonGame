shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 color : source_color = vec4(0.18, 0.16, 0.14, 0.4);
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform float softness = 2.2;

void fragment() {
	float raw = texture(depth_tex, SCREEN_UV).x;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, raw);
	vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view.xyz /= view.w;
	float scene_z = -view.z;
	float frag_z = -VERTEX.z;
	float zfade = clamp((scene_z - frag_z) / max(softness, 0.001), 0.0, 1.0);
	float radial = 1.0 - clamp(length(UV - vec2(0.5)) * 2.0, 0.0, 1.0);
	radial = pow(radial, 1.4);
	ALBEDO = color.rgb * COLOR.rgb;
	ALPHA = color.a * COLOR.a * radial * zfade;
}
