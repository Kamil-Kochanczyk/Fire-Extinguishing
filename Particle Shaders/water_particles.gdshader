shader_type particles;

uniform highp sampler2D u_particle_pos_ener_img : filter_nearest, repeat_disable;
uniform vec4 u_particle_color;
uniform vec2 u_n_to_v_scale_factor;
uniform float u_particle_vis_size;
uniform float u_particle_temp_ambient;
uniform float u_particle_temp_max;
uniform float u_heating_energy_cost;
uniform float u_vaporization_energy_cost;
uniform float u_mass;
uniform float u_specific_heat_capacity;

void start() {
	// called when a particle is spawned
	COLOR = vec4(u_particle_color.r, 0.0, 0.0, 1.0);
}

void process() {
	// called every frame on existing particles (according to the Fixed FPS property)
	
	// we assume a square image
	ivec2 particle_pos_ener_img_size = textureSize(u_particle_pos_ener_img, 0);
	float size = float(particle_pos_ener_img_size.x);
	
	// INDEX - particle index (from total particles)
	float idx = float(INDEX);
	ivec2 texel_pos = ivec2(int(mod(idx, size)), int(idx / size));
	
	// positions are in normalized coordinates (viewport independent)
	// energies are in the range [0, heating energy cost + vaporization energy cost]
	vec4 particle_pos_ener = texelFetch(u_particle_pos_ener_img, texel_pos, 0);
	vec2 particle_pos = particle_pos_ener.rg;
	float particle_ener = particle_pos_ener.b;
	
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
	
	// position
	// n = normalized, v = viewport (unnormalized)
	TRANSFORM[3].xy = vec2(particle_pos.r * u_n_to_v_scale_factor.x, particle_pos.g * u_n_to_v_scale_factor.y);
	
	// scale
	TRANSFORM[0].x = u_particle_vis_size;
	TRANSFORM[1].y = u_particle_vis_size;
	
	// R channel -> density
	// G channel -> temperature
	// B channel -> latent heat
	// smooth transition from red, to yellow, to white differentiates between heating and vaporization stages
	float temperature = u_particle_temp_ambient + (min(particle_ener, u_heating_energy_cost) / (u_mass * u_specific_heat_capacity));
	float normalized_temperature = (temperature - u_particle_temp_ambient) / (u_particle_temp_max - u_particle_temp_ambient);
	float latent_heat = max(particle_ener - u_heating_energy_cost, 0.0);
	float normalized_latent_heat = latent_heat / u_vaporization_energy_cost;
	vec4 final_color = vec4(u_particle_color.r, normalized_temperature, normalized_latent_heat, 1.0);
	
	COLOR = final_color;
}
