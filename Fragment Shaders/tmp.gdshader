shader_type canvas_item;
render_mode blend_disabled;

uniform highp sampler2D u_splash_mask: filter_nearest, repeat_disable;
uniform float u_fire_vis_temp_threshold = 750.0;

void fragment() {
	vec4 extinguish_mask = texture(TEXTURE, UV);
	vec4 splash_mask = texture(u_splash_mask, UV);
	COLOR = vec4(extinguish_mask.r, splash_mask.r, extinguish_mask.g, 0.33);
	//float is_vapor = texture(TEXTURE, UV).b;
	//COLOR = vec4(is_vapor, 0.0, 0.0, 0.33);
	//float value = texture(TEXTURE, UV).r;
	//COLOR = vec4(value, 0.0, 0.0, 0.33);
	//COLOR = vec4(value < 0.0 ? 1.0 : 0.0, 0.0, 0.0, 0.33);
	//COLOR = vec4(value > u_fire_vis_temp_threshold ? 1.0 : 0.0, 0.0, 0.0, 0.5);
	//COLOR = vec4(0.0, (value - 300.0) / (2000.0 - 300.0), 0.0, 0.33);
}
