shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_opaque, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.7, 0.25, 1.0);
uniform float energy = 1.8;

void fragment() {
	vec3 c = color.rgb * energy;
	ALBEDO = c;
	EMISSION = c;
	ALPHA = color.a;
}
