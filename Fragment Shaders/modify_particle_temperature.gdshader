shader_type canvas_item;
render_mode blend_disabled;

uniform highp sampler2D u_fire_temperature_cool : filter_linear, repeat_disable;
uniform highp float u_timestep;
uniform highp float emissivity = 1.0;
uniform highp float u_fire_temp_ambient = 500.0;    // Kelvin
uniform float u_particle_temp_ambient = 300.0;    // Kelvin
uniform float u_particle_temp_max = 373.0;    // Kelvin

void fragment() {
	//highp vec2 particle_temperature_info = texture(TEXTURE, UV).rg;
	//highp float particle_temperature = u_particle_temp_ambient + (particle_temperature_info.r * (u_particle_temp_max - u_particle_temp_ambient));
	
	highp vec4 orig = texture(TEXTURE, UV);
	highp float particles_density = orig.r;
	highp float particles_temperature = orig.g;
	highp float particles_latent_heat = orig.b;
	
	//highp float delta_temperature;
	//highp float modified_temperature;
//
	//if (particles_temperature > 1e-6) {
		//delta_temperature = (1.0 / 120.0) * 0.05 * (u_particle_temp_max - u_particle_temp_ambient);
		//modified_temperature = particles_temperature + 8.25 * delta_temperature;    // increase delta to artificiall counteract numerical dissipation
	//}
	//else {
		//delta_temperature = 0.0;
		//modified_temperature = particles_temperature;
	//}
	
	// Stefan-Boltzmann law
	highp float fire_temperature = texture(u_fire_temperature_cool, UV).r;
	highp float fire_energy = (fire_temperature * fire_temperature * fire_temperature * fire_temperature) * emissivity * 0.00000005670374419 * (TEXTURE_PIXEL_SIZE.x * TEXTURE_PIXEL_SIZE.y) * u_timestep;
	
	//orig.r > 0.0 && orig.r < 2.0 ? 1.0 : 0.0
	COLOR = vec4(fire_temperature > u_fire_temp_ambient ? fire_energy : 0.0, particles_temperature, particles_latent_heat, orig.a);
	
	//COLOR = vec4(0.0, orig.r + (1.0 / 120.0) * 0.5 * (u_particle_temp_max - u_particle_temp_ambient), 0.0, orig.a);
}
