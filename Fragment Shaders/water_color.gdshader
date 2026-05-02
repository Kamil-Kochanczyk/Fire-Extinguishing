shader_type canvas_item;
render_mode blend_disabled;

uniform float u_water_density_threshold : hint_range(0.0, 1.0, 0.01) = 0.5;
uniform float u_edge_softness : hint_range(0.0, 0.2, 0.01) = 0.1;
uniform float u_tint_threshold_min : hint_range(0.0, 1.0, 0.01) = 0.5;
uniform float u_tint_threshold_max : hint_range(0.0, 1.0, 0.01) = 0.5;

uniform vec3 u_water_main_color = vec3(0.033, 0.707, 0.581);
uniform vec3 u_water_tint_color = vec3(0.723, 0.902, 0.893);

void fragment() {
	float water_density = texture(TEXTURE, UV).r;
	
	// smoothstep(a, b, c) = Hermite interpolation from 0 to 1 as c goes from a to b
	// results are undefined when a >= b
	// we use it to smooth the water's edges (so that they're not pixelated)
	// for example, if u_water_density_threshold = 0.5 and u_edge_softness = 0.1, then:
	//    0.5 - 0.1 = 0.4
	//    0.5 + 0.1 = 0.6
	//    intensity = 0   <==> water_density <= 0.4                (no fluid -> no intensity -> no color and full transparency)
	//    intensity ~ 0   <==> 0.4 < water_density < 0.4 + epsilon (transition to fluid starts -> smoothed edge starts -> color starts to appear and transparency starts to disappear)
	//    intensity = 0.5 <==> water_density = 0.5                 (transition halfway through -> smoothed edge's middle is here)
	//    intensity ~ 1   <==> 0.6 - epsilon < water_density < 0.6 (transition to fluid ends -> smoothed edge ends -> color is basically fully visible and transparency no longer applies)
	//    intensity = 1   <==> 0.6 <= water_density                (fluid -> full intensity -> full color and no transparency to make fluid fully visible)
	float intensity = smoothstep(u_water_density_threshold - u_edge_softness, u_water_density_threshold + u_edge_softness, water_density);
	
	// mix = lerp
	// blend two colors for a more interesting visual look
	// denser regions are colored with the main color
	// other regions (mainly the surface) are colored with the tint color
	vec3 res = mix(u_water_tint_color, u_water_main_color, smoothstep(u_tint_threshold_min, u_tint_threshold_max, water_density));
	
	COLOR = vec4(res * intensity, intensity);
}
