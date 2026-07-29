shader_type canvas_item;
render_mode blend_disabled;

uniform highp sampler2D u_velocity_div_free : filter_nearest, repeat_disable;
uniform highp float u_timestep;

vec4 bilerp(sampler2D sampler, vec2 uv, vec2 texel_size) {
	vec2 st = uv / texel_size - 0.5;
	vec2 uv_int = floor(st);
	vec2 uv_frac = fract(st);
	
	vec4 a = texture(sampler, (uv_int + vec2(0.5, 0.5)) * texel_size);
	vec4 b = texture(sampler, (uv_int + vec2(1.5, 0.5)) * texel_size);
	vec4 c = texture(sampler, (uv_int + vec2(0.5, 1.5)) * texel_size);
	vec4 d = texture(sampler, (uv_int + vec2(1.5, 1.5)) * texel_size);
	
	return mix(mix(a, b, uv_frac.x), mix(c, d, uv_frac.x), uv_frac.y);
}

void fragment() {
	vec4 velocities = texture(u_velocity_div_free, UV);
	vec2 fire_velocity = velocities.rg;
	vec2 smoke_velocity = velocities.ba;
	
	vec2 fire_previous_uv = UV - (fire_velocity * u_timestep);
	vec2 smoke_previous_uv = UV - (smoke_velocity * u_timestep);
	
	highp float advected_fire_fuel;
	highp float advected_smoke_density;
	highp float advected_is_vapor;
	
	if (fire_previous_uv.x >= 0.0 && fire_previous_uv.x <= 1.0 && fire_previous_uv.y >= 0.0 && fire_previous_uv.y <= 1.0) {
		advected_fire_fuel = bilerp(TEXTURE, fire_previous_uv, TEXTURE_PIXEL_SIZE).r;
		advected_fire_fuel = clamp(advected_fire_fuel, 0.0, 1.0);
	}
	else {
		advected_fire_fuel = 0.0;
	}
	
	if (smoke_previous_uv.x >= 0.0 && smoke_previous_uv.x <= 1.0 && smoke_previous_uv.y >= 0.0 && smoke_previous_uv.y <= 1.0) {
		highp vec2 asdiv = bilerp(TEXTURE, smoke_previous_uv, TEXTURE_PIXEL_SIZE).gb;
		
		advected_smoke_density = asdiv.x;
		advected_smoke_density = clamp(advected_smoke_density, 0.0, 1.0);
		
		advected_is_vapor = asdiv.y;
		advected_is_vapor = clamp(advected_is_vapor, 0.0, 1.0);
	}
	else {
		advected_smoke_density = 0.0;
		advected_is_vapor = 0.0;
	}
	
	COLOR = vec4(advected_fire_fuel, advected_smoke_density, advected_is_vapor, 1.0);
}
