shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
uniform vec4 tint : source_color = vec4(1.0, 0.93, 0.82, 1.0);
uniform vec4 pale_color : source_color = vec4(0.55, 0.88, 0.32, 1.0);
uniform float vignette : hint_range(0.0, 1.0) = 0.46;
uniform float grain : hint_range(0.0, 1.0) = 0.045;
uniform float pale : hint_range(0.0, 1.0) = 0.0;
uniform float contrast : hint_range(0.5, 2.0) = 1.1;
uniform float saturation : hint_range(0.0, 2.0) = 1.14;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 c = uv - vec2(0.5);
	float d = length(c);
	float vig = smoothstep(0.26, 1.08, d);
	vec2 ca = c * vig * 0.0055;
	vec3 col;
	col.r = texture(screen_tex, uv + ca).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - ca).b;
	vec3 grade = mix(tint.rgb, tint.rgb * pale_color.rgb * vec3(1.02, 1.16, 0.8), pale);
	col *= grade;
	col = (col - vec3(0.5)) * contrast + vec3(0.5);
	float luma = dot(col, vec3(0.2126, 0.7152, 0.0722));
	col = mix(vec3(luma), col, saturation);
	col *= 1.0 - vig * vignette * 0.7;
	col = mix(col, col * pale_color.rgb + pale_color.rgb * 0.05, pale * 0.28);
	float dirt = step(0.9965, hash21(floor(uv * vec2(96.0, 54.0))));
	float scratch = step(0.9988, hash21(vec2(floor(uv.y * 140.0), 8.2)));
	col += vec3(dirt * 0.045 + scratch * 0.03);
	float g = hash21(uv * vec2(1117.3, 913.1) + fract(TIME * 13.0));
	col += (g - 0.5) * grain;
	COLOR = vec4(clamp(col, vec3(0.0), vec3(1.55)), 1.0);
}
