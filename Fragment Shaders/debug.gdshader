shader_type canvas_item;

// shader for testing purposes
// currently not used anywhere

bool is_between(float x, float l, float r) {
	return x >= l && x <= r;
}

void fragment() {
	vec4 original = texture(TEXTURE, UV);
	float c = 0.0;
	float epsilon = 0.1;
	
	if (is_between(original.r, c - epsilon, c + epsilon)) {
		COLOR = vec4(1.0, 0.0, 0.0, 1.0);
	}
	else {
		COLOR = vec4(0.0, 1.0, 0.0, 1.0);
	}
}
