shader_type particles;

uniform highp sampler2D u_particle_pos_temp_img : filter_nearest, repeat_disable;
uniform vec4 u_particle_color;
uniform vec4 u_verbose_particle_color;
uniform vec4 u_neighbor_particle_color;
uniform vec2 u_n_to_v_scale_factor;
uniform highp float u_particle_vis_size;

const float THRESHOLD = 0.5;

void start() {
	// called when a particle is spawned
	COLOR = vec4(u_particle_color.r, 0.0, 0.0, 1.0);
}

void process() {
	// called every frame on existing particles (according to the Fixed FPS property)
	
	// we assume a square image
	ivec2 particle_pos_img_size = textureSize(u_particle_pos_temp_img, 0);
	float size = float(particle_pos_img_size.x);
	
	// INDEX - particle index (from total particles)
	float idx = float(INDEX);
	ivec2 texel_pos = ivec2(int(mod(idx, size)), int(idx / size));
	
	// positions in normalized coordinates (viewport independent)
	// temperatures also in normalized coordinates (0 - default temperature, 1 - maximum possible temperature)
	vec4 particle_pos_temp = texelFetch(u_particle_pos_temp_img, texel_pos, 0);
	vec2 particle_pos = particle_pos_temp.rg;
	float particle_temp = particle_pos_temp.b;
	
	/*
	TRANSFORM matrix (4x4, homogenous coordinates)
	
	        [0]   [1]   [2]   [3]
	      +-----+-----+-----+------+
	x row | r00 | r01 | r02 | posX |
	y row | r10 | r11 | r12 | posY |
	z row | r20 | r21 | r22 | posZ |
	w row |  0  |  0  |  0  |  1   |
	      +-----+-----+-----+------+
	
	[0..2][0..2] = Rotation + Scale (3x3 matrix)
	[0..2][3]    = Position / Translation (posX, posY, posZ)
	[3][0..2]    = Always 0
	[3][3]       = Always 1
	
	Conceptually:
	
	| Rotation/Scale | Position |
	|      3x3       |   3x1    |
	|----------------+----------|
	|     0 0 0      |    1     |
	*/
	
	// n = normalized, v = viewport (unnormalized)
	TRANSFORM[3].xy = vec2(particle_pos.r * u_n_to_v_scale_factor.x, particle_pos.g * u_n_to_v_scale_factor.y);
	
	TRANSFORM[0].x = u_particle_vis_size;
	TRANSFORM[1].y = u_particle_vis_size;
	
	//if (particle_pos.b > THRESHOLD) {
		//// verbose particle
		//COLOR = u_verbose_particle_color;
	//}
	//else if (particle_pos.a > THRESHOLD) {
		//// neighbor particle
		//COLOR = u_neighbor_particle_color;
	//}
	//else {
		//COLOR = u_particle_color;
	//}
	
	// R channel -> density
	// G channel -> temperature
	vec4 final_color = vec4(u_particle_color.r, particle_temp, 0.0, 1.0);
	
	COLOR = final_color;
}
