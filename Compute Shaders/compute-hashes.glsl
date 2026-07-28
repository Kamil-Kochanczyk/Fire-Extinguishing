#[compute]
#version 450

// compute shader used in neighborhood search
// for each particle it computes the hash of the cell that the particle is currently in
// it stores that information in the corresponding buffers
// the next step is to sort those buffers by hashes using parallel radix sort
// (keys, values) = (hashes, particle_indices) in this case

layout(local_size_x = 256, local_size_y = 1, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) restrict readonly buffer Positions {
    vec2 positions[];
};

layout(set = 0, binding = 1, std430) restrict writeonly buffer Hashes {
    uint hashes[];
};

layout(set = 0, binding = 2, std430) restrict writeonly buffer ParticleIndices {
    uint particle_indices[];
};

layout(push_constant) uniform Parameters {
    uint particle_count;
    float smoothing_radius;    // cell size
} params;

void main() {
    uint id = gl_GlobalInvocationID.x;

    if (id >= params.particle_count) {
        return;
    }

    vec2 pos = positions[id];

    // convert world coordinates into grid coordinates
    // cell offsets, like -1, 0, +1, are used with grid coordinates, not with world coordinates
    ivec2 cell = ivec2(floor(pos / params.smoothing_radius));

    // "^" = "⊕" = bitwise XOR
    // XOR return 1 if bits are different and 0 if bits are the same
    // for example 5 ^ 3 = 101 ^ 011 = 110 = 6
    // 73856093 and 19349663 are large prime numbers
    // multiplication spreads values apart, XOR blends values together
    // so, (x, y) becomes a single number (a hash) that changes a lot even for small differences and is unlikely to collide
    // we take the modulo to wrap it around a fixed range because we need to know the size of all possible hashes to preallocate buffers for them
    // but in the future this may cause more frequent collisions and unnecessary processing of particles from random cells
    // watch out - what if the position is negative?
    uint hash = (uint(cell.x) * 73856093u) ^ (uint(cell.y) * 19349663u);

    hashes[id] = hash % params.particle_count;
    particle_indices[id] = id;
}
