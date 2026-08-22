shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 albedo : source_color = vec4(0.58, 0.9, 0.34, 1.0);
uniform sampler2D flesh_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float pulse : hint_range(0.2, 4.0) = 1.35;
uniform float emission_energy = 1.15;
uniform float tex_scale = 0.55;

varying vec3 world_pos;
varying vec3 world_nrm;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float swell = 0.012 * sin(TIME * pulse + VERTEX.y * 4.0);
	VERTEX += NORMAL * swell;
}

void fragment() {
	vec3 wn = abs(normalize(world_nrm));
	wn = max(wn, vec3(0.001));
	wn /= wn.x + wn.y + wn.z;
	vec3 wp = world_pos;
	vec3 tx = texture(flesh_tex, wp.zy * tex_scale).rgb;
	vec3 ty = texture(flesh_tex, wp.xz * tex_scale).rgb;
	vec3 tz = texture(flesh_tex, wp.xy * tex_scale).rgb;
	vec3 texc = tx * wn.x + ty * wn.y + tz * wn.z;
	float beat = 0.58 + 0.42 * sin(TIME * pulse + wp.y * 2.2);
	vec3 col = mix(albedo.rgb, texc, 0.74);
	float vein = smoothstep(0.45, 0.85, texc.g);
	ALBEDO = col;
	ROUGHNESS = mix(0.42, 0.18, vein);
	METALLIC = 0.02;
	SPECULAR = 0.45;
	RIM = 0.72;
	RIM_TINT = 0.55;
	SSS_STRENGTH = 0.55;
	BACKLIGHT = col * 0.4;
	EMISSION = col * emission_energy * beat * (0.45 + vein * 0.7);
	float h = texc.g;
	vec3 dpdx = dFdx(VERTEX);
	vec3 dpdy = dFdy(VERTEX);
	float dhdx = dFdx(h);
	float dhdy = dFdy(h);
	vec3 r1 = cross(dpdy, NORMAL);
	vec3 r2 = cross(NORMAL, dpdx);
	float det = max(dot(dpdx, r1), 0.0001);
	NORMAL = normalize(NORMAL - ((r1 * dhdx + r2 * dhdy) / det) * 0.9);
}
