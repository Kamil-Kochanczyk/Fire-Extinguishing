#[compute]
#version 450

// compute shader used in PCISPH
// second part of the iterative loop
// calculates predicted densities and updates pressures based on predicted density errors relative to rest density
// it uses the neighborhood search data calculated for the original (not predicted) positions
// the predicted positions can be different from the original positions so this might cause some small errors in the calculations
// we reuse the same neighborhood search data to avoid recalculting it in every iteration and thus save time

layout(local_size_x = 256, local_size_y = 1, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) restrict readonly buffer PredictedPositions {
    vec2 predicted_positions[];
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

layout(set = 0, binding = 4, std430) restrict writeonly buffer PredictedDensities {
    float predicted_densities[];
};

layout(set = 0, binding = 5, std430) restrict buffer Pressures {
    float pressures[];
};

layout(set = 0, binding = 6, std430) restrict readonly buffer IsAlive {
    uint is_alive[];
};

layout(push_constant) uniform Parameters {
    uint particle_count;
    float smoothing_radius;    // cell size
    float poly6_2d_constant;    // 4 / (π * h^8)
    float mass;
    float rest_density;
    float sigma;
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
        predicted_densities[id] = 0.0;
        return;
    }

    vec2 pos = predicted_positions[id];

    float density = 0.0;

    float h = params.smoothing_radius;
    float h2 = h * h;

    ivec2 base_cell = ivec2(floor(pos / h));

    for (int dy = -1; dy <= 1; dy++) {
        for (int dx = -1; dx <= 1; dx++) {

            ivec2 neighbor_cell = base_cell + ivec2(dx, dy);
            uint hash = hash_cell(neighbor_cell);

            uint start_idx = start_indices[hash];
            uint end_idx = end_indices[hash];

            for (uint i = start_idx; i < end_idx; i++) {
                uint neighbor_idx = sorted_particle_indices[i];

                // include self in the calculations, i.e. neighbor_idx = id is good

                vec2 diff = predicted_positions[neighbor_idx] - pos;
                float r2 = dot(diff, diff);

                if (r2 < h2) {
                    float term = h2 - r2;
                    density += term * term * term;    // (h^2 - r^2)^3
                }
            }
        }
    }

    float predicted_density = params.poly6_2d_constant * params.mass * density;
    float predicted_density_error = predicted_density - params.rest_density;
    float updated_pressure = pressures[id] + (0.05 * params.sigma * predicted_density_error);    // without the scaling factor the simulation seems to be unstable, for some reason

    predicted_densities[id] = predicted_density;
    pressures[id] = updated_pressure;
}
