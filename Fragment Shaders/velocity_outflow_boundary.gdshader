shader_type canvas_item;
render_mode blend_disabled;

uniform highp sampler2D u_obstacles_raw : filter_nearest, repeat_disable;
uniform highp sampler2D u_obstacles_edges : filter_nearest, repeat_disable;

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

void fragment() {
	vec2 tx = TEXTURE_PIXEL_SIZE;
	vec2 fire_velocity_final;
	vec2 smoke_velocity_final;
	
	if (UV.x < tx.x) {
		// left border
		//COLOR.rgb = vec3(1.0, 0.0, 0.0);
		vec4 neighbour_r = sample_neighbour(TEXTURE, UV, 2, tx);
		fire_velocity_final = neighbour_r.rg;
		smoke_velocity_final = neighbour_r.ba;
	}
	else if (UV.x > 1.0 - tx.x) {
		// right border
		//COLOR.rgb = vec3(0.0, 1.0, 0.0);
		vec4 neighbour_l = sample_neighbour(TEXTURE, UV, 1, tx);
		fire_velocity_final = neighbour_l.rg;
		smoke_velocity_final = neighbour_l.ba;
	}
	else if (UV.y < tx.y) {
		// top border
		//COLOR.rgb = vec3(0.0, 0.0, 1.0);
		vec4 neighbour_b = sample_neighbour(TEXTURE, UV, 4, tx);
		fire_velocity_final = neighbour_b.rg;
		smoke_velocity_final = neighbour_b.ba;
	}
	else if (UV.y > 1.0 - tx.y) {
		// bottom border
		//COLOR.rgb = vec3(1.0, 1.0, 1.0);
		vec4 neighbour_t = sample_neighbour(TEXTURE, UV, 3, tx);
		fire_velocity_final = neighbour_t.rg;
		smoke_velocity_final = neighbour_t.ba;
	}
	else {
		// interior
		//COLOR.rgb = vec3(0.0, 0.0, 0.0);
		
		vec2 obstacle_normal = texture(u_obstacles_edges, UV).rg;
		float x = obstacle_normal.x;
		float y = obstacle_normal.y;
		float epsilon = 0.001;
		float c = 0.0;
		float l = c - epsilon;
		float r = c + epsilon;
		
		if (x >= l && x <= r && y >= l && y <= r) {
			// no obstacle edge (normal vector is approximately [0,0])
			const float THRESHOLD = 0.5;
			
			if (texture(u_obstacles_raw, UV).r > THRESHOLD) {
				// inside obstacle
				fire_velocity_final = vec2(0.0, 0.0);
				smoke_velocity_final = vec2(0.0, 0.0);
			}
			else {
				// free space
				vec4 velocity_free_space = texture(TEXTURE, UV);
				fire_velocity_final = velocity_free_space.rg;
				smoke_velocity_final = velocity_free_space.ba;
			}
		}
		else {
			// obstacle edge
			vec4 velocity_obstacle_edge = texture(TEXTURE, UV);
			fire_velocity_final = -velocity_obstacle_edge.rg;
			smoke_velocity_final = -velocity_obstacle_edge.ba;
		}
	}
	
	COLOR = vec4(fire_velocity_final.x, fire_velocity_final.y, smoke_velocity_final.x, smoke_velocity_final.y);
}
