shader_type canvas_item;
render_mode blend_disabled;

uniform highp sampler2D u_splash_mask: filter_nearest, repeat_disable;

void fragment() {
	//vec4 extinguish_mask = texture(TEXTURE, UV);
	//vec4 splash_mask = texture(u_splash_mask, UV);
	//COLOR = vec4(extinguish_mask.r, splash_mask.r, 0.0, 0.42);
	vec4 orig = texture(TEXTURE, UV);
	COLOR = vec4(orig.a, 0.0, 0.0, 0.33);
}
