shader_type canvas_item;
render_mode blend_disabled;

uniform float u_particle_temp_ambient = 300.0;
uniform float u_particle_temp_max = 373.0;

void fragment() {
	//highp vec2 particle_temperature_info = texture(TEXTURE, UV).rg;
	//highp float particle_temperature = u_particle_temp_ambient + (particle_temperature_info.r * (u_particle_temp_max - u_particle_temp_ambient));
//
	//highp float delta_temperature;
	//highp float modified_temperature;
//
	//if (particle_temperature_info.g < 1e-6) {
		//delta_temperature = (1.0 / 120.0) * 0.05 * (u_particle_temp_max - u_particle_temp_ambient);
		//modified_temperature = particle_temperature + delta_temperature;
	//}
	//else {
		//delta_temperature = 0.0;
		//modified_temperature = particle_temperature;
	//}
//
	//COLOR = vec4(delta_temperature, modified_temperature, 0.0, 1.0);

	highp vec4 orig = texture(TEXTURE, UV);

	COLOR = vec4(0.0, orig.r + (1.0 / 120.0) * 0.5 * (u_particle_temp_max - u_particle_temp_ambient), 0.0, orig.a);
}
