shader_type canvas_item;
render_mode blend_disabled;

uniform highp sampler2D u_particles_to_grid : filter_linear, repeat_disable;
uniform highp sampler2D u_splash_mask : filter_nearest, repeat_disable;
uniform highp sampler2D u_fire_fuel_smoke_density_splash : filter_nearest, repeat_disable;
uniform highp sampler2D u_fire_smoke_temperature : filter_nearest, repeat_disable;
uniform highp sampler2D u_grid_to_particles : filter_linear, repeat_disable;
uniform highp sampler2D u_fire_temperature_extinguish : filter_nearest, repeat_disable;
uniform float u_extinguish_strength = 100.0;
uniform float u_fire_vis_fuel_threshold = 0.5;
uniform float u_fire_temp_extinguish = 600.0;    // Kelvin
uniform bool u_init_state = true;

void fragment() {
	if (u_init_state == true) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	}
	else {
		highp float prev_extinguish_mask = texture(TEXTURE, UV).r;
		//highp float particle_density = texture(u_particles_to_grid, UV).r;
		highp float evaporated_mass = texture(u_particles_to_grid, UV).b;
		highp float fuel_mask = texture(u_splash_mask, UV).r;
		highp float rho_fuel = texture(u_fire_fuel_smoke_density_splash, UV).r;
		highp float heat_transfer = texture(u_grid_to_particles, UV).b;
		highp vec2 extinguished_temp_aux_temp = texture(u_fire_temperature_extinguish, UV).rb;
		highp float extinguished_temp = extinguished_temp_aux_temp.x;
		highp float max_temp_registered = texture(u_fire_smoke_temperature, UV).b;

		float new_extinguish_mask = prev_extinguish_mask;

		// product of mutliple numbers is non-zero iff each of these multiple numbers is non-zero
		if ((heat_transfer > 0.0) && (rho_fuel > u_fire_vis_fuel_threshold) && (fuel_mask > 0.0) && (extinguished_temp < u_fire_temp_extinguish)) {
			new_extinguish_mask = 1.0;
		}

		COLOR = vec4(new_extinguish_mask, (extinguished_temp < u_fire_temp_extinguish) ? 1.0 : 0.0, 0.0, 1.0);
		//COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	}
}
