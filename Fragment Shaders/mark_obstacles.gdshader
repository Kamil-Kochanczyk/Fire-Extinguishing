shader_type canvas_item;
render_mode blend_disabled;

uniform highp sampler2D u_obstacles_raw : filter_nearest, repeat_disable;

void fragment() {
	const float THRESHOLD = 0.5;
	bool is_inside_obstacle = texture(u_obstacles_raw, UV).r > THRESHOLD;
	
	if (is_inside_obstacle) {
		COLOR = texture(u_obstacles_raw, UV);
	}
	else {
		COLOR = texture(TEXTURE, UV);
	}
}
