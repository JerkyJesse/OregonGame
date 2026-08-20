shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 albedo : source_color = vec4(0.24, 0.22, 0.18, 1.0);
uniform vec4 stain : source_color = vec4(0.14, 0.10, 0.08, 1.0);
uniform vec4 rust : source_color = vec4(0.46, 0.22, 0.08, 1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.78;
uniform float metallic : hint_range(0.0, 1.0) = 0.22;
uniform float scale = 0.22;
uniform float rust_amount : hint_range(0.0, 1.0) = 0.32;
uniform float emission_energy = 0.0;
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.11, 0.17, 0.23));
	p += dot(p, p.yzx + 19.19);
	return fract((p.x + p.y) * p.z);
}

float noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(hash(i), hash(i + vec3(1.0, 0.0, 0.0)), f.x),
			mix(hash(i + vec3(0.0, 1.0, 0.0)), hash(i + vec3(1.0, 1.0, 0.0)), f.x), f.y),
		mix(mix(hash(i + vec3(0.0, 0.0, 1.0)), hash(i + vec3(1.0, 0.0, 1.0)), f.x),
			mix(hash(i + vec3(0.0, 1.0, 1.0)), hash(i + vec3(1.0, 1.0, 1.0)), f.x), f.y),
		f.z);
}

void fragment() {
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float n = noise(wp * scale);
	float n2 = noise(wp * scale * 3.4 + vec3(9.0, 4.0, 2.0));
	float n3 = noise(wp * scale * 9.0);
	float rust_mask = smoothstep(1.0 - rust_amount, 1.02, n * 0.62 + n2 * 0.48);
	vec3 col = mix(albedo.rgb, stain.rgb, n * 0.55 + n3 * 0.18);
	col = mix(col, rust.rgb, rust_mask * rust_amount);
	ALBEDO = col;
	ROUGHNESS = clamp(roughness + n * 0.2 - rust_mask * 0.1, 0.18, 1.0);
	METALLIC = clamp(metallic - rust_mask * 0.22 + n3 * 0.05, 0.0, 1.0);
	EMISSION = emission_color.rgb * emission_energy;
}
