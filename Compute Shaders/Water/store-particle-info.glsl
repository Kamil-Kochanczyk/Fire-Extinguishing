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

layout(set = 0, binding = 5, std430) restrict readonly buffer Temperatures {
    float temperatures[];
};

layout(set = 0, binding = 6, rgba32f) uniform restrict writeonly image2D particles_to_grid_img;

layout(push_constant) uniform Parameters {
    uint particle_count;
    float smoothing_radius;    // cell size
    float poly6_2d_constant;    // 4 / (π * h^8)
    float mass;
    float max_temperature;
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

    // float temperature_sum = 0.0;
    // float weight_sum = 0.0;
    float temperature = 0.0;
    // float count = 0.0;

    vec2 uv = (vec2(pixel_coords) + 0.5) / vec2(img_size);

    float h2 = params.smoothing_radius * params.smoothing_radius;

    // base cell variable is already in grid coordinates (not in world coordinates!)
    // offsets like -1, 0, +1 can be used with grid coordinates
    ivec2 base_cell = ivec2(floor(uv / params.smoothing_radius));

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

                vec2 diff = positions[neighbor_idx] - uv;
                float r2 = dot(diff, diff);

                if (r2 < h2) {
                    // float term = h2 - r2;
                    // float w = params.poly6_2d_constant * term * term * term;    // (h^2 - r^2)^3
                    // float weight = params.mass * (1.0 / max(densities[neighbor_idx], 1e-6)) * w;
                    // temperature_sum += weight * temperatures[neighbor_idx];
                    // weight_sum += weight;

                    // float w = 1.0 - (sqrt(r2) / params.smoothing_radius);    // linear weight based on distance
                    // temperature_sum += w * params.mass * temperatures[neighbor_idx];
                    // weight_sum += w * params.mass;

                    temperature = max(temperature, temperatures[neighbor_idx]);    // take the maximum temperature among the particles in the neighboring cells

                    // temperature += temperatures[neighbor_idx];
                    // count += 1.0;
                }
            }
        }
    }

    // if (count > 0.0) {
    //     temperature /= count;    // average temperature of the particles in the neighboring cells
    // } else {
    //     temperature = 0.0;
    // }

    // temperature = (weight_sum > 0.0) ? (temperature_sum / weight_sum) : 0.0;    // weighted average temperature of the particles in the neighboring cells

    imageStore(particles_to_grid_img, pixel_coords, vec4(min(temperature, params.max_temperature), 0.0, 0.0, 0.33));
}
