shader_type canvas_item;
render_mode blend_disabled;

uniform highp sampler2D u_particles_to_grid : filter_linear, repeat_disable;
uniform highp sampler2D u_splash_mask : filter_nearest, repeat_disable;
uniform highp sampler2D u_fire_temperature_extinguish : filter_nearest, repeat_disable;
uniform float u_timestep;
uniform float u_extinguish_strength = 1.0;
uniform float u_reignition_strength = 1.0;
uniform bool u_init_state = true;

void fragment() {
	if (u_init_state == true) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	}
	else {
		highp float prev_extinguish_mask = texture(TEXTURE, UV).r;
		highp float new_extinguish_mask = prev_extinguish_mask;
		
		highp vec2 particle_density_evaporated_mass = texture(u_particles_to_grid, UV).rb;
		highp float particle_density = particle_density_evaporated_mass.x;
		highp float evaporated_mass = particle_density_evaporated_mass.y;
		
		highp float fuel_mask = texture(u_splash_mask, UV).r;
		highp float delta_temp = texture(u_fire_temperature_extinguish, UV).b;
		
		// 0 - totally not extinguished, 1 - totally extinguished
		// try to extinguish only where the fuel is injected
		if (fuel_mask > 0.0) {
			
			// wetness is suppossed to help extinguish weak fires
			// other terms disappear in case of weak fires due to smaller and smaller temerature difference between fire and water
			// wetness helps to make sure that each fire can be extinguished 100%
			highp float cooling_contribution = 0.1 * delta_temp;
			highp float evaporation_contribution = 1000.0 * evaporated_mass * particle_density;
			highp float wetness_contribution = (10.0 * particle_density) / (cooling_contribution + evaporation_contribution + 1.0);
			highp float total_contribution = cooling_contribution + evaporation_contribution + wetness_contribution;
			
			// water extinguishes
			new_extinguish_mask += (u_extinguish_strength * total_contribution * u_timestep);
			
			// check if extinguish threshold has been reached
			if (new_extinguish_mask < 1.0) {
				
				// if not, fire reignites
				new_extinguish_mask -= (u_reignition_strength * u_timestep);
			}
		}
		
		COLOR = vec4(clamp(new_extinguish_mask, 0.0, 1.0), 0.0, 0.0, 1.0);
	}
}
