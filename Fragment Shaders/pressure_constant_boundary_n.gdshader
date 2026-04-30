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
	float fire_pressure_final;
	float smoke_pressure_final;
	
	if (UV.x < tx.x) {
		// left border
		//COLOR.rgb = vec3(1.0, 0.0, 0.0);
		fire_pressure_final = 0.0;
		smoke_pressure_final = 0.0;
	}
	else if (UV.x > 1.0 - tx.x) {
		// right border
		//COLOR.rgb = vec3(0.0, 1.0, 0.0);
		fire_pressure_final = 0.0;
		smoke_pressure_final = 0.0;
	}
	else if (UV.y < tx.y) {
		// top border
		//COLOR.rgb = vec3(0.0, 0.0, 1.0);
		fire_pressure_final = 0.0;
		smoke_pressure_final = 0.0;
	}
	else if (UV.y > 1.0 - tx.y) {
		// bottom border
		//COLOR.rgb = vec3(1.0, 1.0, 1.0);
		fire_pressure_final = 0.0;
		smoke_pressure_final = 0.0;
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
				vec2 pressures_inside_obstacle = texture(TEXTURE, UV).rg;
				fire_pressure_final = pressures_inside_obstacle.x;
				smoke_pressure_final = pressures_inside_obstacle.y;
			}
			else {
				// free space
				vec2 pressures_free_space = texture(TEXTURE, UV).rg;
				fire_pressure_final = pressures_free_space.x;
				smoke_pressure_final = pressures_free_space.y;
			}
		}
		else {
			// obstacle edge
			vec2 pressures_obstacle_edge = texture(TEXTURE, UV).rg;
			fire_pressure_final = pressures_obstacle_edge.x;
			smoke_pressure_final = pressures_obstacle_edge.y;
		}
	}
	
	COLOR = vec4(fire_pressure_final, smoke_pressure_final, 0.0, 1.0);
}
