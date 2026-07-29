shader_type canvas_item;
render_mode blend_disabled;

uniform highp sampler2D u_obstacles_raw : filter_nearest, repeat_disable;
uniform highp sampler2D u_baked_fire_temp : filter_nearest, repeat_disable;
uniform highp sampler2D u_custom_fire_temp;
uniform int u_use_custom_fire_temp = 0;
uniform highp float u_fire_temp_ambient = 300.0;    // Kelvin
uniform highp float u_fire_temp_max = 2000.0;    // Kelvin

void fragment() {
	const float THRESHOLD = 0.5;
	bool is_inside_obstacle = texture(u_obstacles_raw, UV).r > THRESHOLD;

	if (is_inside_obstacle) {
		COLOR = texture(u_obstacles_raw, UV);
	}
	else {
		// Planck's Law is used to find the color of a blackbody based on its temperature
		// it's implemented here implicitly using a lookup texture
		// lookup texture has some predefined colors corresponding to some temperature range
		// we use a baked, predefined image texture or a custom, dynamic gradient texture

		highp float fire_temp = texture(TEXTURE, UV).r;
		highp float fire_temp_normalized = (fire_temp - u_fire_temp_ambient) / (u_fire_temp_max - u_fire_temp_ambient);
		fire_temp_normalized = clamp(fire_temp_normalized, 0.0, 1.0);

		vec3 fire_color;

		if (u_use_custom_fire_temp == 1) {
			fire_color = texture(u_custom_fire_temp, vec2(fire_temp_normalized, 0.0)).rgb;
		}
		else {
			fire_color = texture(u_baked_fire_temp, vec2(fire_temp_normalized, 0.0)).rgb;
		}

		COLOR = vec4(fire_color, 1.0);
	}
}
