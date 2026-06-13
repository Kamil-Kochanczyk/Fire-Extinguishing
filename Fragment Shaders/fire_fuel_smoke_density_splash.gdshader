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
		highp float is_vapor = fire_fuel_smoke_density_is_vapor.z;

		highp float fire_temp = texture(u_fire_smoke_temperature_advect, UV).r;

		highp vec4 splash_mask = texture(u_splash_mask, UV);

		highp vec2 particle_density_evaporated_mass = texture(u_particles_to_grid, UV).rb;
		highp float particle_density = particle_density_evaporated_mass.x;
		highp float evaporated_mass = particle_density_evaporated_mass.y;

		//highp float is_vapor_new = (particles_latent_heat > 0.0 && fire_temp > u_fire_temp_ambient && u_vapor_density_splash_strength > 0.0) ? 1.0 : 0.0;
		
		rho_fuel += splash_mask.r * u_timestep;
		rho_fuel = clamp(rho_fuel, 0.0, 1.0);

		rho_density += splash_mask.g * u_timestep;
		highp float vapor_delta = evaporated_mass * particle_density * u_vapor_density_splash_strength * u_timestep;
		rho_density += vapor_delta;
		is_vapor += vapor_delta;
		highp float dissipation_delta = u_density_dissipation_rate * u_timestep;
		rho_density -= dissipation_delta;
		is_vapor -= dissipation_delta;
		rho_density = clamp(rho_density, 0.0, 1.0);
		is_vapor = clamp(is_vapor, 0.0, 1.0);

		// vapor-related variable is stored in the final texture for visualization purposes

		COLOR = vec4(rho_fuel, rho_density, is_vapor, 1.0);
	}
}
