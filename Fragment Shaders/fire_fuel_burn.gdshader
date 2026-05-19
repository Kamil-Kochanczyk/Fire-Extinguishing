shader_type canvas_item;
render_mode blend_disabled;

uniform highp float u_timestep;
uniform highp float u_gamma_fuel = 0.925;    // rate of fuel dissipation
uniform highp float u_burn_strength = 0.01;

void fragment() {
	highp vec3 fire_fuel_smoke_density = texture(TEXTURE, UV).rgb;
	highp float rho_fire_fuel = fire_fuel_smoke_density.x;
	highp float rho_smoke_density = fire_fuel_smoke_density.y;
	highp float is_vapor = fire_fuel_smoke_density.z;
	
	highp float rho_fire_burnt = rho_fire_fuel * pow(1.0 - u_gamma_fuel, u_timestep) * (1.0 - u_burn_strength);
	rho_fire_burnt = clamp(rho_fire_burnt, 0.0, 1.0);
	
	// the analogical operation on smoke density (smoke density dissipation) has already been done in another shader
	
	COLOR = vec4(rho_fire_burnt, rho_smoke_density, is_vapor, 1.0);
}
