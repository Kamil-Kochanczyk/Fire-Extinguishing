shader_type canvas_item;
render_mode blend_disabled;

uniform highp sampler2D u_obstacles_raw : filter_nearest, repeat_disable;
uniform int u_use_custom_density_color = 0;
uniform vec3 u_density_color = vec3(0.0, 0.0, 0.0);
uniform vec3 u_min_albedo = vec3(0.0, 0.0, 0.0);
uniform vec3 u_max_albedo = vec3(0.3, 0.3, 0.3);

void fragment() {
	const float THRESHOLD = 0.5;
	bool is_inside_obstacle = texture(u_obstacles_raw, UV).r > THRESHOLD;
	
	if (is_inside_obstacle) {
		COLOR = texture(u_obstacles_raw, UV);
	}
	else {
		vec2 density_is_vapor = texture(TEXTURE, UV).gb;
		
		float orig_density_f = density_is_vapor.x;
		float is_vapor = density_is_vapor.y;    // "fuzzy" boolean variable
		
		vec3 orig_density = vec3(orig_density_f);
		
		vec3 adjusted_max_albedo = mix(u_max_albedo, vec3(1.0, 1.0, 1.0), is_vapor);    // we assume that vapor is white-ish
		
		vec3 new_density = u_min_albedo + orig_density * (adjusted_max_albedo - u_min_albedo);
		
		if (u_use_custom_density_color == 1) {
			COLOR = vec4(u_density_color.r * new_density.x, u_density_color.g * new_density.y, u_density_color.b * new_density.z, 1.0);
		}
		else {
			COLOR = vec4(new_density.x, new_density.y, new_density.z, 1.0);
		}
	}
}
