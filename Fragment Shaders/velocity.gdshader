shader_type canvas_item;
render_mode blend_disabled;

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
	vec4 velocities = texture(TEXTURE, UV);
	vec2 fire_velocity = velocities.rg;
	vec2 smoke_velocity = velocities.ba;
	
	vec2 fire_previous_uv = UV - (fire_velocity * u_timestep);
	vec2 smoke_previous_uv = UV - (smoke_velocity * u_timestep);
	
	vec2 fire_advected_velocity;
	vec2 smoke_advected_velocity;
	
	if (fire_previous_uv.x >= 0.0 && fire_previous_uv.x <= 1.0 && fire_previous_uv.y >= 0.0 && fire_previous_uv.y <= 1.0) {
		fire_advected_velocity = bilerp(TEXTURE, fire_previous_uv, TEXTURE_PIXEL_SIZE).rg;
	}
	else {
		fire_advected_velocity = vec2(0.0, 0.0);
	}
	
	if (smoke_previous_uv.x >= 0.0 && smoke_previous_uv.x <= 1.0 && smoke_previous_uv.y >= 0.0 && smoke_previous_uv.y <= 1.0) {
		smoke_advected_velocity = bilerp(TEXTURE, smoke_previous_uv, TEXTURE_PIXEL_SIZE).ba;
	}
	else {
		smoke_advected_velocity = vec2(0.0, 0.0);
	}
	
	COLOR = vec4(fire_advected_velocity.x, fire_advected_velocity.y, smoke_advected_velocity.x, smoke_advected_velocity.y);
}
