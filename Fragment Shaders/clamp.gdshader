shader_type canvas_item;

/*
Supports arbitrary channel combinations:
R, G, B, A
RG, RB, RA, GB, GA, BA
RGB, RGA, RBA, GBA
RGBA

Example → remap only R and B:
u_use_r = true
u_use_g = false
u_use_b = true
u_use_a = false
*/

uniform bool u_use_r = true;
uniform bool u_use_g = true;
uniform bool u_use_b = true;
uniform bool u_use_a = true;

uniform float u_min_value = -5.0;
uniform float u_max_value = 5.0;

void fragment() {
	vec4 v = texture(TEXTURE, UV);
	
	// prevent division by zero
	float range = max(u_max_value - u_min_value, 0.00001);
	
	vec4 result = vec4(0.0, 0.0, 0.0, 1.0);
	
	// remap only selected channels from [min, max] -> [0, 1]
	if (u_use_r) {
		result.r = clamp((v.r - u_min_value) / range, 0.0, 1.0);
	}
	if (u_use_g) {
		result.g = clamp((v.g - u_min_value) / range, 0.0, 1.0);
	}
	if (u_use_b) {
		result.b = clamp((v.b - u_min_value) / range, 0.0, 1.0);
	}
	if (u_use_a) {
		result.a = clamp((v.a - u_min_value) / range, 0.0, 1.0);
	}
	
	COLOR = result;
}
