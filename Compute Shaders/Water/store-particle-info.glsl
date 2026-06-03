#[compute]
#version 450

// compute shader used to store particle information in a texture representing the grid

layout(local_size_x = 16, local_size_y = 16, local_size_z = 1) in;

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

// layout(set = 0, binding = 5, std430) restrict readonly buffer Temperatures {
//     float temperatures[];
// };

// layout(set = 0, binding = 6, std430) restrict readonly buffer LatentHeats {
//     float latent_heats[];
// };

layout(set = 0, binding = 5, std430) restrict readonly buffer Energies {
    float energies[];
};

layout(set = 0, binding = 6, rgba32f) uniform restrict writeonly image2D particles_to_grid_img;

layout(set = 0, binding = 7, std430) restrict writeonly buffer Tmp {
    float tmp[];
};

layout(push_constant) uniform Parameters {
    uint particle_count;
    float smoothing_radius;    // cell size
    float poly6_2d_constant;    // 4 / (π * h^8)
    float mass;
    // float ambient_temperature;
    // float max_temperature;
    // float latent_heat_vaporization;
    // float specific_heat_capacity;
    float total_energy_cost;
} params;

uint hash_cell(ivec2 cell) {
    return ((uint(cell.x) * 73856093u) ^ (uint(cell.y) * 19349663u)) % params.particle_count;
}

// void main() {
//     ivec2 pixel_coords = ivec2(gl_GlobalInvocationID.xy);
//     ivec2 img_size = imageSize(particles_to_grid_img);
    
//     if (pixel_coords.x >= img_size.x || pixel_coords.y >= img_size.y) {
//         return;
//     }

//     float density = 0.0;

//     // float temperature_sum = 0.0;
//     // float weight_sum = 0.0;
//     // float temperature = 0.0;
//     // float count = 0.0;

//     // float latent_heat = 0.0;

//     float energy = 0.0;

//     vec2 uv = (vec2(pixel_coords) + 0.5) / vec2(img_size);

//     float h2 = params.smoothing_radius * params.smoothing_radius;

//     // base cell variable is already in grid coordinates (not in world coordinates!)
//     // offsets like -1, 0, +1 can be used with grid coordinates
//     ivec2 base_cell = ivec2(floor(uv / params.smoothing_radius));

//     // loop over 3x3 neighboring cells
//     // start from the first row (top-left corner) and move rightwards, then move on to the next row and again move rightwards, and then again do the same thing for the last row
//     // (-1,-1) (0,-1) (1,-1)
//     // (-1, 0) (0, 0) (1, 0)
//     // (-1, 1) (0, 1) (1, 1)
//     for (int dy = -1; dy <= 1; dy++) {
//         for (int dx = -1; dx <= 1; dx++) {

//             ivec2 neighbor_cell = base_cell + ivec2(dx, dy);
//             uint hash = hash_cell(neighbor_cell);
//             uint start_idx = start_indices[hash];
//             uint end_idx = end_indices[hash];

//             for (uint i = start_idx; i < end_idx; i++) {
//                 uint neighbor_idx = sorted_particle_indices[i];

//                 vec2 diff = positions[neighbor_idx] - uv;
//                 float r2 = dot(diff, diff);

//                 if (r2 < h2) {
//                     float term = h2 - r2;
//                     float w = params.poly6_2d_constant * term * term * term;    // (h^2 - r^2)^3
//                     density += w * params.mass;    // accumulate density contribution from neighboring particles

//                     // float weight = params.mass * (1.0 / max(densities[neighbor_idx], 1e-6)) * w;
//                     // temperature_sum += weight * temperatures[neighbor_idx];
//                     // weight_sum += weight;

//                     // float w = 1.0 - (sqrt(r2) / params.smoothing_radius);    // linear weight based on distance
//                     // temperature_sum += w * params.mass * temperatures[neighbor_idx];
//                     // weight_sum += w * params.mass;

//                     // temperature = max(temperature, temperatures[neighbor_idx]);    // take the maximum temperature among the particles in the neighboring cells

//                     // temperature += temperatures[neighbor_idx];
//                     // count += 1.0;

//                     // latent_heat = max(latent_heat, latent_heats[neighbor_idx]);    // take the maximum latent heat among the particles in the neighboring cells

//                     energy = max(energy, energies[neighbor_idx]);    // take the maximum energy among the particles in the neighboring cells, maximum helps against numerical dissipation
//                 }
//             }
//         }
//     }

//     // if (count > 0.0) {
//     //     temperature /= count;    // average temperature of the particles in the neighboring cells
//     // } else {
//     //     temperature = 0.0;
//     // }

//     // temperature = (weight_sum > 0.0) ? (temperature_sum / weight_sum) : 0.0;    // weighted average temperature of the particles in the neighboring cells

//     // temperature = min(temperature, params.max_temperature);    // clamp temperature to the maximum allowed value
//     // latent_heat = min(latent_heat, params.latent_heat_vaporization);    // clamp latent heat to the maximum allowed value

//     // vec2 texel_size = 1.0 / vec2(img_size);
//     // float mass = density * (texel_size.x * texel_size.y);    // mass = density * volume (in 2D, volume is area)
//     // float heating_contribution = mass * params.specific_heat_capacity * (temperature - params.ambient_temperature);
//     // float vaporization_contribution = mass * latent_heat;
//     // float total_contribution = heating_contribution + vaporization_contribution;

//     // imageStore(particles_to_grid_img, pixel_coords, vec4(density, temperature, latent_heat, total_contribution));
//     imageStore(particles_to_grid_img, pixel_coords, vec4(density, energy, 0.0, 0.33));
// }

// bilinear interpolation on the image grid by taking advantage of the neighborhood search grid
void main() {
    ivec2 pixel_coords = ivec2(gl_GlobalInvocationID.xy);
    ivec2 img_size = imageSize(particles_to_grid_img);

    if (pixel_coords.x >= img_size.x || pixel_coords.y >= img_size.y) {
        return;
    }

    vec2 imgSizeF = vec2(img_size);
    vec2 center_uv = (vec2(pixel_coords) + vec2(0.5)) / imgSizeF; // pixel center in UV

    // rectangle covering pixel center +/- 1 pixel (covers neighbors)
    vec2 min_uv = (vec2(pixel_coords) - vec2(0.5)) / imgSizeF; // center - 1.0 in pixel units
    vec2 max_uv = (vec2(pixel_coords) + vec2(1.5)) / imgSizeF; // center + 1.0 in pixel units

    // clamp rectangle to image UV domain [0,1] (Godot UVs have origin top-left)
    min_uv = clamp(min_uv, vec2(0.0), vec2(1.0));
    max_uv = clamp(max_uv, vec2(0.0), vec2(1.0));

    ivec2 min_cell = ivec2(floor(min_uv / params.smoothing_radius));
    ivec2 max_cell = ivec2(floor(max_uv / params.smoothing_radius));

    float density_sum = 0.0;
    float energy_sum = 0.0;
    float weight_sum = 0.0;

    // float energy_max = 0.0;

    vec2 center_pix = vec2(pixel_coords) + vec2(0.5);

    // int count = 0;

    for (int cy = min_cell.y; cy <= max_cell.y; ++cy) {
        for (int cx = min_cell.x; cx <= max_cell.x; ++cx) {

            ivec2 cell = ivec2(cx, cy);
            uint hash = hash_cell(cell);
            uint start_idx = start_indices[hash];
            uint end_idx = end_indices[hash];

            for (uint i = start_idx; i < end_idx; ++i) {
                uint pid = sorted_particle_indices[i];

                vec2 p_uv = positions[pid]; // particle position in UV (0..1). Convert if needed upstream.

                // quick rectangle reject in UV space
                if (p_uv.x < min_uv.x || p_uv.x > max_uv.x) continue;
                if (p_uv.y < min_uv.y || p_uv.y > max_uv.y) continue;

                // particle position in pixel coordinates
                vec2 p_pix = p_uv * imgSizeF;
                vec2 d = abs(p_pix - center_pix); // distance in pixels

                // bilinear support = 1 pixel in each axis
                if (d.x > 1.0 || d.y > 1.0) continue;

                float w = (1.0 - d.x) * (1.0 - d.y);

                density_sum += w * densities[pid];
                energy_sum += w * energies[pid];
                weight_sum += w;

                // energy_max = max(energy_max, energies[pid]);

                // count++;
            }
        }
    }

    float density = (weight_sum > 0.0) ? (density_sum / weight_sum) : 0.0;
    float energy = (weight_sum > 0.0) ? (energy_sum / weight_sum) : 0.0;
    // float energy = energy_max;

    // if (pixel_coords.x < 10 && pixel_coords.y == 5) {
    //     tmp[pixel_coords.x] = density; // debug: store the number of cells covered by the 3x3 neighborhood
    // }

    imageStore(particles_to_grid_img, pixel_coords, vec4(density, energy, 0.0, 0.33));
}
