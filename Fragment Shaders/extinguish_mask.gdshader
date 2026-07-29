shader_type canvas_item;
render_mode blend_disabled;

uniform highp sampler2D u_particles_to_grid : filter_linear, repeat_disable;
uniform highp sampler2D u_splash_mask : filter_nearest, repeat_disable;
uniform highp sampler2D u_fire_temperature_extinguish : filter_nearest, repeat_disable;
uniform float u_timestep;
uniform float u_extinguish_strength = 1.0;
uniform float u_reignition_strength = 1.0;
uniform float u_fire_temp_ambient = 300.0;    // Kelvin
uniform float u_fire_temp_max = 2000.0;    // Kelvin
uniform bool u_init_state = true;

void fragment() {
	if (u_init_state == true) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	}
	else {
		highp vec2 prev_extinguish_masks = texture(TEXTURE, UV).rg;

		highp vec2 particle_density_evaporated_mass = texture(u_particles_to_grid, UV).rb;
		highp float particle_density = particle_density_evaporated_mass.x;
		highp float evaporated_mass = particle_density_evaporated_mass.y;

		highp float fuel_mask = texture(u_splash_mask, UV).r;
		//highp float rho_fuel = texture(u_fire_fuel_smoke_density_splash, UV).r;
		//highp float heat_transfer = texture(u_grid_to_particles, UV).b;
		highp vec2 extinguished_temp_delta_temp = texture(u_fire_temperature_extinguish, UV).rb;
		//highp float extinguished_temp = extinguished_temp_delta_temp.x;
		//highp float max_temp_registered = texture(u_fire_smoke_temperature, UV).b;
		highp float delta_temp = extinguished_temp_delta_temp.y;

		// 0 - totally not extinguished, 1 - totally extinguished
		// moving mask - can be any values between 0 and 1
		// stationary mask = can be either 0 or 1 (represents a boolean)

		highp float prev_moving_mask = prev_extinguish_masks.r;
		//highp float prev_boolean_mask = prev_extinguish_masks.g;

		highp float new_moving_mask = prev_moving_mask;
		//highp float new_boolean_mask = prev_boolean_mask;

		// if this cell is not extinguished
		//if (prev_stationary_mask < 1.0) {

		// try to extinguish only where the fuel is injected
		if (fuel_mask > 0.0) {

			// wetness is suppossed to help extinguish weak fires
			// other terms disappear in case of weak fires due to smaller and smaller temerature difference between fire and water
			// wetness helps to make sure that each fire can extinguished 100%

			highp float cooling_contribution = 0.1 * delta_temp;
			highp float evaporation_contribution = 1000.0 * evaporated_mass * particle_density;
			highp float wetness_contribution = (3.0 * particle_density) / (cooling_contribution + evaporation_contribution + 1.0);
			highp float total_contribution = cooling_contribution + evaporation_contribution + wetness_contribution;

			// water extinguishes
			new_moving_mask += u_extinguish_strength * total_contribution * u_timestep;

			// check if extinguish threshold has been reached
			if (new_moving_mask < 1.0) {

				// if not, fire reignites
				new_moving_mask -= u_reignition_strength * u_timestep;
			}
			//else {

				// otherwise, the cell is marked as extinguished
				//new_moving_mask = 1.0;
				//new_boolean_mask = 1.0;
			//}
		}
			//else {
				//
				//// if temperature is dissipating, there is no point to keep the mask
				//// so we can dissipte it with temperature
				//float normalized_temp = (extinguished_temp - u_fire_temp_ambient) / (u_fire_temp_max - u_fire_temp_ambient);
				//new_moving_mask = (normalized_temp < 1e-6) ? 0.0 : new_moving_mask;
			//}
		//}
		//else {
			//// otherwise, the cell is marked as extinguished
			//// overwrite moving mask which dissipates due to advection
			//new_moving_mask = 1.0;
			//new_stationary_mask = 1.0;
		//}

		// product of mutliple numbers is non-zero iff each of these multiple numbers is non-zero
		//if ((heat_transfer > 0.0) && (rho_fuel > u_fire_vis_fuel_threshold) && (fuel_mask > 0.0) && (extinguished_temp < u_fire_temp_extinguish)) {
			//new_extinguish_mask = 1.0;
		//}

		//COLOR = vec4(new_extinguish_mask, (extinguished_temp < u_fire_temp_extinguish) ? 1.0 : 0.0, 0.0, 1.0);
		COLOR = vec4(clamp(new_moving_mask, 0.0, 1.0), 0.0, 0.0, 1.0);
	}
}
