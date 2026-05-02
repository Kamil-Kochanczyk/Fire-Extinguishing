shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform float lod : hint_range(0.0, 5.0, 0.1) = 1.0;

void fragment() {
	// screen texture gives us access to the already rendered screen contents
	// we use mipmaps of this screen texture to create the blur effect
	// smaller and smaller mipmaps are more and more blurry
	// if we sample from those blurry mipmaps, we get a blur effect
	// the "smallness" of mipmaps, i.e. the blur amount, is determined by lod
	// lod = level of detail
	// "a form of level of detail management has been applied to texture maps for years, under the name of mipmapping"
	// the bigger the lod, the bigger the blur

	vec3 res = textureLod(SCREEN_TEXTURE, SCREEN_UV, lod).rgb;
	COLOR.rgb = res;
}
