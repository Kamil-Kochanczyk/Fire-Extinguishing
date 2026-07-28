#[compute]
#version 450

// this shader writes particle properties to PG grid
// it is performed once, at the end of each lagrangian simulation step
// it is a bilinear interpolation weighting of particles on the PG grid by taking advantage of the PG grid's intersection with neighborhood search grid

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

layout(set = 0, binding = 5, std430) restrict readonly buffer Energies {
    float energies[];
};

layout(set = 0, binding = 6, std430) restrict readonly buffer EvaporatedMasses {
    float evaporated_masses[];
};

layout(set = 0, binding = 7, rgba32f) uniform restrict writeonly image2D particles_to_grid_img;

layout(push_constant) uniform Parameters {
    uint particle_count;
    float smoothing_radius;    // cell size
    float poly6_2d_constant;    // 4 / (π * h^8)
    float mass;
    float total_energy_cost;
} params;

uint hash_cell(ivec2 cell) {
    return ((uint(cell.x) * 73856093u) ^ (uint(cell.y) * 19349663u)) % params.particle_count;
}

void main() {
    ivec2 pixel_coords = ivec2(gl_GlobalInvocationID.xy);
    ivec2 img_size = imageSize(particles_to_grid_img);

    if (pixel_coords.x >= img_size.x || pixel_coords.y >= img_size.y) {
        return;
    }

    // each thread corresponds to one PG grid cell (pixel)
    vec2 img_size_f = vec2(img_size);
    vec2 center_uv = (vec2(pixel_coords) + vec2(0.5, 0.5)) / img_size_f;    // pixel center in UV

    // rectangle which covers immediate neighbors, defined by centers (pixel center +/- 1 pixel)
    vec2 min_uv = (vec2(pixel_coords) - vec2(0.5, 0.5)) / img_size_f;    // center - 1 in pixel units
    vec2 max_uv = (vec2(pixel_coords) + vec2(1.5, 1.5)) / img_size_f;    // center + 1 in pixel units
    min_uv = clamp(min_uv, vec2(0.0, 0.0), vec2(1.0, 1.0));
    max_uv = clamp(max_uv, vec2(0.0, 0.0), vec2(1.0, 1.0));

    // find the cells of neighborhood search grid which intersect with the above rectangle
    // those will also form a rectangle (defined by its opposite corners, just like above)
    ivec2 min_cell = ivec2(floor(min_uv / params.smoothing_radius));
    ivec2 max_cell = ivec2(floor(max_uv / params.smoothing_radius));

    // for this cell the particle contributions will be gatherred (center cell)
    vec2 center_pix = vec2(pixel_coords) + vec2(0.5, 0.5);

    // those particle properties will be gathered
    float density_sum = 0.0;
    float energy_sum = 0.0;
    float evaporated_mass_sum = 0.0;

    // iterate over neighborhood search grid cells which "envelope" the PG grid rectangle
    for (int cy = min_cell.y; cy <= max_cell.y; ++cy) {
        for (int cx = min_cell.x; cx <= max_cell.x; ++cx) {

            // find all particles in the current neighborhood search grid cell
            ivec2 cell = ivec2(cx, cy);
            uint hash = hash_cell(cell);
            uint start_idx = start_indices[hash];
            uint end_idx = end_indices[hash];

            for (uint i = start_idx; i < end_idx; ++i) {

                // particle position in normalized coordinates
                uint pid = sorted_particle_indices[i];
                vec2 p_uv = positions[pid];

                // quick rectangle reject in UV space
                if (p_uv.x < min_uv.x || p_uv.x > max_uv.x) continue;
                if (p_uv.y < min_uv.y || p_uv.y > max_uv.y) continue;

                // particle position in pixel coordinates
                vec2 p_pix = p_uv * img_size_f;

                // distance from center cell (in pixel units)
                vec2 d = abs(p_pix - center_pix);

                // in each horizontal and vertical direction: bilinear support = 1 pixel
                if (d.x > 1.0 || d.y > 1.0) continue;

                // one distance-dependent formula for bilinear weighting (instead of 4 formulas for 4 bilinear interpolation weights)
                float w = (1.0 - d.x) * (1.0 - d.y);

                // gathering particle contributions
                density_sum += w;
                energy_sum += w * energies[pid];
                evaporated_mass_sum += w * evaporated_masses[pid];
            }
        }
    }

    float density = density_sum;
    float energy = (density > 0.0) ? (energy_sum / density) : 0.0;
    float evaporated_mass = (density > 0.0) ? (evaporated_mass_sum / density) : 0.0;

    // useful for debugging with grid visualizer
    // if (pixel_coords.x >= 11 && pixel_coords.x <= 20 && pixel_coords.y == 5) {
        // tmp[pixel_coords.x - 11] = max_cell.x - min_cell.x + 1;    // how many neighborhood search grid cells covered the PG grid rectangle in the given direction
        // tmp[pixel_coords.x - 11] = float(count);    // how many particles contributed in total to the center cell
    // }

    imageStore(particles_to_grid_img, pixel_coords, vec4(density, energy, evaporated_mass, 0.33));
}
