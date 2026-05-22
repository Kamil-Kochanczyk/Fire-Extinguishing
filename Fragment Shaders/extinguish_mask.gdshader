shader_type canvas_item;
render_mode blend_disabled;

uniform highp sampler2D u_particles_to_grid : filter_linear, repeat_disable;
uniform highp sampler2D u_splash_mask : filter_nearest, repeat_disable;
uniform highp sampler2D u_fire_temperature_extinguish : filter_nearest, repeat_disable;
uniform float u_fire_temp_extinguish = 500.0;

void fragment() {
	highp float prev_extinguish_mask = texture(TEXTURE, UV).r;
	highp float particles_density = texture(u_particles_to_grid, UV).r;
	highp float fuel_mask = texture(u_splash_mask, UV).r;
	highp float extinguished_temp = texture(u_fire_temperature_extinguish, UV).r;
	
	float new_extinguish_mask = prev_extinguish_mask;
	
	if ((extinguished_temp <= u_fire_temp_extinguish) && (particles_density > 0.0) && (fuel_mask > 0.0) && (prev_extinguish_mask < 1e-6)) {
		new_extinguish_mask = 1.0;
	}
	
	COLOR = vec4(new_extinguish_mask, 0.0, 0.0, 1.0);
}
