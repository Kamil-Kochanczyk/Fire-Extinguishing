#[compute]
#version 450

// compute shader used in neighborhood search
// for each hash it computes its range of indices in the buffers already sorted by parallel radix sort
// start index = first index
// end index = last index + 1
// thus, we construct [start, end) (exclusive) ranges for each hash
// we don't use [start, end] (inclusive) ranges because [start, end) give us a nicer condition in the loop
// i.e. "for (i = start; i < end; i++) {}" is better than "for (i = start; i <= end; i++) {}"
// moreover, [start, end) naturally handles the empty range case (end == start) and allows us to easily calcualte range length (range length = end - start)
// note that in each frame some hashes can have outdated start and end indices from previous frames because non-empty cells can become empty cells and vice versa

layout(local_size_x = 256, local_size_y = 1, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) restrict readonly buffer Hashes {
    uint hashes[];
};

layout(set = 0, binding = 1, std430) restrict writeonly buffer StartIndices {
    uint start_indices[];
};

layout(set = 0, binding = 2, std430) restrict writeonly buffer EndIndices {
    uint end_indices[];
};

layout(push_constant) uniform Parameters {
    uint particle_count;    // determines the total number of hashes that we can have
} params;

void main() {
    uint id = gl_GlobalInvocationID.x;

    if (id >= params.particle_count) {
        return;
    }

    uint hash = hashes[id];

    if ((id == 0) || (hash != hashes[id - 1])) {
        start_indices[hash] = id;

        if (id > 0) {
            end_indices[hashes[id - 1]] = id;
        }
    }

    if (id == (params.particle_count - 1)) {
        end_indices[hash] = params.particle_count;
    }
}
