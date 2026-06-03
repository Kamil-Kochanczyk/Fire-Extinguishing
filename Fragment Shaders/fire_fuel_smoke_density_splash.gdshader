shader_type canvas_item;
render_mode blend_disabled;

uniform highp sampler2D u_particles_to_grid : filter_linear, repeat_disable;
uniform highp sampler2D u_obstacles_raw : filter_nearest, repeat_disable;
uniform highp sampler2D u_splash_mask : filter_nearest, repeat_disable;
uniform highp sampler2D u_extinguish_mask : filter_nearest, repeat_disable;
uniform highp sampler2D u_fire_smoke_temperature_advect : filter_nearest, repeat_disable;
uniform float u_timestep;
uniform float u_vapor_density_splash_strength = 1.0;
uniform float u_density_dissipation_rate = 0.05;
uniform float u_fire_temp_ambient = 500.0;    // Kelvin
uniform float u_heating_energy_cost;    // J

void fragment() {
	const float THRESHOLD = 0.5;

	bool is_inside_obstacle = texture(u_obstacles_raw, UV).r > THRESHOLD;

	if (is_inside_obstacle) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	}
	else {
		highp vec3 fire_fuel_smoke_density_is_vapor = texture(TEXTURE, UV).rgb;
		highp float rho_fuel = fire_fuel_smoke_density_is_vapor.x;
		highp float rho_density = fire_fuel_smoke_density_is_vapor.y;
		highp float is_vapor_previous = fire_fuel_smoke_density_is_vapor.z;

		highp float fire_temp = texture(u_fire_smoke_temperature_advect, UV).r;

		highp vec4 splash_mask = texture(u_splash_mask, UV);
		highp float particles_energy = texture(u_particles_to_grid, UV).g;
		highp float particles_latent_heat = max(particles_energy - u_heating_energy_cost, 0.0);
		//highp float is_vapor_new = (particles_latent_heat > 0.0 && rho_fuel > 0.0 && u_vapor_density_splash_strength > 0.0) ? 1.0 : 0.0;
		highp float is_vapor_new = (particles_latent_heat > 0.0 && fire_temp > u_fire_temp_ambient && u_vapor_density_splash_strength > 0.0) ? 1.0 : 0.0;

		float extinguish_mask = texture(u_extinguish_mask, UV).r;

		if (extinguish_mask > 0.5) {
			rho_fuel = 0.0;
		}
		else {
			rho_fuel += splash_mask.r * u_timestep;
			rho_fuel = clamp(rho_fuel, 0.0, 1.0);
		}

		rho_density += splash_mask.g * u_timestep;
		//rho_density += is_vapor_new * u_vapor_density_splash_strength * u_timestep;
		rho_density += is_vapor_new * 0.0 * u_timestep;
		rho_density -= u_density_dissipation_rate * u_timestep;
		rho_density = clamp(rho_density, 0.0, 1.0);

		COLOR = vec4(rho_fuel, rho_density, clamp(is_vapor_previous + is_vapor_new, 0.0, 1.0), 1.0);
	}
}
