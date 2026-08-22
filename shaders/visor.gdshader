shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 albedo : source_color = vec4(1.0, 0.5, 0.12, 1.0);
uniform float energy = 3.4;

void fragment() {
	float ndv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fres = pow(1.0 - ndv, 2.35);
	vec3 col = albedo.rgb;
	ALBEDO = col * 0.16;
	ROUGHNESS = 0.045;
	METALLIC = 0.92;
	SPECULAR = 1.0;
	RIM = 0.9;
	RIM_TINT = 0.15;
	EMISSION = col * (energy * 0.5 + fres * energy * 1.25);
	CLEARCOAT = 0.65;
	CLEARCOAT_ROUGHNESS = 0.04;
}
