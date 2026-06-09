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

// layout(set = 0, binding = 7, std430) restrict buffer Temperatures {
//     float temperatures[];
// };

// layout(set = 0, binding = 8, std430) restrict buffer LatentHeats {
//     float latent_heats[];
// };

layout(set = 0, binding = 7, std430) restrict buffer Energies {
    float energies[];
};

layout(set = 0, binding = 8, std430) restrict writeonly buffer EvaporatedMasses {
    float evaporated_masses[];
};

layout(set = 0, binding = 9, rgba16f) uniform restrict readonly image2D grid_to_particles_img;

layout(set = 0, binding = 10, std430) restrict writeonly buffer Tmp {
    float tmp[];    // used for debugging to store intermediate values like relative error between particle energy and grid energy
};

layout(push_constant) uniform Parameters {
    uint particle_count;
    float delta;
    float grid_to_particles_img_size_x;
    float grid_to_particles_img_size_y;
    float mass;
    float ambient_temperature;
    float max_temperature;
    float specific_heat_capacity;
    float heating_energy_cost;
    float vaporization_energy_cost;
    float total_energy_cost;    // heating_energy_cost + vaporization_energy_cost
    float heating_speed;
    float vaporization_speed;
    float lerp_factor;
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

float get_temperature(float energy) {
    return params.ambient_temperature + (min(energy, params.heating_energy_cost) / (params.mass * params.specific_heat_capacity));
}

float get_latent_heat(float energy) {
    return max(energy - params.heating_energy_cost, 0.0);
}

float get_energy(float temperature, float latent_heat) {
    return (params.mass * params.specific_heat_capacity * (temperature - params.ambient_temperature)) + latent_heat;
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
        float age = ages[id];
        if (lifetime != (1.0 / 0.0)) {
            age += params.delta;
        }

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
        // float modified_latent_heat = pixel.b;
        // // float new_temperature = temperatures[id] + delta_temperature;
        // // float new_temperature = modified_temperature;
        // float new_latent_heat = modified_latent_heat;

        // // get the temperature of the particle from the grid_to_particles_img using its position
        // // for simplicity we don't do any bilinear interpolation
        // vec2 pos = positions[id];
        // vec2 clamped_pos = clamp(pos, vec2(0.0), vec2(1.0));
        // vec2 grid_space_pos = vec2(clamped_pos.x * params.grid_to_particles_img_size_x, clamped_pos.y * params.grid_to_particles_img_size_y);
        // ivec2 pixel_pos = ivec2(clamp(round(grid_space_pos), vec2(0.0), vec2(params.grid_to_particles_img_size_x - 1.0, params.grid_to_particles_img_size_y - 1.0)));
        // vec4 pixel = imageLoad(grid_to_particles_img, pixel_pos);
        // float delta_temperature = pixel.r;
        // float modified_temperature = pixel.g;
        // float modified_latent_heat = pixel.b;
        // // float new_temperature = temperatures[id] + delta_temperature;
        // // float new_temperature = modified_temperature;
        // float new_latent_heat = modified_latent_heat;
        
        // // PIC-FLIP-style blending of the two temperature updates to improve stability and reduce temperature oscillations
        // // 0 -> delta, 1 -> modified, values in between blend the two updates
        // float lerp_factor = 0.005;
        // float new_temperature = max(mix(temperatures[id] + delta_temperature, modified_temperature, lerp_factor), params.ambient_temperature); // ensure temperature doesn't go below ambient
        
        // // nearest neighbor sampling
        // vec2 pos = positions[id];
        // vec2 clamped_pos = clamp(pos, vec2(0.0), vec2(1.0));
        // vec2 grid_space_pos = vec2(clamped_pos.x * params.grid_to_particles_img_size_x, clamped_pos.y * params.grid_to_particles_img_size_y);
        // ivec2 pixel_pos = ivec2(clamp(round(grid_space_pos), vec2(0.0), vec2(params.grid_to_particles_img_size_x - 1.0, params.grid_to_particles_img_size_y - 1.0)));
        // vec4 pixel = imageLoad(grid_to_particles_img, pixel_pos);
        // float fire_energy = pixel.r;
        // float modified_temperature = pixel.g;
        // float modified_latent_heat = pixel.b;

        // // bilinear interpolation sampling
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
        // float fire_energy = pixel.r;
        // float modified_temperature = pixel.g;
        // float modified_latent_heat = pixel.b;

        // nearest neighbor sampling
        // vec2 pos = positions[id];
        // vec2 clamped_pos = clamp(pos, vec2(0.0), vec2(1.0));
        // vec2 grid_space_pos = vec2(clamped_pos.x * params.grid_to_particles_img_size_x, clamped_pos.y * params.grid_to_particles_img_size_y);
        // ivec2 pixel_pos = ivec2(clamp(round(grid_space_pos), vec2(0.0), vec2(params.grid_to_particles_img_size_x - 1.0, params.grid_to_particles_img_size_y - 1.0)));
        // vec4 pixel = imageLoad(grid_to_particles_img, pixel_pos);
        // float fire_energy = pixel.r;
        // float modified_energy = pixel.g;

        // bilinear interpolation sampling
        vec2 pos = positions[id];
        vec2 clamped_pos = clamp(pos, vec2(0.0), vec2(1.0));
        vec2 grid_space_pos = clamped_pos * vec2(params.grid_to_particles_img_size_x - 1.0, params.grid_to_particles_img_size_y - 1.0);
        vec2 base_f = floor(grid_space_pos);
        ivec2 base = ivec2(base_f);
        vec2 frac = grid_space_pos - base_f;
        ivec2 max_pixel = ivec2(params.grid_to_particles_img_size_x - 1.0, params.grid_to_particles_img_size_y - 1.0);
        ivec2 p00 = clamp(base, ivec2(0), max_pixel);
        ivec2 p10 = clamp(base + ivec2(1, 0), ivec2(0), max_pixel);
        ivec2 p01 = clamp(base + ivec2(0, 1), ivec2(0), max_pixel);
        ivec2 p11 = clamp(base + ivec2(1, 1), ivec2(0), max_pixel);
        vec4 c00 = imageLoad(grid_to_particles_img, p00);
        vec4 c10 = imageLoad(grid_to_particles_img, p10);
        vec4 c01 = imageLoad(grid_to_particles_img, p01);
        vec4 c11 = imageLoad(grid_to_particles_img, p11);
        float w00 = ((c00.a > 0.0) ? ((1.0 - frac.x) * (1.0 - frac.y)) : 0.0);    // consider only cells with non-zero particle density
        float w10 = ((c10.a > 0.0) ? (frac.x * (1.0 - frac.y)) : 0.0);    // consider only cells with non-zero particle density
        float w01 = ((c01.a > 0.0) ? ((1.0 - frac.x) * frac.y) : 0.0);    // consider only cells with non-zero particle density
        float w11 = ((c11.a > 0.0) ? (frac.x * frac.y) : 0.0);    // consider only cells with non-zero particle density
        float weight_sum = w00 + w10 + w01 + w11;
        vec4 pixel = vec4(0.0);
        if (weight_sum > 0.0) {
            pixel = (w00 * c00 + w10 * c10 + w01 * c01 + w11 * c11) / weight_sum;
        }

        float delta_energy = pixel.r;    // FLIP style
        float modified_energy = pixel.g;    // PIC style
        float heat_transfer = pixel.b;

        float energy = energies[id];
        // float temperature = get_temperature(energy);
        // float latent_heat = get_latent_heat(energy);

        // float current_heating_energy = min(energy, params.heating_energy_cost);
        // float heating_energy_desirable = params.heating_energy_cost - current_heating_energy;
        // float heating_energy_used = min(delta_energy, heating_energy_desirable);
        // temperature += (1.0 * (heating_energy_used / (params.mass * params.specific_heat_capacity)));    // heating happens when still no mass is evaporated
        // temperature = mix(temperature, get_temperature(modified_energy), params.lerp_factor);    // 0 -> temp computed here based on the acquired energy (FLIP-like, grainy), 1 -> temp precomputed on the grid in the fragment shader (PIC-like, smooth), values in between blend the two updates
        // temperature = clamp(temperature, params.ambient_temperature, params.max_temperature);    // ensure temperature stays within [ambient, max]

        // only when the particle reaches the max temperature, it can start vaporizing and thus gain latent heat
        // if (temperature >= params.max_temperature) {
            // float orig_latent_heat = latent_heat;
            // float delta_energy_left = delta_energy - heating_energy_used;
            // float vaporization_energy_desirable = params.vaporization_energy_cost - latent_heat;
            // float vaporization_energy_used = min(delta_energy_left, vaporization_energy_desirable);
            // latent_heat += (1.0 * vaporization_energy_used);
            // latent_heat = mix(latent_heat, get_latent_heat(modified_energy), params.lerp_factor);    // 0 -> latent heat computed here based on the acquired energy (FLIP-like, grainy), 1 -> latent heat precomputed on the grid in the fragment shader (PIC-like, smooth), values in between blend the two updates
            // latent_heat = clamp(latent_heat, 0.0, params.vaporization_energy_cost);    // ensure latent heat stays within [0, vaporization_energy_cost]
            // evaporated_mass = max(0.0, (latent_heat - orig_latent_heat) / params.vaporization_energy_cost);    // compute the evaporated mass based on the change in latent heat, store % to avoid small numbers
        // }

        float new_energy;

        if (heat_transfer > 0.0) {
            new_energy = clamp(mix(energy + delta_energy, modified_energy, params.lerp_factor), 0.0, params.total_energy_cost);
        }
        else {
            new_energy = energy;
        }

        float evaporated_mass = max(0.0, (get_latent_heat(new_energy) - get_latent_heat(energy)) / params.vaporization_energy_cost);    // compute the evaporated mass based on the change in latent heat, store % to avoid small numbers

        // tmp[id] = new_energy;

        // if age exceeds lifetime of a mortal particle or latent heat reaches vaporization threshold, this particle is killed (becomes dead)
        if (((lifetime != (1.0 / 0.0)) && (age > lifetime)) || (new_energy >= params.total_energy_cost)) {
            ages[id] = 0.0;
            // temperatures[id] = params.ambient_temperature;
            // latent_heats[id] = 0.0;
            energies[id] = 0.0;
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
            // temperatures[id] = temperature;
            // latent_heats[id] = latent_heat;
            energies[id] = new_energy;
        }

        evaporated_masses[id] = evaporated_mass;
    }
}
