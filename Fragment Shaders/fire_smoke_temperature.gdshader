shader_type canvas_item;
render_mode blend_disabled;

uniform highp sampler2D u_fire_fuel_smoke_density_splash : filter_nearest, repeat_disable;
uniform highp sampler2D u_obstacles_raw : filter_nearest, repeat_disable;

uniform bool u_init_state = true;
uniform highp float u_timestep;

// fire uniforms
uniform float u_fire_temp_ambient = 500.0;    // Kelvin
uniform float u_fire_temp_burn = 2000.0;    // Kelvin
uniform float u_fire_temp_max = 2000.0;    // Kelvin

// smoke uniforms
uniform highp float u_smoke_temp_ambient = 300.0;    // Kelvin
uniform highp float u_smoke_temp_max = 500.0;    // Kelvin
uniform vec2 u_smoke_temp_heating_mouse_position = vec2(-1.0, -1.0);
uniform float u_smoke_temp_heating_splash_radius = 0.05;
uniform float u_smoke_temp_heating_splash_strength = 10.0;
uniform vec2 u_smoke_temp_cooling_mouse_position = vec2(-1.0, -1.0);
uniform float u_smoke_temp_cooling_splash_radius = 0.2;
uniform float u_smoke_temp_cooling_splash_strength = 10.0;
uniform float u_smoke_temp_dissipation_rate = 0.05;
uniform int u_smoke_temp_heating_source_1_toggle = 1;
uniform int u_smoke_temp_heating_source_2_toggle = 1;
uniform int u_smoke_temp_heating_source_3_toggle = 1;
uniform int u_smoke_temp_heating_source_4_toggle = 1;
uniform int u_smoke_temp_heating_source_5_toggle = 1;
uniform int u_smoke_temp_heating_source_6_toggle = 1;
uniform int u_smoke_temp_heating_source_7_toggle = 1;
uniform int u_smoke_temp_cooling_source_1_toggle = 1;
uniform int u_smoke_temp_cooling_source_2_toggle = 1;

struct TemperatureSource {
	vec2 pos;
	float radius;
	float strength;
};

const int SMOKE_TEMP_HEATING_SOURCE_COUNT = 7;
const int SMOKE_TEMP_COOLING_SOURCE_COUNT = 2;

// should match density sources in the density shader
const TemperatureSource smoke_temp_heating_sources[SMOKE_TEMP_HEATING_SOURCE_COUNT] = TemperatureSource[](
	TemperatureSource(vec2(0.125, 0.85), 0.03, 100.0),
	TemperatureSource(vec2(0.25, 0.85), 0.03, 100.0),
	TemperatureSource(vec2(0.375, 0.85), 0.03, 100.0),
	TemperatureSource(vec2(0.5, 0.85), 0.03, 100.0),
	TemperatureSource(vec2(0.625, 0.85), 0.03, 100.0),
	TemperatureSource(vec2(0.75, 0.85), 0.03, 100.0),
	TemperatureSource(vec2(0.875, 0.85), 0.03, 100.0)
);

// don't have to match other sources
const TemperatureSource smoke_temp_cooling_sources[SMOKE_TEMP_COOLING_SOURCE_COUNT] = TemperatureSource[](
	TemperatureSource(vec2(0.375, 0.2), 0.25, 1.0),
	TemperatureSource(vec2(0.625, 0.2), 0.25, 1.0)
);

void fragment() {
	if (u_init_state) {
		COLOR = vec4(u_fire_temp_ambient, u_smoke_temp_ambient, 0.0, 1.0);
	}
	else {
		highp vec4 temps_previous = texture(TEXTURE, UV);
		highp float fire_temp_previous = temps_previous.x;
		highp float smoke_temp_previous = temps_previous.y;
		
		highp float rho_fuel = texture(u_fire_fuel_smoke_density_splash, UV).r;
		highp float fire_temp_new = max(fire_temp_previous, rho_fuel * u_fire_temp_burn);
		fire_temp_new = clamp(fire_temp_new, u_fire_temp_ambient, u_fire_temp_max);
		
		highp float smoke_temp_new;
		
		const float THRESHOLD = 0.5;
		
		bool is_inside_obstacle = texture(u_obstacles_raw, UV).r > THRESHOLD;
		
		if (is_inside_obstacle) {
			smoke_temp_new = u_smoke_temp_ambient;
		}
		else {
			smoke_temp_new = smoke_temp_previous;
			
			// a circular mask (either smooth or constant)
			highp float mask;
			
			bool h_x_pos_ok = u_smoke_temp_heating_mouse_position.x >= 0.0 && u_smoke_temp_heating_mouse_position.x <= 1.0;
			bool h_y_pos_ok = u_smoke_temp_heating_mouse_position.y >= 0.0 && u_smoke_temp_heating_mouse_position.y <= 1.0;
			
			if (h_x_pos_ok && h_y_pos_ok) {
				// left button clicked -> heating
				mask = 1.0 - smoothstep(0.0, u_smoke_temp_heating_splash_radius, distance(UV, u_smoke_temp_heating_mouse_position));
				smoke_temp_new += u_smoke_temp_heating_splash_strength * mask * (u_smoke_temp_max - u_smoke_temp_ambient) * u_timestep;
			}
			
			bool c_x_pos_ok = u_smoke_temp_cooling_mouse_position.x >= 0.0 && u_smoke_temp_cooling_mouse_position.x <= 1.0;
			bool c_y_pos_ok = u_smoke_temp_cooling_mouse_position.y >= 0.0 && u_smoke_temp_cooling_mouse_position.y <= 1.0;
			
			if (c_x_pos_ok && c_y_pos_ok) {
				// middle button clicked -> cooling
				mask = 1.0 - smoothstep(0.0, u_smoke_temp_cooling_splash_radius, distance(UV, u_smoke_temp_cooling_mouse_position));
				smoke_temp_new -= u_smoke_temp_cooling_splash_strength * mask * (u_smoke_temp_max - u_smoke_temp_ambient) * u_timestep;
			}
			
			int smoke_temp_heating_toggles[SMOKE_TEMP_HEATING_SOURCE_COUNT];
			smoke_temp_heating_toggles[0] = u_smoke_temp_heating_source_1_toggle;
			smoke_temp_heating_toggles[1] = u_smoke_temp_heating_source_2_toggle;
			smoke_temp_heating_toggles[2] = u_smoke_temp_heating_source_3_toggle;
			smoke_temp_heating_toggles[3] = u_smoke_temp_heating_source_4_toggle;
			smoke_temp_heating_toggles[4] = u_smoke_temp_heating_source_5_toggle;
			smoke_temp_heating_toggles[5] = u_smoke_temp_heating_source_6_toggle;
			smoke_temp_heating_toggles[6] = u_smoke_temp_heating_source_7_toggle;
			
			// continuous, predefined, smoke temp heating sources
			for (int i = 0; i < SMOKE_TEMP_HEATING_SOURCE_COUNT; ++i) {
				if (smoke_temp_heating_toggles[i] == 1) {
					mask = 1.0 - smoothstep(0.0, smoke_temp_heating_sources[i].radius, distance(UV, smoke_temp_heating_sources[i].pos));
					smoke_temp_new += smoke_temp_heating_sources[i].strength * mask * (u_smoke_temp_max - u_smoke_temp_ambient) * u_timestep;
				}
			}
			
			int smoke_temp_cooling_toggles[SMOKE_TEMP_COOLING_SOURCE_COUNT];
			smoke_temp_cooling_toggles[0] = u_smoke_temp_cooling_source_1_toggle;
			smoke_temp_cooling_toggles[1] = u_smoke_temp_cooling_source_2_toggle;
			
			// continuous, predefined, smoke temp cooling sources
			for (int i = 0; i < SMOKE_TEMP_COOLING_SOURCE_COUNT; ++i) {
				if (smoke_temp_cooling_toggles[i] == 1) {
					mask = distance(UV, smoke_temp_cooling_sources[i].pos) < smoke_temp_cooling_sources[i].radius ? 1.0 : 0.0;
					smoke_temp_new -= smoke_temp_cooling_sources[i].strength * mask * (u_smoke_temp_max - u_smoke_temp_ambient) * u_timestep;
				}
			}
			
			smoke_temp_new -= u_smoke_temp_dissipation_rate * (u_smoke_temp_max - u_smoke_temp_ambient) * u_timestep;
			
			smoke_temp_new = clamp(smoke_temp_new, u_smoke_temp_ambient, u_smoke_temp_max);
		}
		
		COLOR = vec4(fire_temp_new, smoke_temp_new, 0.0, 1.0);
	}
}
