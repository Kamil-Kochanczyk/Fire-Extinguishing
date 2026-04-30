#[compute]
#version 450

layout(local_size_x = 256, local_size_y = 1, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) restrict readonly buffer Positions {
    vec2 positions[];
};

layout(set = 0, binding = 1, std430) restrict readonly buffer Velocities {
    vec2 velocities[];
};

layout(set = 0, binding = 2, std430) restrict readonly buffer SortedParticleIndices {
    uint sorted_particle_indices[];
};

layout(set = 0, binding = 3, std430) restrict readonly buffer StartIndices {
    uint start_indices[];
};

layout(set = 0, binding = 4, std430) restrict readonly buffer EndIndices {
    uint end_indices[];
};

layout(set = 0, binding = 5, std430) restrict readonly buffer Densities {
    float densities[];
};

layout(set = 0, binding = 6, std430) restrict readonly buffer Pressures {
    float pressures[];
};

layout(set = 0, binding = 7, std430) restrict readonly buffer NearDensities {
    float near_densities[];
};

layout(set = 0, binding = 8, std430) restrict readonly buffer NearPressures {
    float near_pressures[];
};

layout(set = 0, binding = 9, std430) restrict readonly buffer Vorticities {
    float vorticities[];
};

layout(set = 0, binding = 10, std430) restrict writeonly buffer Forces {
    vec2 forces[];
};

layout(set = 0, binding = 11, std430) restrict readonly buffer IsAlive {
    uint is_alive[];
};

layout(push_constant) uniform Parameters {
    uint particle_count;
    float smoothing_radius;    // cell size
    float spiky_2d_gradient_constant;    // -30 / (π * h^5)
    float visc_2d_laplacian_constant;    // 40 / (π * h^5)
    float viscosity_scale;
    float gravity_x;
    float gravity_y;
    float mouse_pos_x;
    float mouse_pos_y;
    float mouse_interaction_radius;
    float mouse_interaction_strength;
    float surface_tension_threshold;
    float surface_tension_scale;
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
        forces[id] = vec2(0.0, 0.0);
        return;
    }

    vec2 pos_i = positions[id];
    vec2 vel_i = velocities[id];
    float p_i = pressures[id];
    float rho_i = densities[id];
    float p_i_near = near_pressures[id];
    float rho_i_near = near_densities[id];
    float vorticity_i = vorticities[id];

    vec2 force = vec2(0.0, 0.0);

    vec2 gradient_c = vec2(0.0, 0.0);
    float laplacian_c = 0.0;

    vec2 grad_abs_vorticity = vec2(0.0, 0.0);

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

                vec2 diff = pos_i - positions[j];
                float r2 = dot(diff, diff);

                if (r2 < h2) {
                    // prevent division by zero
                    float r = sqrt(r2) + 1e-6;

                    float term = h - r;
                    float term2 = term * term;

                    float scaling_near = (1.0 - (r / h));

                    vec2 gradient_W_dir = ((-diff) / r);

                    vec2 gradient_W = params.spiky_2d_gradient_constant * term2 * gradient_W_dir;
                    float laplacian_W = params.visc_2d_laplacian_constant * term;

                    // pressure force (pressure term in Navier-Stokes)
                    float p_j = pressures[j];
                    float rho_j = densities[j];
                    // float p_sym_term = ((p_i + p_j) / (2.0 * rho_j));
                    float p_sym_term = (p_i / (rho_i * rho_i)) + (p_j / (rho_j * rho_j));
                    vec2 f_pressure = params.mass * p_sym_term * gradient_W;
                    force += f_pressure;

                    // near pressure force (purely repulsive, anti-clumping)
                    float p_j_near = near_pressures[j];
                    float rho_j_near = near_densities[j];
                    // float p_sym_term_near = ((p_i_near + p_j_near) / (2.0 * rho_j_near));
                    float p_sym_term_near = (p_i_near / (rho_i_near * rho_i_near)) + (p_j_near / (rho_j_near * rho_j_near));
                    vec2 f_pressure_near = (scaling_near * scaling_near * scaling_near) * params.mass * p_sym_term_near * gradient_W;
                    force += f_pressure_near;

                    // viscosity force (viscosity term in Navier-Stokes)
                    vec2 vel_j = velocities[j];
                    vec2 f_viscosity = params.viscosity_scale * params.mass * ((vel_j - vel_i) / rho_j) * laplacian_W;
                    force += f_viscosity;

                    // surface tension force (accumulation of gradient and laplacian of color field)
                    if (params.surface_tension_scale > 0.0) {
                        gradient_c += (params.mass / rho_j) * gradient_W;
                        laplacian_c += (params.mass / rho_j) * laplacian_W;
                    }

                    // vorticity confinement force (accumulation of gradient of absolute vorticity)
                    if (params.vorticity_scale > 0.0) {
                        float vorticity_j = vorticities[j];
                        grad_abs_vorticity += (params.mass / rho_j) * abs(vorticity_j) * gradient_W;
                    }
                }
            }
        }
    }

    // external forces: gravity + user interaction which attracts/repels particles near the mouse position and modifies gravity there

    float gravity_weight = 1.0;

    if (params.mouse_interaction_strength != 0.0) {
        vec2 offset = vec2(params.mouse_pos_x, params.mouse_pos_y) - pos_i;
        float offset2 = dot(offset, offset);

        if (offset2 < (params.mouse_interaction_radius * params.mouse_interaction_radius)) {
            float offset_len = sqrt(offset2) + 1e-6;

            // offset_len = 0.0 -> centre_closeness = 1.0
            // offset_len = params.mouse_interaction_radius -> centre_closeness = 0.0
            float centre_closeness = 1.0 - (offset_len / params.mouse_interaction_radius);

            // reduce gravity near the center
            gravity_weight = 1.0 - (centre_closeness * clamp(abs(params.mouse_interaction_strength) / 10.0, 0.0, 1.0));

            // attractive/repulsive acceleration stronger near the center
            vec2 dir_to_centre = offset / offset_len;
            vec2 a = dir_to_centre * centre_closeness * params.mouse_interaction_strength;

            // damping that slows down those particles which are near the center
            a -= vel_i * centre_closeness;

            // convert to force using Newton's second law for tiny volumes
            force += rho_i * a;
        }
    }

    force += rho_i * vec2(params.gravity_x, params.gravity_y) * gravity_weight;

    // external forces: surface tension force which also serves as a cohesive force
    if (params.surface_tension_scale > 0.0) {
        float len2 = dot(gradient_c, gradient_c);

        if (len2 > (params.surface_tension_threshold * params.surface_tension_threshold)) {
            vec2 gradient_c_dir = gradient_c / sqrt(len2);
            force += params.surface_tension_scale * (-laplacian_c) * gradient_c_dir;
        }
    }

    // external forces: vorticity confinement force
    if (params.vorticity_scale > 0.0) {
        vec2 grad_abs_vorticity_dir = normalize(grad_abs_vorticity + 1e-6);
        vec2 perp = vec2(grad_abs_vorticity_dir.y, -grad_abs_vorticity_dir.x);
        force += params.vorticity_scale * vorticity_i * perp;
    }

    forces[id] = force;
}
