#[compute]
#version 450

// compute shader used in PCISPH
// third part of the iterative loop
// calculates pressure forces based on the predicted densities and updated pressures

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

layout(set = 0, binding = 4, std430) restrict readonly buffer PredictedDensities {
    float predicted_densities[];
};

layout(set = 0, binding = 5, std430) restrict readonly buffer Pressures {
    float pressures[];
};

layout(set = 0, binding = 6, std430) restrict writeonly buffer PressureForces {
    vec2 pressure_forces[];
};

layout(set = 0, binding = 7, std430) restrict readonly buffer IsAlive {
    uint is_alive[];
};

layout(push_constant) uniform Parameters {
    uint particle_count;
    float smoothing_radius;    // cell size
    float spiky_2d_gradient_constant;    // 4 / (π * h^8)
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

    if (is_alive[id] == 1u) {
        vec2 pos_i = predicted_positions[id];
        float p_i = pressures[id];
        float rho_i = predicted_densities[id];

        vec2 pressure_force = vec2(0.0, 0.0);

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

                    vec2 diff = pos_i - predicted_positions[j];
                    float r2 = dot(diff, diff);

                    if (r2 < h2) {
                        // prevent division by zero
                        float r = sqrt(r2) + 1e-6;

                        float term = h - r;
                        float term2 = term * term;

                        vec2 gradient_W_dir = diff / r;

                        vec2 gradient_W = params.spiky_2d_gradient_constant * term2 * gradient_W_dir;

                        // pressure force (pressure term in Navier-Stokes)
                        float p_j = pressures[j];
                        float rho_j = predicted_densities[j];
                        // float p_sym_term = ((p_i + p_j) / (2.0 * rho_j));    // if using this term, remove the rho_i multiplier in the calculation of f_pressure below
                        float p_sym_term = (p_i / (rho_i * rho_i)) + (p_j / (rho_j * rho_j));    // if using this term, include the rho_i multiplier in the calculation of f_pressure below
                        vec2 f_pressure = rho_i * params.mass * p_sym_term * (-gradient_W);
                        pressure_force += f_pressure;
                    }
                }
            }
        }

        pressure_forces[id] = pressure_force;
    }
}
