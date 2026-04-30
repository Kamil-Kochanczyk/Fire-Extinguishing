shader_type canvas_item;

// nothing here, this is a dummy shader which contains some of my notes

// intuitive explanation of bilerp
vec4 bilerp(sampler2D sampler, vec2 uv, vec2 texel_size) {
	// texel_size = 1 / texture_size, e.g. texel_size = (1 / 256, 1 / 256)
	
	// UV -> texel coordinate space, i.e. ([0,1], [0,1]) -> ([0,width], [0,height])
	// 0.5 shifts from corners to centers of texels
	vec2 st = uv / texel_size - 0.5;
	
	// which texel (cell) is our top-left neighbor? (find its top-left corner)
	vec2 uv_int = floor(st);
	
	// how far (in %) from the top-left neighbor's center are we (in each direction)?
	vec2 uv_frac = fract(st);
	
	// top-left neighbor
	vec4 a = texture(sampler, (uv_int + vec2(0.5, 0.5)) * texel_size);
	
	// top-right neighbor
	vec4 b = texture(sampler, (uv_int + vec2(1.5, 0.5)) * texel_size);
	
	// bottom-left neighbor
	vec4 c = texture(sampler, (uv_int + vec2(0.5, 1.5)) * texel_size);
	
	// bottom-right neighbor
	vec4 d = texture(sampler, (uv_int + vec2(1.5, 1.5)) * texel_size);
	
	// bilinear interpolation
	return mix(mix(a, b, uv_frac.x), mix(c, d, uv_frac.x), uv_frac.y);
}

// UV coordinates: [0,0] -> top-left corner, [1,1] -> bottom-right corner
// TEXTURE - gives access to texture currently assigned to sprite, e.g. assigned in the inspector
// highp - short fot "high precision"
// 1D scalars encoding: r = fire's x, g = smoke's x
// 2D vectors encoding: rg = fire's xy, ba = smoke's xy

void fragment() {
	
}
