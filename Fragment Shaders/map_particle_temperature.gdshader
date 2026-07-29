shader_type canvas_item;
render_mode blend_disabled;

uniform bool u_init_state = true;

void fragment() {
	if (u_init_state) {
		COLOR = vec4(0.0, 0.0, 0.0, 0.33);
	}
	else {
		COLOR = texture(TEXTURE, UV);
	}
}
