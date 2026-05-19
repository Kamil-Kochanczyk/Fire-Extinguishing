shader_type canvas_item;
render_mode blend_disabled;

uniform bool u_init_state = true;
uniform float u_particle_temp_ambient = 300.0;
uniform float u_particle_temp_max = 373.0;

void fragment() {
	//highp float particle_temperature = texture(TEXTURE, UV).g;
	//highp float normalized_temperature = (particle_temperature - u_particle_temp_ambient) / (u_particle_temp_max - u_particle_temp_ambient);
	//highp vec4 final_color = vec4(0.0, 0.0, 0.0, 1.0);

	//if (particle_temperature < 1e-6) {
		//// temperature is expected to be 0.0 where there are no particles, which is much below particle's ambient temperature
		//final_color.r = 0.0;
		//final_color.g = 1.0;
	//}
	//else {
		//// area where there are some particles
		//final_color.r = normalized_temperature;
		//final_color.g = 0.0;
	//}

	//COLOR = final_color;

	if (u_init_state) {
		COLOR = vec4(0.0, 0.0, 0.0, 0.33);
	}
	else {
		COLOR = texture(TEXTURE, UV);
	}
}
