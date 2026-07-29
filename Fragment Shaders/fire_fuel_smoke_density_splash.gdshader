shader_type canvas_item;
render_mode blend_disabled;

uniform highp sampler2D u_particles_to_grid : filter_linear, repeat_disable;
uniform highp sampler2D u_obstacles_raw : filter_nearest, repeat_disable;
uniform highp sampler2D u_splash_mask : filter_nearest, repeat_disable;
uniform highp sampler2D u_extinguish_mask : filter_nearest, repeat_disable;
uniform float u_timestep;
uniform float u_density_heating_injection_strength = 10.0;
uniform float u_vapor_density_injection_strength = 1.0;
uniform float u_density_dissipation_rate = 0.05;

void fragment() {
	const float THRESHOLD = 0.5;
	
	bool is_inside_obstacle = texture(u_obstacles_raw, UV).r > THRESHOLD;
	
	if (is_inside_obstacle) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	}
	else {
		highp vec3 fire_smoke_vapor = texture(TEXTURE, UV).rgb;
		highp float rho_fuel = fire_smoke_vapor.x;
		highp float rho_density = fire_smoke_vapor.y;
		highp float is_vapor = fire_smoke_vapor.z;
		
		highp vec4 splash_mask = texture(u_splash_mask, UV);
		
		highp vec2 particle_density_evaporated_mass = texture(u_particles_to_grid, UV).rb;
		highp float particle_density = particle_density_evaporated_mass.x;
		highp float evaporated_mass = particle_density_evaporated_mass.y;
		
		float extinguish_mask = texture(u_extinguish_mask, UV).r;
		
		rho_fuel += (1.0 - extinguish_mask) * splash_mask.r * u_timestep;
		rho_fuel = clamp(rho_fuel, 0.0, 1.0);
		
		rho_density += rho_fuel * u_density_heating_injection_strength * u_timestep;
		
		highp float vapor_delta = evaporated_mass * particle_density * u_vapor_density_injection_strength * u_timestep;
		rho_density += vapor_delta;
		is_vapor += vapor_delta;
		
		highp float dissipation_delta = u_density_dissipation_rate * u_timestep;
		rho_density -= dissipation_delta;
		is_vapor -= dissipation_delta;
		
		rho_density = clamp(rho_density, 0.0, 1.0);
		is_vapor = clamp(is_vapor, 0.0, 1.0);
		
		COLOR = vec4(rho_fuel, rho_density, is_vapor, 1.0);
	}
}
