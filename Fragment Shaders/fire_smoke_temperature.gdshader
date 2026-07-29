shader_type canvas_item;
render_mode blend_disabled;

uniform highp sampler2D u_particles_to_grid : filter_linear, repeat_disable;
uniform highp sampler2D u_obstacles_raw : filter_nearest, repeat_disable;
uniform highp sampler2D u_fire_fuel_smoke_density_splash : filter_nearest, repeat_disable;

uniform bool u_init_state = true;
uniform highp float u_timestep;
uniform float u_fire_temp_ambient = 300.0;    // Kelvin
uniform float u_fire_temp_burn = 2000.0;    // Kelvin
uniform float u_fire_temp_max = 2000.0;    // Kelvin
uniform highp float u_smoke_temp_ambient = 300.0;    // Kelvin
uniform highp float u_smoke_temp_max = 500.0;    // Kelvin
uniform float u_fire_temp_release_rate = 7.5;
uniform float u_density_heating_injection_strength = 10.0;
uniform float u_vapor_heating_injection_strength = 1.0;
uniform float u_smoke_temp_dissipation_rate = 0.05;

void fragment() {
	if (u_init_state) {
		COLOR = vec4(u_fire_temp_ambient, u_smoke_temp_ambient, 0.0, 1.0);
	}
	else {
		highp vec4 temps_previous = texture(TEXTURE, UV);
		highp float fire_temp_previous = temps_previous.x;
		highp float smoke_temp_previous = temps_previous.y;
		
		highp float rho_fuel = texture(u_fire_fuel_smoke_density_splash, UV).r;
		
		highp vec2 particle_density_evaporated_mass = texture(u_particles_to_grid, UV).rb;
		highp float particle_density = particle_density_evaporated_mass.x;
		highp float evaporated_mass = particle_density_evaporated_mass.y;
		
		highp float fire_temp_new = fire_temp_previous;
		fire_temp_new += (rho_fuel * u_fire_temp_burn * u_fire_temp_release_rate * u_timestep);
		fire_temp_new = clamp(fire_temp_new, u_fire_temp_ambient, u_fire_temp_max);
		
		highp float smoke_temp_new;
		
		const float THRESHOLD = 0.5;
		
		bool is_inside_obstacle = texture(u_obstacles_raw, UV).r > THRESHOLD;
		
		if (is_inside_obstacle) {
			smoke_temp_new = u_smoke_temp_ambient;
		}
		else {
			smoke_temp_new = smoke_temp_previous;
			highp float const_term = (u_smoke_temp_max - u_smoke_temp_ambient) * u_timestep;
			
			smoke_temp_new += rho_fuel * u_density_heating_injection_strength * const_term;
			smoke_temp_new += evaporated_mass * particle_density * u_vapor_heating_injection_strength * const_term;    // vapor contribution
			
			smoke_temp_new -= u_smoke_temp_dissipation_rate * const_term;
			
			smoke_temp_new = clamp(smoke_temp_new, u_smoke_temp_ambient, u_smoke_temp_max);
		}
		
		COLOR = vec4(fire_temp_new, smoke_temp_new, 0.0, 1.0);
	}
}
