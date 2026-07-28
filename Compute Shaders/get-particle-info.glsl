#[compute]
#version 450

// this shader reads particle properties from GP grid, updates energies and computes evaporated masses
// it is performed once, at the beginning of each lagrangian simulation step

layout(local_size_x = 256, local_size_y = 1, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) restrict readonly buffer Positions {
    vec2 positions[];
};

layout(set = 0, binding = 1, std430) restrict readonly buffer IsAlive {
    uint is_alive[];
};

layout(set = 0, binding = 2, std430) restrict buffer Energies {
    float energies[];
};

layout(set = 0, binding = 3, std430) restrict writeonly buffer EvaporatedMasses {
    float evaporated_masses[];
};

layout(set = 0, binding = 4, rgba16f) uniform restrict readonly image2D grid_to_particles_img;

layout(push_constant) uniform Parameters {
    uint particle_count;
    float grid_to_particles_img_size_x;
    float grid_to_particles_img_size_y;
    float mass;
    float ambient_temperature;
    float specific_heat_capacity;
    float heating_energy_cost;
    float vaporization_energy_cost;
    float total_energy_cost;    // heating_energy_cost + vaporization_energy_cost
    float lerp_factor;
} params;

float get_latent_heat(float energy) {
    return max(energy - params.heating_energy_cost, 0.0);
}

void main() {
    uint id = gl_GlobalInvocationID.x;

    if (id >= params.particle_count) {
        return;
    }

    // consider only alive particles
    if (is_alive[id] == 1u) {

        // read particle properties from GP grid using bilinear interpolation sampling
        vec2 pos = positions[id];
        vec2 clamped_pos = clamp(pos, vec2(0.0, 0.0), vec2(1.0, 1.0));
        vec2 grid_space_pos = clamped_pos * vec2(params.grid_to_particles_img_size_x - 1.0, params.grid_to_particles_img_size_y - 1.0);
        vec2 base_f = floor(grid_space_pos);
        ivec2 base = ivec2(base_f);
        vec2 frac = grid_space_pos - base_f;
        ivec2 max_pixel = ivec2(params.grid_to_particles_img_size_x - 1.0, params.grid_to_particles_img_size_y - 1.0);
        ivec2 p00 = clamp(base, ivec2(0, 0), max_pixel);
        ivec2 p10 = clamp(base + ivec2(1, 0), ivec2(0, 0), max_pixel);
        ivec2 p01 = clamp(base + ivec2(0, 1), ivec2(0, 0), max_pixel);
        ivec2 p11 = clamp(base + ivec2(1, 1), ivec2(0, 0), max_pixel);
        vec4 c00 = imageLoad(grid_to_particles_img, p00);
        vec4 c10 = imageLoad(grid_to_particles_img, p10);
        vec4 c01 = imageLoad(grid_to_particles_img, p01);
        vec4 c11 = imageLoad(grid_to_particles_img, p11);
        float w00 = ((c00.a > 0.0) ? ((1.0 - frac.x) * (1.0 - frac.y)) : 0.0);
        float w10 = ((c10.a > 0.0) ? (frac.x * (1.0 - frac.y)) : 0.0);
        float w01 = ((c01.a > 0.0) ? ((1.0 - frac.x) * frac.y) : 0.0);
        float w11 = ((c11.a > 0.0) ? (frac.x * frac.y) : 0.0);
        float weight_sum = w00 + w10 + w01 + w11;
        vec4 pixel = vec4(0.0, 0.0, 0.0, 0.0);
        if (weight_sum > 0.0) {
            pixel = (w00 * c00 + w10 * c10 + w01 * c01 + w11 * c11) / weight_sum;    // samples only cells with non-zero particle density
        }

        // update energy using PIC-FLIP style blending
        float delta_energy = pixel.r;    // FLIP style
        float modified_energy = pixel.g;    // PIC style
        float heat_transfer = pixel.b;
        float energy = energies[id];
        float new_energy;
        if (heat_transfer > 0.0) {
            new_energy = clamp(mix(energy + delta_energy, modified_energy, params.lerp_factor), 0.0, params.total_energy_cost);
        }
        else {
            new_energy = energy;
        }

        // compute evaporated mass (no accumulation, overwriting in each invocation)
        float evaporated_mass = max(0.0, (get_latent_heat(new_energy) - get_latent_heat(energy)) / params.vaporization_energy_cost);    // compute it as % only in order to avoid small numbers

        energies[id] = new_energy;
        evaporated_masses[id] = evaporated_mass;
    }
}
