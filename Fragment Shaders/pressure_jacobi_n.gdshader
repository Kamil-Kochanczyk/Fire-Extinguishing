shader_type canvas_item;
render_mode blend_disabled;

uniform highp sampler2D u_divergence : filter_nearest, repeat_disable;

vec4 sample_neighbour(sampler2D sampler, vec2 uv, int direction, vec2 texture_pixel_size) {
	// direction: 1 - left, 2 - right, 3 - top, 4 - bottom

	vec2 offset = vec2(0.0, 0.0);

	if (direction == 1) {
		offset.x = -1.0;
		offset.y = 0.0;
	}
	else if (direction == 2) {
		offset.x = 1.0;
		offset.y = 0.0;
	}
	else if (direction == 3) {
		offset.x = 0.0;
		offset.y = -1.0;
	}
	else if (direction == 4) {
		offset.x = 0.0;
		offset.y = 1.0;
	}

	vec2 coords = vec2(uv.x + (offset.x * texture_pixel_size.x), uv.y + (offset.y * texture_pixel_size.y));
	float x = clamp(coords.x, 0.0, 1.0);
	float y = clamp(coords.y, 0.0, 1.0);

	return texture(sampler, vec2(x, y));
}

float pressure(float p_r, float p_l, float p_b, float p_t, float dx, float div) {
	// formula comes from the discretization of laplacian
	highp float b = dx * dx * div;
	highp float pressure = (p_r + p_l + p_b + p_t - b) * 0.25;
	return pressure;
}

void fragment() {
	vec2 tx = TEXTURE_PIXEL_SIZE;
	float delta_x = tx.x;    // we assume that delta_x == delta_y

	vec2 previous_r = sample_neighbour(TEXTURE, UV, 2, tx).rg;
	vec2 previous_l = sample_neighbour(TEXTURE, UV, 1, tx).rg;
	vec2 previous_b = sample_neighbour(TEXTURE, UV, 4, tx).rg;
	vec2 previous_t = sample_neighbour(TEXTURE, UV, 3, tx).rg;

	vec2 divergence = texture(u_divergence, UV).rg;

	highp float new_fire_pressure = pressure(previous_r.x, previous_l.x, previous_b.x, previous_t.x, delta_x, divergence.x);
	highp float new_smoke_pressure = pressure(previous_r.y, previous_l.y, previous_b.y, previous_t.y, delta_x, divergence.y);

	COLOR = vec4(new_fire_pressure, new_smoke_pressure, 0.0, 1.0);
}
