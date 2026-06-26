shader_type canvas_item;
render_mode blend_disabled;

uniform highp sampler2D u_smoke_vis : filter_nearest, repeat_disable;
uniform highp sampler2D u_fire_fuel_smoke_density_advect : filter_nearest, repeat_disable;

void fragment() {
	vec4 fire_color = texture(TEXTURE, UV);
	vec4 smoke_color = texture(u_smoke_vis, UV);
	
	float max_fire_component = max(fire_color.r, max(fire_color.g, fire_color.b));
	float smoke_density = texture(u_fire_fuel_smoke_density_advect, UV).g;
	
	vec4 final = mix(smoke_color, fire_color, max_fire_component);
	final.a = max(max_fire_component, smoke_density);
	
	COLOR = final;
}
