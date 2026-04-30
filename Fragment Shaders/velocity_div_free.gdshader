shader_type canvas_item;
render_mode blend_disabled;

uniform highp sampler2D u_velocity_boundary : filter_nearest, repeat_disable;
uniform float fire_vel_abs_val_limit = 1.0;    // this variable's name is actually misleading, see below
uniform float smoke_vel_abs_val_limit = 1.0;    // this variable's name is actually misleading, see below

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

vec2 div_free_vel(vec2 v, float p_r, float p_l, float p_b, float p_t, float dx, float dy, float vel_lim) {
	float dp_dx = (p_r - p_l) / (2.0 * dx);
	float dp_dy = (p_b - p_t) / (2.0 * dy);
	vec2 gradient_p = vec2(dp_dx, dp_dy);
	
	// project velocity and also apply some made-up limit
	// we see that we actually limit components, not absolute value
	// so the variable's name is misleading (sorry for this)
	vec2 div_free_v = vec2(v.x - gradient_p.x, v.y - gradient_p.y);
	return clamp(div_free_v, -vel_lim, vel_lim);
}

void fragment() {
	vec2 tx = TEXTURE_PIXEL_SIZE;
	float delta_x = tx.x;
	float delta_y = tx.y;
	
	vec4 velocities = texture(u_velocity_boundary, UV);
	vec2 fire_velocity = velocities.rg;
	vec2 smoke_velocity = velocities.ba;
	
	vec2 pressures_r = sample_neighbour(TEXTURE, UV, 2, tx).rg;
	vec2 pressures_l = sample_neighbour(TEXTURE, UV, 1, tx).rg;
	vec2 pressures_b = sample_neighbour(TEXTURE, UV, 4, tx).rg;
	vec2 pressures_t = sample_neighbour(TEXTURE, UV, 3, tx).rg;
	
	vec2 fire_div_free_vel = div_free_vel(fire_velocity, pressures_r.x, pressures_l.x, pressures_b.x, pressures_t.x, delta_x, delta_y, fire_vel_abs_val_limit);
	vec2 smoke_div_free_vel = div_free_vel(smoke_velocity, pressures_r.y, pressures_l.y, pressures_b.y, pressures_t.y, delta_x, delta_y, smoke_vel_abs_val_limit);
	
	COLOR = vec4(fire_div_free_vel.x, fire_div_free_vel.y, smoke_div_free_vel.x, smoke_div_free_vel.y);
}
