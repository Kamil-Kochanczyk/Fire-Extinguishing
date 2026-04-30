#[compute]
#version 450

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

layout(set = 0, binding = 4, std430) restrict readonly buffer Densities {
    float densities[];
};

layout(set = 0, binding = 5, std430) restrict readonly buffer Velocities {
    vec2 velocities[];
};

layout(set = 0, binding = 6, std430) restrict writeonly buffer Vorticities {
    float vorticities[];
};

layout(set = 0, binding = 7, std430) restrict readonly buffer IsAlive {
    uint is_alive[];
};

layout(push_constant) uniform Parameters {
    uint particle_count;
    float smoothing_radius;    // cell size
    float spiky_2d_gradient_constant;    // -30 / (π * h^5)
    float vorticity_scale;
    float mass;
} params;

uint hash_cell(ivec2 cell) {
    return ((uint(cell.x) * 73856093u) ^ (uint(cell.y) * 19349663u)) % params.particle_count;
}

void main() {
    uint id = gl_GlobalInvocationID.x;

    if (id >= params.particle_count) {
        return;
    }

    if (is_alive[id] == 0u) {
        vorticities[id] = 0.0;
        return;
    }

    if (params.vorticity_scale > 0.0) {
        vec2 pos_i = positions[id];
        vec2 vel_i = velocities[id];

        float vorticity = 0.0;

        float h = params.smoothing_radius;
        float h2 = h * h;

        ivec2 base_cell = ivec2(floor(pos_i / h));

        for (int dy = -1; dy <= 1; dy++) {
            for (int dx = -1; dx <= 1; dx++) {

                ivec2 neighbor_cell = base_cell + ivec2(dx, dy);
                uint hash = hash_cell(neighbor_cell);

                uint start_idx = start_indices[hash];
                uint end_idx = end_indices[hash];

                for (uint i = start_idx; i < end_idx; i++) {
                    uint j = sorted_particle_indices[i];

                    // avoid self in the calculations in this case
                    if (j == id) {
                        continue;
                    }

                    vec2 diff = positions[j] - pos_i;
                    float r2 = dot(diff, diff);

                    if (r2 < h2) {
                        // prevent division by zero
                        float r = sqrt(r2) + 1e-6;

                        float term = h - r;
                        float term2 = term * term;

                        float rho_j = densities[j];
                        vec2 vel_j = velocities[j];
                        vec2 vel_ij = vel_i - vel_j;

                        vec2 grad_W = params.spiky_2d_gradient_constant * term2 * ((-diff) / r);
                        
                        vorticity += (params.mass / rho_j) * ((vel_ij.x * grad_W.y) - (vel_ij.y * grad_W.x));
                    }
                }
            }
        }

        vorticities[id] = -vorticity;
    }
    else {
        vorticities[id] = 0.0;
    }
}
