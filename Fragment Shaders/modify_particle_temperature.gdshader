shader_type canvas_item;
render_mode blend_disabled;

uniform highp sampler2D u_fire_temperature_cool : filter_linear, repeat_disable;
uniform highp float u_timestep;
uniform highp float u_water_heating_speed = 250.0;
uniform highp float u_water_vaporization_speed = 250.0;
uniform highp float u_mass = 0.0;
uniform highp float u_specific_heat_capacity = 0.0;    // J / kg / K
uniform highp float u_heating_energy_cost = 0.0;    // J
uniform highp float u_vaporization_energy_cost = 0.0;    // J
uniform highp float u_total_energy_cost = 0.0;    // J
uniform float u_particle_temp_ambient = 300.0;    // Kelvin
uniform float u_particle_temp_max = 373.0;    // Kelvin

float get_temperature(float energy) {
    return u_particle_temp_ambient + (min(energy, u_heating_energy_cost) / (u_mass * u_specific_heat_capacity));
}

float get_latent_heat(float energy) {
    return max(energy - u_heating_energy_cost, 0.0);
}

float get_energy(float temperature, float latent_heat) {
    return (u_mass * u_specific_heat_capacity * (temperature - u_particle_temp_ambient)) + latent_heat;
}

void fragment() {
	// used to allow the energy to reach the boiling/death thresholds
	// probably due to numerical issues without allowing slightly bigger values, the thresholds will never be reached
	//const float OVERESTIMATE = 1.001;
	
	highp float area = TEXTURE_PIXEL_SIZE.x * TEXTURE_PIXEL_SIZE.y;
	highp float fire_temperature = texture(u_fire_temperature_cool, UV).r;
	highp vec4 orig = texture(TEXTURE, UV);
	highp float orig_particle_density = orig.r;
	highp float orig_particle_energy = orig.g;
	highp float orig_particle_temperature = get_temperature(orig_particle_energy);
	highp float orig_particle_latent_heat = get_latent_heat(orig_particle_energy);
	highp float heat_transfer = 0.0;
	highp float delta_energy = 0.0;
	highp float modified_energy = orig_particle_energy;
	highp float modified_temperature = orig_particle_temperature;
	highp float modified_latent_heat = orig_particle_latent_heat;
	
	// heating and vaporization speed is multiplied by 8
	// this is because originally a mistake was made
	// heating and vaporization speed were tuned in a situation where the updates were done 8 times
	// while the updates should have always been done only once
	// so the tuned parameters were 8 times smaller than they should
	
	if ((fire_temperature > u_particle_temp_max) && (orig_particle_density > 0.0)) {
		heat_transfer = area * (fire_temperature - orig_particle_temperature) * u_timestep;
		
		highp float current_heating_energy = min(orig_particle_energy, u_heating_energy_cost);
		highp float heating_energy_desirable = u_heating_energy_cost - current_heating_energy;
		highp float heating_energy_used = min(heat_transfer, heating_energy_desirable);
		modified_temperature += ((8.0 * u_water_heating_speed) * (heating_energy_used / (u_mass * u_specific_heat_capacity)));
		modified_temperature = clamp(modified_temperature, u_particle_temp_ambient, u_particle_temp_max);
		
		if (modified_temperature >= u_particle_temp_max) {
			highp float heat_transfer_remaining = heat_transfer - heating_energy_used;
			highp float vaporization_energy_desirable = u_vaporization_energy_cost - orig_particle_latent_heat;
			highp float vaporization_energy_used = min(heat_transfer_remaining, vaporization_energy_desirable);
			modified_latent_heat += ((8.0 * u_water_vaporization_speed) * vaporization_energy_used);
			modified_latent_heat = clamp(modified_latent_heat, 0.0, u_vaporization_energy_cost);
		}
		
		modified_energy = clamp(get_energy(modified_temperature, modified_latent_heat), 0.0, u_total_energy_cost);
		
		delta_energy = modified_energy - orig_particle_energy;
	}
	
	COLOR = vec4(delta_energy, modified_energy, heat_transfer, orig_particle_density);
}
