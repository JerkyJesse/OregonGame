shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

#include "res://shaders/noise.gdshaderinc"

uniform vec4 albedo : source_color = vec4(0.24, 0.22, 0.18, 1.0);
uniform vec4 stain : source_color = vec4(0.14, 0.10, 0.08, 1.0);
uniform vec4 rust : source_color = vec4(0.46, 0.22, 0.08, 1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.78;
uniform float metallic : hint_range(0.0, 1.0) = 0.22;
uniform float scale = 0.22;
uniform float rust_amount : hint_range(0.0, 1.0) = 0.32;
uniform float emission_energy = 0.0;
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform sampler2D grit_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float tex_mix : hint_range(0.0, 1.0) = 0.4;
uniform float wetness : hint_range(0.0, 1.0) = 0.0;
uniform float bump : hint_range(0.0, 4.0) = 1.35;
uniform float panel_size = 0.0;
uniform float displace = 0.0;

varying vec3 world_pos;
varying vec3 world_nrm;

vec3 triplanar(vec3 wp, vec3 wn, float s) {
	vec3 n = abs(wn);
	n = max(n, vec3(0.001));
	n /= n.x + n.y + n.z;
	vec3 tx = texture(grit_tex, wp.zy * s).rgb;
	vec3 ty = texture(grit_tex, wp.xz * s).rgb;
	vec3 tz = texture(grit_tex, wp.xy * s).rgb;
	return tx * n.x + ty * n.y + tz * n.z;
}

float panel_line(vec3 wp, float size) {
	if (size <= 0.01) {
		return 0.0;
	}
	vec3 m = abs(mod(wp + vec3(size) * 0.5, size) - size * 0.5);
	float seam = 1.0 - smoothstep(0.0, 0.05, min(min(m.x, m.y), m.z));
	return seam;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	if (displace > 0.001) {
		float n = fbm(world_pos * 0.07) * 0.7 + noise(world_pos * 0.31) * 0.3;
		VERTEX.y += (n - 0.42) * displace;
		world_pos.y += (n - 0.42) * displace;
	}
}

void fragment() {
	vec3 wp = world_pos;
	vec3 wn = normalize(world_nrm);
	float n = noise(wp * scale);
	float n2 = noise(wp * scale * 3.4 + vec3(9.0, 4.0, 2.0));
	float n3 = noise(wp * scale * 9.0);
	float fb = fbm(wp * scale * 0.55);
	float rust_mask = smoothstep(1.0 - rust_amount, 1.04, n * 0.55 + n2 * 0.45 + fb * 0.15);
	vec3 texc = triplanar(wp, wn, scale * 0.85);
	float h = dot(texc, vec3(0.3, 0.5, 0.2)) * 0.7 + n3 * 0.3;
	vec3 col = mix(albedo.rgb, stain.rgb, n * 0.5 + n3 * 0.2);
	col = mix(col, rust.rgb, rust_mask * rust_amount);
	col = mix(col, col * texc * 1.45, tex_mix);
	float seam = panel_line(wp, panel_size);
	col *= 1.0 - seam * 0.22;
	float ndv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float wear = pow(1.0 - ndv, 2.8);
	col = mix(col, mix(col, rust.rgb, 0.55), wear * 0.28 * (0.4 + rust_amount));
	float puddle = smoothstep(0.58, 0.84, fb) * wetness;
	col = mix(col, col * vec3(0.55, 0.52, 0.48), puddle * 0.45);
	ALBEDO = col;
	float rough = clamp(roughness + n * 0.18 - rust_mask * 0.12 + seam * 0.25, 0.04, 1.0);
	rough = mix(rough, 0.07, puddle);
	ROUGHNESS = rough;
	METALLIC = clamp(metallic - rust_mask * 0.28 + n3 * 0.04 + puddle * 0.55, 0.0, 1.0);
	SPECULAR = mix(0.4, 0.85, puddle);
	CLEARCOAT = puddle * 0.85;
	CLEARCOAT_ROUGHNESS = 0.06;
	AO = mix(0.52, 1.0, fb);
	AO_LIGHT_AFFECT = 0.55;
	EMISSION = emission_color.rgb * emission_energy;
	vec3 dpdx = dFdx(VERTEX);
	vec3 dpdy = dFdy(VERTEX);
	float dhdx = dFdx(h);
	float dhdy = dFdy(h);
	vec3 r1 = cross(dpdy, NORMAL);
	vec3 r2 = cross(NORMAL, dpdx);
	float det = max(dot(dpdx, r1), 0.0001);
	vec3 grad = (r1 * dhdx + r2 * dhdy) / det;
	NORMAL = normalize(NORMAL - grad * bump * 0.55);
}
