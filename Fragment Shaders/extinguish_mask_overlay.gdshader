shader_type canvas_item;
render_mode blend_disabled;

uniform highp sampler2D u_splash_mask: filter_nearest, repeat_disable;
//uniform float u_fire_vis_temp_threshold = 750.0;

void fragment() {
	float extinguish_mask = texture(TEXTURE, UV).r;
	vec4 splash_mask = texture(u_splash_mask, UV);
	COLOR = vec4(extinguish_mask, extinguish_mask >= 1.0 ? 1.0 : 0.0, splash_mask.r, 0.33);
}
