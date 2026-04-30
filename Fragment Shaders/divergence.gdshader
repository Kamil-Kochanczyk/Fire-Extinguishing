shader_type canvas_item;
render_mode blend_disabled;

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

float divergence(vec2 v_r, vec2 v_l, vec2 v_b, vec2 v_t, float dx, float dy) {
	float du_dx = (v_r.x - v_l.x) / (2.0 * dx);
	float dv_dy = (v_b.y - v_t.y) / (2.0 * dy);
	return du_dx + dv_dy;
}

void fragment() {
	vec2 tx = TEXTURE_PIXEL_SIZE;
	float delta_x = tx.x;
	float delta_y = tx.y;
	
	vec4 velocities_r = sample_neighbour(TEXTURE, UV, 2, tx);
	vec4 velocities_l = sample_neighbour(TEXTURE, UV, 1, tx);
	vec4 velocities_b = sample_neighbour(TEXTURE, UV, 4, tx);
	vec4 velocities_t = sample_neighbour(TEXTURE, UV, 3, tx);
	
	vec2 fire_velocity_r = velocities_r.rg;
	vec2 fire_velocity_l = velocities_l.rg;
	vec2 fire_velocity_b = velocities_b.rg;
	vec2 fire_velocity_t = velocities_t.rg;
	
	vec2 smoke_velocity_r = velocities_r.ba;
	vec2 smoke_velocity_l = velocities_l.ba;
	vec2 smoke_velocity_b = velocities_b.ba;
	vec2 smoke_velocity_t = velocities_t.ba;
	
	float fire_velocity_divergence = divergence(fire_velocity_r, fire_velocity_l, fire_velocity_b, fire_velocity_t, delta_x, delta_y);
	float smoke_velocity_divergence = divergence(smoke_velocity_r, smoke_velocity_l, smoke_velocity_b, smoke_velocity_t, delta_x, delta_y);
	
	COLOR = vec4(fire_velocity_divergence, smoke_velocity_divergence, 0.0, 1.0);
}
