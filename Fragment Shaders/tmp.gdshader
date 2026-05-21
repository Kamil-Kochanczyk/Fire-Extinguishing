shader_type canvas_item;
render_mode blend_disabled;

void fragment() {
	vec4 orig = texture(TEXTURE, UV);
	COLOR = vec4(abs(orig.r - orig.b) / max(1e-6, orig.r), 0.0, 0.0, orig.a);
}
