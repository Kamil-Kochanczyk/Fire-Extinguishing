shader_type canvas_item;
render_mode blend_disabled;

void fragment() {
	highp vec4 particle_density_temperature = texture(TEXTURE, UV);
	highp float particle_density = particle_density_temperature.r;
	
	const highp float THRESHOLD = 0.0;
	highp float delta_temperature;
	
	if (particle_density > THRESHOLD) {
		delta_temperature = (1.0 / 120.0) * 0.1;
	}
	else {
		delta_temperature = 0.0;
	}
	
	COLOR = vec4(0.0, delta_temperature, 0.0, 1.0);
}
