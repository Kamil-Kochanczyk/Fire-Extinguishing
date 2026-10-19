shader_type canvas_item;
render_mode blend_disabled;

uniform highp sampler2D u_grid_to_particles : filter_linear, repeat_disable;
uniform highp float u_timestep;
uniform float u_temp_drop_sensitivity = 2500.0;
uniform float u_fire_temp_ambient = 300.0;    // Kelvin
uniform float u_fire_temp_max = 2000.0;    // Kelvin

void fragment() {
	highp vec3 fire_smoke_temp = texture(TEXTURE, UV).rgb;
	highp float fire_temp = fire_smoke_temp.x;
	highp float smoke_temp = fire_smoke_temp.y;
	
	highp float heat_stolen = texture(u_grid_to_particles, UV).b;
	
	highp float extinguished_temp = fire_temp - (u_temp_drop_sensitivity * heat_stolen);
	extinguished_temp = clamp(extinguished_temp, u_fire_temp_ambient, u_fire_temp_max);
	
	COLOR = vec4(extinguished_temp, smoke_temp, fire_temp - extinguished_temp, 1.0);
}
