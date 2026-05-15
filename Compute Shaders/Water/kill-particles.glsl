#[compute]
#version 450

layout(local_size_x = 256, local_size_y = 1, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) restrict buffer Positions {
    vec2 positions[];
};

layout(set = 0, binding = 1, std430) restrict writeonly buffer Velocities {
    vec2 velocities[];
};

layout(set = 0, binding = 2, std430) restrict readonly buffer Lifetimes {
    float lifetimes[];
};

layout(set = 0, binding = 3, std430) restrict buffer Ages {
    float ages[];
};

layout(set = 0, binding = 4, std430) restrict buffer IsAlive {
    uint is_alive[];
};

layout(set = 0, binding = 5, std430) restrict writeonly buffer DeadStack {
    uint dead_stack[];
};

layout(set = 0, binding = 6, std430) restrict buffer DeadCount {
    int dead_count;
};

layout(set = 0, binding = 7, std430) restrict buffer Temperatures {
    float temperatures[];
};

layout(set = 0, binding = 8, rgba16f) uniform restrict readonly image2D grid_to_particles_img;

layout(push_constant) uniform Parameters {
    uint particle_count;
    float delta;
    float grid_to_particles_img_size_x;
    float grid_to_particles_img_size_y;
    float ambient_temperature;
    float max_temperature;
} params;

// Wang hash function for generating random numbers on the GPU
// it outputs a float in the range [0.0, 1.0]
float random(uint x) {
    x = (x ^ 61u) ^ (x >> 16u);
    x *= 9u;
    x = x ^ (x >> 4u);
    x *= 0x27d4eb2du;
    x = x ^ (x >> 15u);
    return float(x) / 4294967295.0;
}

void main() {
    uint id = gl_GlobalInvocationID.x;

    if (id >= params.particle_count) {
        return;
    }

    // consider only alive particles
    if (is_alive[id] == 1u) {

        // lifetime determines if a particle is mortal or immortal
        float lifetime = lifetimes[id];

        // increase age only for mortal particles, i.e. particles whose lifetime isn't INF
        if (lifetime != (1.0 / 0.0)) {
            float age = ages[id];
            age += params.delta;

            // // get the temperature of the particle from the grid_to_particles_img using its position
            // // perform bilinear interpolation manually using four texel reads
            // vec2 pos = positions[id];
            // vec2 clamped_pos = clamp(pos, vec2(0.0), vec2(1.0));
            // vec2 grid_space_pos = clamped_pos * vec2(params.grid_to_particles_img_size_x - 1.0, params.grid_to_particles_img_size_y - 1.0);
            // vec2 base_f = floor(grid_space_pos);
            // ivec2 base = ivec2(base_f);
            // vec2 frac = grid_space_pos - base_f;
            // ivec2 max_pixel = ivec2(params.grid_to_particles_img_size_x - 1.0, params.grid_to_particles_img_size_y - 1.0);
            // ivec2 p00 = clamp(base, ivec2(0), max_pixel);
            // ivec2 p10 = clamp(base + ivec2(1, 0), ivec2(0), max_pixel);
            // ivec2 p01 = clamp(base + ivec2(0, 1), ivec2(0), max_pixel);
            // ivec2 p11 = clamp(base + ivec2(1, 1), ivec2(0), max_pixel);
            // vec4 c00 = imageLoad(grid_to_particles_img, p00);
            // vec4 c10 = imageLoad(grid_to_particles_img, p10);
            // vec4 c01 = imageLoad(grid_to_particles_img, p01);
            // vec4 c11 = imageLoad(grid_to_particles_img, p11);
            // vec4 pixel = mix(mix(c00, c10, frac.x), mix(c01, c11, frac.x), frac.y);
            // float delta_temperature = pixel.r;
            // float modified_temperature = pixel.g;
            // // float new_temperature = temperatures[id] + delta_temperature;
            // float new_temperature = modified_temperature;

            // get the temperature of the particle from the grid_to_particles_img using its position
            // for simplicity we don't do any bilinear interpolation
            vec2 pos = positions[id];
            vec2 clamped_pos = clamp(pos, vec2(0.0), vec2(1.0));
            vec2 grid_space_pos = vec2(clamped_pos.x * params.grid_to_particles_img_size_x, clamped_pos.y * params.grid_to_particles_img_size_y);
            ivec2 pixel_pos = ivec2(clamp(round(grid_space_pos), vec2(0.0), vec2(params.grid_to_particles_img_size_x - 1.0, params.grid_to_particles_img_size_y - 1.0)));
            vec4 pixel = imageLoad(grid_to_particles_img, pixel_pos);
            float delta_temperature = pixel.r;
            float modified_temperature = pixel.g;
            // float new_temperature = temperatures[id] + delta_temperature;
            float new_temperature = modified_temperature;
            
            // if age exceeds lifetime of a mortal particle or the particle reaches its maximum possible temperature, this particle is killed (becomes dead)
            if ((age > lifetime) || (new_temperature > params.max_temperature)) {
                ages[id] = 0.0;
                temperatures[id] = params.ambient_temperature;
                is_alive[id] = 0u;

                // move the killed particle to a random position outside the simulation domain [0,1]x[0,1] using positive coordinates between 2.0 and 12.0
                // decorrelate rand_x and rand_y by adding a large constant to the input of one of them
                float rand_x = random(id);
                float rand_y = random(id + 1000u);
                positions[id] = vec2(2.0 + (rand_x * 10.0), 2.0 + (rand_y * 10.0));

                // make the killed particle stationary
                velocities[id] = vec2(0.0, 0.0);

                // add the killed particle to the dead stack so that it can be reused later
                int push_idx = atomicAdd(dead_count, 1);
                dead_stack[uint(push_idx)] = id;
            }
            else {
                // the particle stays alive but its age is increased and its temperature is updated
                ages[id] = age;
                temperatures[id] = new_temperature;
            }
        }
    }
}
