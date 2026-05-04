shader_type canvas_item;
render_mode blend_disabled;

uniform highp sampler2D u_obstacles_raw : filter_nearest, repeat_disable;
uniform highp sampler2D u_splash_mask : filter_nearest, repeat_disable;
uniform float u_timestep;
uniform float u_density_dissipation_rate = 0.05;

void fragment() {
	const float THRESHOLD = 0.5;
	
	bool is_inside_obstacle = texture(u_obstacles_raw, UV).r > THRESHOLD;
	
	if (is_inside_obstacle) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	}
	else {
		highp vec2 fire_fuel_smoke_density = texture(TEXTURE, UV).rg;
		highp float rho_fuel = fire_fuel_smoke_density.x;
		highp float rho_density = fire_fuel_smoke_density.y;
		
		highp vec4 splash_mask = texture(u_splash_mask, UV);
		
		rho_fuel += splash_mask.r * u_timestep;
		rho_fuel = clamp(rho_fuel, 0.0, 1.0);
		
		rho_density += splash_mask.g * u_timestep;
		rho_density -= u_density_dissipation_rate * u_timestep;
		rho_density = clamp(rho_density, 0.0, 1.0);
		
		COLOR = vec4(rho_fuel, rho_density, 0.0, 1.0);
	}
}
