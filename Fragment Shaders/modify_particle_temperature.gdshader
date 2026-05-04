shader_type canvas_item;
render_mode blend_disabled;

void fragment() {
	highp vec4 particle_density_temperature = texture(TEXTURE, UV);
	highp float particle_density = particle_density_temperature.r;
	highp float particle_temperature = particle_density_temperature.g;
	
	const highp float THRESHOLD = 0.0;
	highp float delta_temperature;
	highp float modified_temperature;
	
	if (particle_density > THRESHOLD) {
		delta_temperature = (1.0 / 120.0) * 0.05;
		modified_temperature = particle_temperature + delta_temperature;
	}
	else {
		delta_temperature = 0.0;
		modified_temperature = particle_temperature;
	}
	
	COLOR = vec4(0.0, delta_temperature, modified_temperature, 1.0);
}
