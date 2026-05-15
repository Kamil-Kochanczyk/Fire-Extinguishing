shader_type canvas_item;
render_mode blend_disabled;

uniform highp sampler2D u_fire_fuel_smoke_density_splash : filter_nearest, repeat_disable;
uniform highp sampler2D u_splash_mask : filter_nearest, repeat_disable;
uniform highp sampler2D u_obstacles_raw : filter_nearest, repeat_disable;

uniform bool u_init_state = true;
uniform highp float u_timestep;
uniform float u_fire_temp_ambient = 500.0;    // Kelvin
uniform float u_fire_temp_burn = 2000.0;    // Kelvin
uniform float u_fire_temp_max = 2000.0;    // Kelvin
uniform highp float u_smoke_temp_ambient = 300.0;    // Kelvin
uniform highp float u_smoke_temp_max = 500.0;    // Kelvin
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
		highp float fire_temp_new = max(fire_temp_previous, rho_fuel * u_fire_temp_burn);
		fire_temp_new = clamp(fire_temp_new, u_fire_temp_ambient, u_fire_temp_max);

		highp float smoke_temp_new;

		const float THRESHOLD = 0.5;

		bool is_inside_obstacle = texture(u_obstacles_raw, UV).r > THRESHOLD;

		if (is_inside_obstacle) {
			smoke_temp_new = u_smoke_temp_ambient;
		}
		else {
			highp vec4 splash_mask = texture(u_splash_mask, UV);
			smoke_temp_new = smoke_temp_previous;
			smoke_temp_new += splash_mask.g * (u_smoke_temp_max - u_smoke_temp_ambient) * u_timestep;
			smoke_temp_new -= splash_mask.b * (u_smoke_temp_max - u_smoke_temp_ambient) * u_timestep;
			smoke_temp_new -= u_smoke_temp_dissipation_rate * (u_smoke_temp_max - u_smoke_temp_ambient) * u_timestep;
			smoke_temp_new = clamp(smoke_temp_new, u_smoke_temp_ambient, u_smoke_temp_max);
		}

		COLOR = vec4(fire_temp_new, smoke_temp_new, 0.0, 1.0);
	}
}
