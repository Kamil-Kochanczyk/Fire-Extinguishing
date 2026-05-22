shader_type canvas_item;
render_mode blend_disabled;

uniform highp sampler2D u_fire_fuel_smoke_density_splash : filter_nearest, repeat_disable;
uniform highp sampler2D u_fire_temperature_extinguish : filter_nearest, repeat_disable;

uniform highp float u_timestep;

// fire uniforms
uniform vec2 u_fire_disturbance_origin = vec2(-1.0, -1.0);    // already in UV coordinates
uniform vec2 u_fire_disturbance_vector = vec2(0.0, 0.0);
uniform highp float u_fire_disturbance_radius = 0.005;
uniform highp float u_fire_disturbance_strength = 2.5;
uniform float u_fire_vorticity_scale = 5.0;
uniform highp float u_fire_beta = 10.0;    // buoyancy strength
uniform highp float u_fire_temp_ambient = 500.0;    // Kelvin
uniform highp float u_fire_temp_max = 2000.0;    // Kelvin
uniform vec2 u_fire_buoyancy_dir = vec2(0.0, -1.0);

// smoke uniforms
uniform vec2 u_smoke_disturbance_origin = vec2(-1.0, -1.0);    // already in UV coordinates
uniform vec2 u_smoke_disturbance_vector = vec2(0.0, 0.0);
uniform highp float u_smoke_disturbance_radius = 0.005;
uniform highp float u_smoke_disturbance_strength = 2.5;
uniform float u_smoke_vorticity_scale = 1.0;
uniform highp float u_smoke_alpha = 0.1;    // dense regions downward motion strength
uniform highp float u_smoke_beta = 2.0;    // hot regions upward motion strength
uniform highp float u_smoke_temp_ambient = 300.0;    // Kelvin
uniform highp float u_smoke_temp_max = 500.0;    // Kelvin
uniform vec2 u_smoke_buoyancy_dir = vec2(0.0, -1.0);

float disturbance_weight(float dist_squared, float disturbance_radius) {
	return exp((-dist_squared) / disturbance_radius);    // for positive x values e^(-x) takes values from (0,1] range
}

float fire_curl(sampler2D velocity, vec2 uv, vec2 texel_size) {
	vec2 x_offset = vec2(texel_size.x, 0.0);
	vec2 y_offset = vec2(0.0, texel_size.y);
	
	float velocity_b = texture(velocity, uv + y_offset).r;
	float velocity_t = texture(velocity, uv - y_offset).r;
	float velocity_r = texture(velocity, uv + x_offset).g;
	float velocity_l = texture(velocity, uv - x_offset).g;
	
	float dp_dy = velocity_b - velocity_t;
	float dq_dx = velocity_r - velocity_l;
	
	return dq_dx - dp_dy;    // not vividing by deltas because we'll scale it anyway
}

float smoke_curl(sampler2D velocity, vec2 uv, vec2 texel_size) {
	vec2 x_offset = vec2(texel_size.x, 0.0);
	vec2 y_offset = vec2(0.0, texel_size.y);
	
	float velocity_b = texture(velocity, uv + y_offset).b;
	float velocity_t = texture(velocity, uv - y_offset).b;
	float velocity_r = texture(velocity, uv + x_offset).a;
	float velocity_l = texture(velocity, uv - x_offset).a;
	
	float dp_dy = velocity_b - velocity_t;
	float dq_dx = velocity_r - velocity_l;
	
	return dq_dx - dp_dy;    // not vividing by deltas because we'll scale it anyway
}

vec2 fire_vort(sampler2D velocity, vec2 uv, vec2 texel_size, float vorticity_scale) {
	vec2 x_offset = vec2(texel_size.x, 0.0);
	vec2 y_offset = vec2(0.0, texel_size.y);
	
	float curl_b = fire_curl(velocity, uv + y_offset, texel_size);
	float curl_t = fire_curl(velocity, uv - y_offset, texel_size);
	float curl_r = fire_curl(velocity, uv + x_offset, texel_size);
	float curl_l = fire_curl(velocity, uv - x_offset, texel_size);
	
	float curl_c = fire_curl(velocity, uv, texel_size);
	
	float nx = abs(curl_r) - abs(curl_l);
	float ny = abs(curl_b) - abs(curl_t);
	//vec2 grad = vec2(nx, ny);
	vec2 perp_to_grad = vec2(ny, -nx);    // given [a,b], [b,-a] is perpendicular to [a,b]
	
	vec2 dir_normalized = perp_to_grad / (length(perp_to_grad) + 1e-5);
	
	return vorticity_scale * u_timestep * curl_c * dir_normalized;
}

vec2 smoke_vort(sampler2D velocity, vec2 uv, vec2 texel_size, float vorticity_scale) {
	vec2 x_offset = vec2(texel_size.x, 0.0);
	vec2 y_offset = vec2(0.0, texel_size.y);
	
	float curl_b = smoke_curl(velocity, uv + y_offset, texel_size);
	float curl_t = smoke_curl(velocity, uv - y_offset, texel_size);
	float curl_r = smoke_curl(velocity, uv + x_offset, texel_size);
	float curl_l = smoke_curl(velocity, uv - x_offset, texel_size);
	
	float curl_c = smoke_curl(velocity, uv, texel_size);
	
	float nx = abs(curl_r) - abs(curl_l);
	float ny = abs(curl_b) - abs(curl_t);
	//vec2 grad = vec2(nx, ny);
	vec2 perp_to_grad = vec2(ny, -nx);    // given [a,b], [b,-a] is perpendicular to [a,b]
	
	vec2 dir_normalized = perp_to_grad / (length(perp_to_grad) + 1e-5);
	
	return vorticity_scale * u_timestep * curl_c * dir_normalized;
}

vec2 fire_buoy(sampler2D fire_smoke_temp_sampler, vec2 uv) {
	highp float fire_temp = texture(fire_smoke_temp_sampler, uv).r;
	
	highp float fire_temp_normalized = (fire_temp - u_fire_temp_ambient) / (u_fire_temp_max - u_fire_temp_ambient);    // map to [0,1] range
	fire_temp_normalized = clamp(fire_temp_normalized, 0.0, 1.0);
	
	return u_fire_beta * fire_temp_normalized * u_timestep * u_fire_buoyancy_dir;
}

vec2 smoke_buoy(sampler2D fire_fuel_smoke_density_sampler, sampler2D fire_smoke_temp_sampler, vec2 uv) {
	highp float smoke_density = texture(fire_fuel_smoke_density_sampler, uv).g;
	highp float smoke_temp = texture(fire_smoke_temp_sampler, uv).g;
	
	highp float smoke_temp_normalized = (smoke_temp - u_smoke_temp_ambient) / (u_smoke_temp_max - u_smoke_temp_ambient);    // map to [0,1] range
	smoke_temp_normalized = clamp(smoke_temp_normalized, 0.0, 1.0);
	
	return (-u_smoke_alpha * smoke_density * u_timestep * u_smoke_buoyancy_dir) + (u_smoke_beta * smoke_temp_normalized * u_timestep * u_smoke_buoyancy_dir);
}

void fragment() {
	vec4 velocities = texture(TEXTURE, UV);
	vec2 fire_velocity = velocities.rg;
	vec2 smoke_velocity = velocities.ba;
	
	vec2 fire_disturbance;
	vec2 smoke_disturbance;
	
	bool x_pos_ok = u_fire_disturbance_origin.x >= 0.0 && u_fire_disturbance_origin.x <= 1.0;
	bool y_pos_ok = u_fire_disturbance_origin.y >= 0.0 && u_fire_disturbance_origin.y <= 1.0;
	
	if (x_pos_ok && y_pos_ok) {
		vec2 diff = u_fire_disturbance_origin - UV;
		float w = disturbance_weight(dot(diff, diff), u_fire_disturbance_radius);    // dist = 0 -> weight = 1, dist = inf -> weight = 0
		fire_disturbance = u_fire_disturbance_strength * w * u_timestep * u_fire_disturbance_vector;
	}
	else {
		fire_disturbance = vec2(0.0, 0.0);
	}
	
	x_pos_ok = u_smoke_disturbance_origin.x >= 0.0 && u_smoke_disturbance_origin.x <= 1.0;
	y_pos_ok = u_smoke_disturbance_origin.y >= 0.0 && u_smoke_disturbance_origin.y <= 1.0;
	
	if (x_pos_ok && y_pos_ok) {
		vec2 diff = u_smoke_disturbance_origin - UV;
		float w = disturbance_weight(dot(diff, diff), u_smoke_disturbance_radius);    // dist = 0 -> weight = 1, dist = inf -> weight = 0
		smoke_disturbance = u_smoke_disturbance_strength * w * u_timestep * u_smoke_disturbance_vector;
	}
	else {
		smoke_disturbance = vec2(0.0, 0.0);
	}
	
	vec2 fire_vorticity = fire_vort(TEXTURE, UV, TEXTURE_PIXEL_SIZE, u_fire_vorticity_scale);
	vec2 smoke_vorticity = smoke_vort(TEXTURE, UV, TEXTURE_PIXEL_SIZE, u_smoke_vorticity_scale);
	
	vec2 fire_buoyancy = fire_buoy(u_fire_temperature_extinguish, UV);
	vec2 smoke_buoyancy = smoke_buoy(u_fire_fuel_smoke_density_splash, u_fire_temperature_extinguish, UV);
	
	vec2 fire_velocity_final = fire_velocity + fire_disturbance + fire_vorticity + fire_buoyancy;
	vec2 smoke_velocity_final = smoke_velocity + smoke_disturbance + smoke_vorticity + smoke_buoyancy;
	
	COLOR = vec4(fire_velocity_final.x, fire_velocity_final.y, smoke_velocity_final.x, smoke_velocity_final.y);
}
