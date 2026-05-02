shader_type canvas_item;
render_mode blend_disabled;

void fragment() {
	vec4 particle_density_temperature = texture(TEXTURE, UV);
	float particle_density = particle_density_temperature.r;
	float particle_temperature = particle_density_temperature.g;
	
	float delta_temperature;
	const float THRESHOLD = 0.0;
	
	if (particle_density > THRESHOLD) {
		delta_temperature = (1.0 / 120.0) * 0.5;
	}
	else {
		delta_temperature = 0.0;
	}
	
	COLOR = vec4(0.0, delta_temperature, 0.0, 1.0);
}
