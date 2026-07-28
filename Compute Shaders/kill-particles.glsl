#[compute]
#version 450

layout(local_size_x = 256, local_size_y = 1, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) restrict writeonly buffer Positions {
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

layout(set = 0, binding = 7, std430) restrict buffer Energies {
    float energies[];
};

layout(push_constant) uniform Parameters {
    uint particle_count;
    float delta;
    float total_energy_cost;    // heating_energy_cost + vaporization_energy_cost
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

        // energy tells us if a particle is fully evaporated or not
        float energy = energies[id];

        // if age exceeds lifetime of a mortal particle or latent heat reaches vaporization threshold, this particle is killed (becomes dead)
        if (((lifetime != (1.0 / 0.0)) && (age > lifetime)) || (energy >= params.total_energy_cost)) {

            // go back to default values
            ages[id] = 0.0;
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
            // the particle stays alive but its age is increased
            ages[id] = age;
        }
    }
}
