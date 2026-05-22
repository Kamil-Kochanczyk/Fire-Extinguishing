shader_type canvas_item;
render_mode blend_disabled;

void fragment() {
	vec4 orig = texture(TEXTURE, UV);
	COLOR = vec4(orig.r, orig.g, orig.b, 1.0);
}
