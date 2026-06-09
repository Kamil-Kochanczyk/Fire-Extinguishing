shader_type canvas_item;
render_mode blend_disabled;

uniform highp sampler2D u_velocity_div_free : filter_nearest, repeat_disable;
uniform highp float u_timestep;
uniform highp float u_fire_temp_ambient = 500.0;    // Kelvin
uniform highp float u_fire_temp_max = 2000.0;    // Kelvin
uniform highp float u_smoke_temp_ambient = 300.0;    // Kelvin
uniform highp float u_smoke_temp_max = 500.0;    // Kelvin

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

	highp float advected_fire_temp;
	highp float advected_smoke_temp;
	
	highp float fire_temp_aux = texture(TEXTURE, UV).b;

	if (fire_previous_uv.x >= 0.0 && fire_previous_uv.x <= 1.0 && fire_previous_uv.y >= 0.0 && fire_previous_uv.y <= 1.0) {
		advected_fire_temp = bilerp(TEXTURE, fire_previous_uv, TEXTURE_PIXEL_SIZE).r;
		advected_fire_temp = clamp(advected_fire_temp, u_fire_temp_ambient, u_fire_temp_max);
		
		fire_temp_aux = bilerp(TEXTURE, fire_previous_uv, TEXTURE_PIXEL_SIZE).b;
		fire_temp_aux = clamp(fire_temp_aux, u_fire_temp_ambient, u_fire_temp_max);
	}
	else {
		advected_fire_temp = u_fire_temp_ambient;
	}

	if (smoke_previous_uv.x >= 0.0 && smoke_previous_uv.x <= 1.0 && smoke_previous_uv.y >= 0.0 && smoke_previous_uv.y <= 1.0) {
		advected_smoke_temp = bilerp(TEXTURE, smoke_previous_uv, TEXTURE_PIXEL_SIZE).g;
		advected_smoke_temp = clamp(advected_smoke_temp, u_smoke_temp_ambient, u_smoke_temp_max);
	}
	else {
		advected_smoke_temp = u_smoke_temp_ambient;
	}

	COLOR = vec4(advected_fire_temp, advected_smoke_temp, fire_temp_aux, 1.0);
}
