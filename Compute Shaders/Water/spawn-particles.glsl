#[compute]
#version 450

// each thread corresponds to one dead particle being spawned (spawning = making the particle alive again)
// how many threads will actually succeed in spawning their corresponding dead particles depends on spawn_count and dead_count
// 
// dead_stack contains particles (or rather their IDs) which are currently marked as dead
// dead_count tracks where the stack ends
// after the end of the stack we have garbage values
// the maximum possible size of the stack is equal to the maximum number of particles
// only the first dead_count elements are valid
// 
// for example:
//     dead_stack     = [7, 3, 9, -, -, -, ..., -]
//     dead_stack_idx =  0  1  2  3  4  5  ... N-1
//                                ^
//                                |
//                                |
//                                |
//                          dead_count = 3
// 
// atomicAdd(x, y):
//     old = x
//     x = x + y
//     return old
// 
// atomicSub is equivalent to atomicAdd with a negative value
// 
// for example:
//     dead_count = 3; -> uint result = atomicAdd(dead_count, 0); -> result is 3 and dead_count is still 3 (unchanged) -> atomicAdd(x, 0) = safe way to READ x
//     dead_count = 3; -> uint result = atomicAdd(dead_count, -1); -> result is 3 and dead_count is 2
// 
// spawning is done via placing particles randomly in a square grid of cells around the mouse position
// each cell can be associated with exactly one particle and all neighboring cells are particle_spacing apart
// the size of the grid is determined by how many particles we want to spawn
// this tries to ensure that the particles spawned are sampled from the fluid in the same manner as the particles initially placed in the scene, i.e. with the same spacing and rest density
// to properly center the grid around the mouse position we want an odd number of cells so that there is a center cell (0, 0) and an equal number of cells on each side
// to prevent the particles from being spawned in the same place in each dispatch we add a random offset to the grid
// this offset is also in particle_spacing units to maintain the correct spacing between particles

layout(local_size_x = 256, local_size_y = 1, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) restrict writeonly buffer Positions {
    vec2 positions[];
};

layout(set = 0, binding = 1, std430) restrict writeonly buffer Velocities {
    vec2 velocities[];
};

layout(set = 0, binding = 2, std430) restrict writeonly buffer Ages {
    float ages[];
};

layout(set = 0, binding = 3, std430) restrict writeonly buffer IsAlive {
    uint is_alive[];
};

layout(set = 0, binding = 4, std430) restrict readonly buffer DeadStack {
    uint dead_stack[];
};

layout(set = 0, binding = 5, std430) restrict buffer DeadCount {
    int dead_count;
};

// layout(set = 0, binding = 6, std430) restrict writeonly buffer Temperatures {
//     float temperatures[];
// };

// layout(set = 0, binding = 7, std430) restrict writeonly buffer LatentHeats {
//     float latent_heats[];
// };

layout(set = 0, binding = 6, std430) restrict writeonly buffer Energies {
    float energies[];
};

layout(set = 0, binding = 7, std430) restrict writeonly buffer EvaporatedMasses {
    float evaporated_masses[];
};

layout(push_constant) uniform Parameters {
    uint particle_count;
    uint spawn_count;
    uint spawn_seed;
    uint spawn_grid_size;    // an odd number, ceil(sqrt(spawn_count)) or ceil(sqrt(spawn_count)) + 1
    float spawn_init_vel_x;
    float spawn_init_vel_y;
    float mouse_pos_x;
    float mouse_pos_y;
    float particle_spacing;
    int spawn_random_offset_x;
    int spawn_random_offset_y;
    // float ambient_temperature;
} params;

// deterministic pseudo-random generation of uints
uint hash_uint(uint x) {
    x ^= x >> 16;
    x *= 0x7feb352d;
    x ^= x >> 15;
    x *= 0x846ca68b;
    x ^= x >> 16;
    return x;
}

void main() {
    uint id = gl_GlobalInvocationID.x;

    if ((id >= params.particle_count) || (id >= params.spawn_count)) {
        return;
    }

    // atomicSub
    int old_count = atomicAdd(dead_count, -1);
    
    // if there is at least one dead particle that can be reused, we spawn it and mark as alive
    if (old_count > 0) {
        uint dead_stack_idx = old_count - 1;
        uint dead_particle_id = dead_stack[dead_stack_idx];

        // create a unique seed per particle so they don't all pick the same spot
        uint seed = id + params.spawn_seed;

        // define how many grid cells wide the brush is
        // grid cells are particle_spacing apart
        // each grid cell can be associated with one particle
        // diameter_in_cells should be odd so that we have a center cell (0, 0) and an equal number of cells on each side
        uint diameter_in_cells = params.spawn_grid_size;
        uint range_val = (diameter_in_cells - 1) / 2;

        // each thread picks random integer coordinates on the grid
        // use hash_uint to get a big number, then use modulo to fit the brush size
        // range_val shifts the coordinates so that the (0, 0) cell is in the center of the brush
        // this way, the integer coordinates become offsets from the center of the brush
        int ix = int(hash_uint(seed) % diameter_in_cells) - int(range_val);
        int iy = int(hash_uint(seed + 1000u) % diameter_in_cells) - int(range_val);

        // map back to world space
        vec2 offset = vec2(float(ix + params.spawn_random_offset_x), float(iy + params.spawn_random_offset_y)) * params.particle_spacing;
        vec2 spawn_pos = vec2(params.mouse_pos_x, params.mouse_pos_y) + offset;

        // spawn the particle and mark it as alive
        positions[dead_particle_id] = spawn_pos;
        velocities[dead_particle_id] = vec2(params.spawn_init_vel_x, params.spawn_init_vel_y);
        // temperatures[dead_particle_id] = params.ambient_temperature;
        // latent_heats[dead_particle_id] = 0.0;
        energies[dead_particle_id] = 0.0;
        ages[dead_particle_id] = 0.0;
        is_alive[dead_particle_id] = 1u;
        evaporated_masses[dead_particle_id] = 0.0;
    } else {
        // restore the count if no dead particles found
        atomicAdd(dead_count, 1);
    }
}
