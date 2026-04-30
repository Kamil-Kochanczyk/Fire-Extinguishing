shader_type canvas_item;
render_mode blend_disabled;

uniform highp float u_timestep;
uniform highp float u_sigma_cool = 5000.0;    // rate of temperature dissipation
uniform highp float u_fire_temp_ambient = 500.0;    // Kelvin
uniform highp float u_fire_temp_max = 2000.0;    // Kelvin
uniform float u_exponent = 1.0;

void fragment() {
	highp vec2 fire_smoke_temp = texture(TEXTURE, UV).rg;
	highp float fire_temp = fire_smoke_temp.x;
	highp float smoke_temp = fire_smoke_temp.y;
	
	highp float fire_temp_cooled = fire_temp - (u_sigma_cool * pow(fire_temp / u_fire_temp_max, u_exponent) * u_timestep);
	fire_temp_cooled = clamp(fire_temp_cooled, u_fire_temp_ambient, u_fire_temp_max);
	
	// the analogical operation on smoke temperature (smoke temperature dissipation) has already been done in another shader
	
	COLOR = vec4(fire_temp_cooled, smoke_temp, 0.0, 1.0);
}
