shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 u_fuel_splash_position = vec2(-1.0, -1.0);
uniform float u_fuel_splash_radius = 0.1;
uniform float u_fuel_splash_strength = 10.0;
uniform int u_fuel_eraser_off = 1;    // represents a boolean variable

uniform vec2 u_density_heating_splash_position = vec2(-1.0, -1.0);
uniform float u_density_heating_splash_radius = 0.05;
uniform float u_density_heating_splash_strength = 10.0;
uniform int u_density_heating_eraser_off = 1;    // represents a boolean variable

uniform vec2 u_cooling_mouse_position = vec2(-1.0, -1.0);
uniform float u_cooling_splash_radius = 0.2;
uniform float u_cooling_splash_strength = 10.0;
uniform int u_cooling_eraser_off = 1;    // represents a boolean variable

void fragment() {
	// R - fire fuel mask
	// G - smoke density/heating mask
	// B - smoke cooling mask
	// A - extinguish mask
	vec4 previous = texture(TEXTURE, UV);

	vec3 previous_mask = previous.rgb;
	vec3 new_mask = previous_mask;

	bool x_pos_ok = u_fuel_splash_position.x >= 0.0 && u_fuel_splash_position.x <= 1.0;
	bool y_pos_ok = u_fuel_splash_position.y >= 0.0 && u_fuel_splash_position.y <= 1.0;

	if (x_pos_ok && y_pos_ok) {
		float fuel_mask_delta = (1.0 - smoothstep(0.0, u_fuel_splash_radius, distance(UV, u_fuel_splash_position))) * u_fuel_splash_strength;

		if (u_fuel_eraser_off == 1) {
			// create a smooth circular mask, the smaller the distance, the whiter the mask
			new_mask.r += fuel_mask_delta;
			new_mask.r = clamp(new_mask.r, previous_mask.r, u_fuel_splash_strength < previous_mask.r ? previous_mask.r : u_fuel_splash_strength);
		}
		else {
			new_mask.r -= fuel_mask_delta;
			new_mask.r = max(0.0, new_mask.r);
		}
	}

	x_pos_ok = u_density_heating_splash_position.x >= 0.0 && u_density_heating_splash_position.x <= 1.0;
	y_pos_ok = u_density_heating_splash_position.y >= 0.0 && u_density_heating_splash_position.y <= 1.0;

	if (x_pos_ok && y_pos_ok) {
		float density_heating_mask_delta = (1.0 - smoothstep(0.0, u_density_heating_splash_radius, distance(UV, u_density_heating_splash_position))) * u_density_heating_splash_strength;

		if (u_density_heating_eraser_off == 1) {
			// create a smooth circular mask, the smaller the distance, the whiter the mask
			new_mask.g += density_heating_mask_delta;
			new_mask.g = clamp(new_mask.g, previous_mask.g, u_density_heating_splash_strength < previous_mask.g ? previous_mask.g : u_density_heating_splash_strength);
		}
		else {
			new_mask.g -= density_heating_mask_delta;
			new_mask.g = max(0.0, new_mask.g);
		}
	}

	x_pos_ok = u_cooling_mouse_position.x >= 0.0 && u_cooling_mouse_position.x <= 1.0;
	y_pos_ok = u_cooling_mouse_position.y >= 0.0 && u_cooling_mouse_position.y <= 1.0;

	if (x_pos_ok && y_pos_ok) {
		float cooling_mask_delta = (1.0 - smoothstep(0.0, u_cooling_splash_radius, distance(UV, u_cooling_mouse_position))) * u_cooling_splash_strength;

		if (u_cooling_eraser_off == 1) {
			// middle button clicked -> cooling
			new_mask.b += cooling_mask_delta;
			new_mask.b = clamp(new_mask.b, previous_mask.b, u_cooling_splash_strength < previous_mask.b ? previous_mask.b : u_cooling_splash_strength);
		}
		else {
			new_mask.b -= cooling_mask_delta;
			new_mask.b = max(0.0, new_mask.b);
		}
	}

	COLOR = vec4(new_mask.r, new_mask.g, new_mask.b, 0.5);
}
