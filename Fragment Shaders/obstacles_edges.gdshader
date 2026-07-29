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

void fragment() {
	float c = texture(TEXTURE, UV).r;
	
	float left = sample_neighbour(TEXTURE, UV, 1, TEXTURE_PIXEL_SIZE).r;
	float right = sample_neighbour(TEXTURE, UV, 2, TEXTURE_PIXEL_SIZE).r;
	float top = sample_neighbour(TEXTURE, UV, 3, TEXTURE_PIXEL_SIZE).r;
	float bottom = sample_neighbour(TEXTURE, UV, 4, TEXTURE_PIXEL_SIZE).r;
	
	const float THRESHOLD = 0.5;
	
	// if color is white-ish, then it's obstacle
	bool is_obstacle = (c > THRESHOLD);
	
	// we look at neighbors to check if one of them isn't obstacle
	bool has_neighbour_not_obstacle = (left < THRESHOLD) || (right < THRESHOLD) || (top < THRESHOLD) || (bottom < THRESHOLD);
	
	// we call it an edge if a white-ish center has at least one black neighbour
	bool is_edge = is_obstacle && has_neighbour_not_obstacle;
	
	// compute a simple gradient
	// we don’t divide by delta explicitly
	// that's because we normalize later, which cancels any scale
	float gx = right - left;
	float gy = bottom - top;
	vec2 grad = vec2(gx, gy);
	
	// by convention, we want normals pointing from obstacle into free space
	// but gradient, as written, points from free space to obstacle
	vec2 normal = vec2(0.0, 0.0);
	if (is_edge) {
		normal = normalize(-grad);
	}
	
	COLOR = vec4(normal.x, normal.y, 0.0, 1.0);
	
	// visualize
	//COLOR = vec4(normal.x * 0.5 + 0.5, normal.y * 0.5 + 0.5, 0.0, 1.0);
}
