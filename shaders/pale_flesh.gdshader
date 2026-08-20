shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 albedo : source_color = vec4(0.58, 0.9, 0.34, 1.0);
uniform sampler2D flesh_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float pulse : hint_range(0.2, 4.0) = 1.35;
uniform float emission_energy = 1.15;
uniform float tex_scale = 0.55;

void fragment() {
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 wn = abs(normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz));
	wn = max(wn, vec3(0.001));
	wn /= wn.x + wn.y + wn.z;
	vec3 tx = texture(flesh_tex, wp.zy * tex_scale).rgb;
	vec3 ty = texture(flesh_tex, wp.xz * tex_scale).rgb;
	vec3 tz = texture(flesh_tex, wp.xy * tex_scale).rgb;
	vec3 texc = tx * wn.x + ty * wn.y + tz * wn.z;
	float beat = 0.62 + 0.38 * sin(TIME * pulse + wp.y * 2.2);
	vec3 col = mix(albedo.rgb, texc, 0.72);
	ALBEDO = col;
	ROUGHNESS = 0.38;
	METALLIC = 0.04;
	RIM = 0.55;
	RIM_TINT = 0.7;
	EMISSION = col * emission_energy * beat * 0.7;
}
