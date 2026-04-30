shader_type canvas_item;
render_mode blend_disabled;

uniform highp sampler2D u_obstacles_raw : filter_nearest, repeat_disable;
uniform float u_timestep;

// fire uniforms
uniform vec2 u_fuel_splash_position = vec2(-1.0, -1.0);
uniform float u_fuel_splash_radius = 0.1;
uniform float u_fuel_splash_strength = 10.0;
uniform int u_fuel_source_1_toggle = 1;
uniform int u_fuel_source_2_toggle = 1;
uniform int u_fuel_source_3_toggle = 1;
uniform int u_fuel_source_4_toggle = 1;
uniform int u_fuel_source_5_toggle = 1;
uniform int u_fuel_source_6_toggle = 1;
uniform int u_fuel_source_7_toggle = 1;

// smoke uniforms
uniform vec2 u_density_splash_position = vec2(-1.0, -1.0);
uniform float u_density_splash_radius = 0.05;
uniform float u_density_splash_strength = 10.0;
uniform float u_density_dissipation_rate = 0.05;
uniform int u_density_source_1_toggle = 1;
uniform int u_density_source_2_toggle = 1;
uniform int u_density_source_3_toggle = 1;
uniform int u_density_source_4_toggle = 1;
uniform int u_density_source_5_toggle = 1;
uniform int u_density_source_6_toggle = 1;
uniform int u_density_source_7_toggle = 1;

// fuel source or density source
struct Source {
	vec2 pos;
	float radius;
	float strength;
};

const int FUEL_SOURCE_COUNT = 7;
const int DENSITY_SOURCE_COUNT = 7;

// should more or less match density sources
const Source fuel_sources[FUEL_SOURCE_COUNT] = Source[](
	Source(vec2(0.125, 0.85), 0.1, 10.0),
	Source(vec2(0.25, 0.85), 0.1, 10.0),
	Source(vec2(0.375, 0.85), 0.1, 10.0),
	Source(vec2(0.5, 0.85), 0.1, 10.0),
	Source(vec2(0.625, 0.85), 0.1, 10.0),
	Source(vec2(0.75, 0.85), 0.1, 10.0),
	Source(vec2(0.875, 0.85), 0.1, 10.0)
);

// should match heating sources in the temperature shader
const Source density_sources[DENSITY_SOURCE_COUNT] = Source[](
	Source(vec2(0.125, 0.85), 0.03, 100.0),
	Source(vec2(0.25, 0.85), 0.03, 100.0),
	Source(vec2(0.375, 0.85), 0.03, 100.0),
	Source(vec2(0.5, 0.85), 0.03, 100.0),
	Source(vec2(0.625, 0.85), 0.03, 100.0),
	Source(vec2(0.75, 0.85), 0.03, 100.0),
	Source(vec2(0.875, 0.85), 0.03, 100.0)
);

void fragment() {
	const float THRESHOLD = 0.5;
	
	bool is_inside_obstacle = texture(u_obstacles_raw, UV).r > THRESHOLD;
	
	if (is_inside_obstacle) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	}
	else {
		highp vec2 fire_fuel_smoke_density = texture(TEXTURE, UV).rg;
		highp float rho_fuel = fire_fuel_smoke_density.x;
		highp float rho_density = fire_fuel_smoke_density.y;
		
		highp float mask;
		
		bool x_pos_ok = u_fuel_splash_position.x >= 0.0 && u_fuel_splash_position.x <= 1.0;
		bool y_pos_ok = u_fuel_splash_position.y >= 0.0 && u_fuel_splash_position.y <= 1.0;
		
		if (x_pos_ok && y_pos_ok) {
			// create a smooth circular mask, the smaller the distance, the whiter the mask
			mask = 1.0 - smoothstep(0.0, u_fuel_splash_radius, distance(UV, u_fuel_splash_position));
			rho_fuel += u_fuel_splash_strength * mask * u_timestep;
		}
		
		x_pos_ok = u_density_splash_position.x >= 0.0 && u_density_splash_position.x <= 1.0;
		y_pos_ok = u_density_splash_position.y >= 0.0 && u_density_splash_position.y <= 1.0;
		
		if (x_pos_ok && y_pos_ok) {
			// create a smooth circular mask, the smaller the distance, the whiter the mask
			mask = 1.0 - smoothstep(0.0, u_density_splash_radius, distance(UV, u_density_splash_position));
			rho_density += u_density_splash_strength * mask * u_timestep;
		}
		
		int fuel_toggles[FUEL_SOURCE_COUNT];
		fuel_toggles[0] = u_fuel_source_1_toggle;
		fuel_toggles[1] = u_fuel_source_2_toggle;
		fuel_toggles[2] = u_fuel_source_3_toggle;
		fuel_toggles[3] = u_fuel_source_4_toggle;
		fuel_toggles[4] = u_fuel_source_5_toggle;
		fuel_toggles[5] = u_fuel_source_6_toggle;
		fuel_toggles[6] = u_fuel_source_7_toggle;
		
		// continuous, predefined fuel sources
		for (int i = 0; i < FUEL_SOURCE_COUNT; ++i) {
			if (fuel_toggles[i] == 1) {
				mask = 1.0 - smoothstep(0.0, fuel_sources[i].radius, distance(UV, fuel_sources[i].pos));
				rho_fuel += fuel_sources[i].strength * mask * u_timestep;
			}
		}
		
		rho_fuel = clamp(rho_fuel, 0.0, 1.0);
		
		int density_toggles[DENSITY_SOURCE_COUNT];
		density_toggles[0] = u_density_source_1_toggle;
		density_toggles[1] = u_density_source_2_toggle;
		density_toggles[2] = u_density_source_3_toggle;
		density_toggles[3] = u_density_source_4_toggle;
		density_toggles[4] = u_density_source_5_toggle;
		density_toggles[5] = u_density_source_6_toggle;
		density_toggles[6] = u_density_source_7_toggle;
		
		// continuous, predefined density sources
		for (int i = 0; i < DENSITY_SOURCE_COUNT; ++i) {
			if (density_toggles[i] == 1) {
				mask = 1.0 - smoothstep(0.0, density_sources[i].radius, distance(UV, density_sources[i].pos));
				rho_density += density_sources[i].strength * mask * u_timestep;
			}
		}
		
		rho_density -= u_density_dissipation_rate * u_timestep;
		
		rho_density = clamp(rho_density, 0.0, 1.0);
		
		COLOR = vec4(rho_fuel, rho_density, 0.0, 1.0);
	}
}
