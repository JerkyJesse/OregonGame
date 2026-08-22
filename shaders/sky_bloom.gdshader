shader_type sky;

#include "res://shaders/noise.gdshaderinc"

uniform vec4 sky_top : source_color = vec4(0.16, 0.09, 0.05, 1.0);
uniform vec4 sky_horizon : source_color = vec4(0.58, 0.36, 0.16, 1.0);
uniform vec4 ground_bottom : source_color = vec4(0.08, 0.06, 0.04, 1.0);
uniform vec4 ground_horizon : source_color = vec4(0.32, 0.2, 0.1, 1.0);
uniform vec4 pale_color : source_color = vec4(0.48, 0.92, 0.32, 1.0);
uniform float pale_amount : hint_range(0.0, 1.5) = 0.7;
uniform float dust : hint_range(0.0, 1.0) = 0.45;

void sky() {
	vec3 dir = EYEDIR;
	float h = dir.y;
	vec3 col;
	if (h >= 0.0) {
		float t = pow(clamp(h, 0.0, 1.0), 0.42);
		col = mix(sky_horizon.rgb, sky_top.rgb, t);
	} else {
		float t = pow(clamp(-h, 0.0, 1.0), 0.38);
		col = mix(ground_horizon.rgb, ground_bottom.rgb, t);
	}
	float haze = exp(-abs(h) * 3.2);
	col = mix(col, sky_horizon.rgb, haze * 0.35);
	vec3 pale_dir = normalize(vec3(0.28, 0.07, -0.96));
	float bloom = pow(max(dot(dir, pale_dir), 0.0), 8.0);
	float band = exp(-pow((h - 0.06) * 5.5, 2.0));
	col += pale_color.rgb * (bloom * 0.85 + band * 0.45) * pale_amount;
	col = mix(col, pale_color.rgb * 0.55, bloom * pale_amount * 0.25);
	if (LIGHT0_ENABLED) {
		float sun = pow(max(dot(dir, LIGHT0_DIRECTION), 0.0), 96.0);
		float corona = pow(max(dot(dir, LIGHT0_DIRECTION), 0.0), 8.0);
		col += LIGHT0_COLOR * LIGHT0_ENERGY * (sun * 0.9 + corona * 0.12);
	}
	float n = noise(dir * 8.0 + vec3(0.0, TIME * 0.015, 0.0));
	col += (n - 0.5) * dust * 0.08 * (1.0 - abs(h));
	float streak = pow(max(1.0 - abs(h), 0.0), 2.4) * dust * 0.12;
	col += sky_horizon.rgb * streak;
	COLOR = col;
}
