shader_type canvas_item;
render_mode unshaded, blend_mul;

uniform vec4 tint : source_color = vec4(1.0, 0.93, 0.82, 1.0);
uniform vec4 pale_color : source_color = vec4(0.55, 0.88, 0.32, 1.0);
uniform float vignette : hint_range(0.0, 1.0) = 0.46;
uniform float grain : hint_range(0.0, 1.0) = 0.045;
uniform float pale : hint_range(0.0, 1.0) = 0.0;
uniform float contrast : hint_range(0.5, 2.0) = 1.1;
uniform float saturation : hint_range(0.0, 2.0) = 1.14;

void fragment() {
	vec2 uv = UV;
	float d = distance(uv, vec2(0.5));
	float vig = smoothstep(0.3, 1.05, d);
	vec3 t = mix(tint.rgb, tint.rgb * pale_color.rgb * vec3(1.05, 1.12, 0.85), pale);
	t = (t - vec3(0.5)) * contrast + vec3(0.5);
	float luma = dot(t, vec3(0.299, 0.587, 0.114));
	t = mix(vec3(luma), t, saturation);
	t *= 1.0 - vig * vignette * 0.85;
	float g = fract(sin(dot(uv * vec2(187.3, 119.1) + fract(TIME * 9.0), vec2(12.9898, 78.233))) * 43758.5453);
	t += vec3(g - 0.5) * grain;
	COLOR = vec4(clamp(t, vec3(0.35), vec3(1.35)), 1.0);
}
