shader_type canvas_item;
render_mode blend_disabled;

uniform highp sampler2D u_fire_fuel_burn : filter_linear, repeat_disable;
uniform highp sampler2D u_fire_temperature_cool : filter_linear, repeat_disable;
uniform highp float u_timestep;
uniform highp float u_water_heating_speed = 250.0;
uniform highp float u_water_vaporization_speed = 250.0;
uniform float u_fire_temp_ambient = 300.0;    // Kelvin
uniform float u_fire_temp_max = 2000.0;    // Kelvin
uniform highp float u_mass = 0.0;
uniform highp float u_specific_heat_capacity = 0.0;    // J / kg / K
uniform highp float u_specific_latent_heat_vaporization = 0.0;    // J / kg
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
	const float OVERESTIMATE = 1.001;

	highp float area = TEXTURE_PIXEL_SIZE.x * TEXTURE_PIXEL_SIZE.y;

	//highp vec4 orig = texture(TEXTURE, UV);
	//highp float particles_density = orig.r;
	//highp float particle_energy = orig.g;
	//
	//highp float particle_temperature = get_temperature(particle_energy);
	//highp float particle_latent_heat = get_latent_heat(particle_energy);
	//
	//highp float modified_particle_energy = particle_energy;
	//highp float modified_particle_temperature = particle_temperature;
	//highp float modified_particle_latent_heat = particle_latent_heat;
	//
	//// Stefan-Boltzmann law (radiative heat transfer, very simple)
	//// assuming uniform energy distribution, so the energy is proportional to area
	//highp float emissivity = 1.0;
	highp float fire_density = texture(u_fire_fuel_burn, UV).r;
	highp float fire_temperature = texture(u_fire_temperature_cool, UV).r;
	//highp float fire_energy = (fire_temperature * fire_temperature * fire_temperature * fire_temperature) * emissivity * 0.00000005670374419 * area * u_timestep;
	//fire_energy = (fire_temperature > u_fire_temp_ambient) ? fire_energy : 0.0;
	//highp float fire_energy_ambient = (u_fire_temp_ambient * u_fire_temp_ambient * u_fire_temp_ambient * u_fire_temp_ambient) * emissivity * 0.00000005670374419 * area * u_timestep;
	//fire_energy_ambient = (fire_energy > 0.0) ? fire_energy_ambient : 0.0;
	//highp float fire_energy_max = (u_fire_temp_max * u_fire_temp_max * u_fire_temp_max * u_fire_temp_max) * emissivity * 0.00000005670374419 * area * u_timestep;
	//fire_energy_max = (fire_energy > 0.0) ? fire_energy_max : 0.0;
	//
	//highp float fire_energy_lost = 0.0;
	//
	//// update energy by updating temperature and latent heat
	//// this update is more smoothed than the corresponding update performed in the compute shader
	//// however, due to numerical issues, it currently artificially injects energy into the system
	//// mass per grid cell can vary, contrary to the constant mass per particle but we assume the modification is done for only one particle in the grid cell
	//// this particle is the chosen "max" particle from the corresponding compute shader
	//if (particles_density > 0.0) {
		//highp float current_heating_energy = min(particle_energy, u_heating_energy_cost);
		//highp float heating_energy_desirable = u_heating_energy_cost - current_heating_energy;
		//highp float heating_energy_used = min(fire_energy, heating_energy_desirable);
		//modified_particle_temperature += (u_water_heating_speed * (heating_energy_used / (u_mass * u_specific_heat_capacity)));
		//modified_particle_temperature = clamp(modified_particle_temperature, u_particle_temp_ambient, OVERESTIMATE * u_particle_temp_max);
		//
		//fire_energy_lost += max(heating_energy_used, 0.0);
		//
		//if (modified_particle_temperature >= u_particle_temp_max) {
			//highp float fire_energy_left = fire_energy - heating_energy_used;
			//highp float vaporization_energy_desirable = u_vaporization_energy_cost - particle_latent_heat;
			//highp float vaporization_energy_used = min(fire_energy_left, vaporization_energy_desirable);
			//modified_particle_latent_heat += (u_water_vaporization_speed * vaporization_energy_used);
			//modified_particle_latent_heat = clamp(modified_particle_latent_heat, 0.0, OVERESTIMATE * u_vaporization_energy_cost);
			//
			//fire_energy_lost += max(vaporization_energy_used, 0.0);
		//}
		//
		//modified_particle_energy = clamp(get_energy(modified_particle_temperature, modified_particle_latent_heat), 0.0, OVERESTIMATE * u_total_energy_cost);
	//}
	//
	//highp float cooling_factor = particles_density * (fire_energy_lost / fire_energy) * (fire_temperature - u_fire_temp_ambient);
	//
	//COLOR = vec4(fire_energy, modified_particle_energy, cooling_factor, orig.a);

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
