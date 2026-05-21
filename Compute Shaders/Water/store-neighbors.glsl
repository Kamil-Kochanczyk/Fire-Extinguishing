#[compute]
#version 450

// compute shader used to visualize that the neighborhood search actually works
// it calculates 0/1 flags for all particles
// those flags mark whether a given particle is a neighbor of some chosen, verbose particle, or not
// this compute shader isoutdated and shouldn't be used anymore due to the fact that the texture used here is now used to store the energies of the particles

layout(local_size_x = 256, local_size_y = 1, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) restrict readonly buffer Positions {
    vec2 positions[];
};

layout(set = 0, binding = 1, std430) restrict readonly buffer SortedParticleIndices {
    uint sorted_particle_indices[];
};

layout(set = 0, binding = 2, std430) restrict readonly buffer StartIndices {
    uint start_indices[];
};

layout(set = 0, binding = 3, std430) restrict readonly buffer EndIndices {
    uint end_indices[];
};

layout(set = 0, binding = 4, std430) restrict writeonly buffer NeighborFlags {
    uint neighbor_flags[];
};

layout(set = 0, binding = 5, rgba32f) uniform restrict writeonly image2D particle_pos_img;

layout(push_constant) uniform Parameters {
    uint particle_count;
    float smoothing_radius;    // cell size
    float image_size;
    uint verbose_particle_idx;
} params;

uint hash_cell(ivec2 cell) {
    return ((uint(cell.x) * 73856093u) ^ (uint(cell.y) * 19349663u)) % params.particle_count;
}

void main() {
    uint id = gl_GlobalInvocationID.x;

    if (id >= params.particle_count) {
        return;
    }

    bool is_verbose = (id == params.verbose_particle_idx);
    
    // this loop is rather inefficient
    // but it is the easiest way to visualize the neighborhood search and to verify that it works
    if (is_verbose) {
        for (uint i = 0; i < params.particle_count; i++) {
            neighbor_flags[i] = 0u;
        }
    }

    vec2 pos = positions[id];

    float h2 = params.smoothing_radius * params.smoothing_radius;

    // base cell variable is already in grid coordinates (not in world coordinates!)
    // offsets like -1, 0, +1 can be used with grid coordinates
    ivec2 base_cell = ivec2(floor(pos / params.smoothing_radius));

    // loop over 3x3 neighboring cells
    // start from the first row (top-left corner) and move rightwards, then move on to the next row and again move rightwards, and then again do the same thing for the last row
    // (-1,-1) (0,-1) (1,-1)
    // (-1, 0) (0, 0) (1, 0)
    // (-1, 1) (0, 1) (1, 1)
    for (int dy = -1; dy <= 1; dy++) {
        for (int dx = -1; dx <= 1; dx++) {

            ivec2 neighbor_cell = base_cell + ivec2(dx, dy);
            uint hash = hash_cell(neighbor_cell);
            uint start_idx = start_indices[hash];
            uint end_idx = end_indices[hash];

            for (uint i = start_idx; i < end_idx; i++) {
                uint neighbor_idx = sorted_particle_indices[i];

                // avoid self
                if (neighbor_idx == id) {
                    continue;
                }

                vec2 pos_neighbor = positions[neighbor_idx];
                vec2 diff = pos_neighbor - pos;
                float dist_sqr = dot(diff, diff);

                bool is_within = (dist_sqr < h2);

                if (is_verbose && is_within) {
                    neighbor_flags[neighbor_idx] = 1u;
                }
            }
        }
    }

    ivec2 pixel_pos = ivec2(int(mod(id, params.image_size)), int(id / params.image_size));

    imageStore(particle_pos_img, pixel_pos, vec4(positions[id].x, positions[id].y, (is_verbose ? 1.0 : 0.0), 0.0));
}
