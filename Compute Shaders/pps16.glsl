#[compute]
#version 450

// parallel radix sort, part 3
// pps16 = parallel prefix sum (scan) of the array of 16 elements
// this shader can be used to compute the parallel prefix sum (scan) of an array of unsigned integers using the Blelloch scan algorithm
// its purpose is to scan an array of 16 elements (this is why we have 8 threads here: each thread processes 2 elements)
// we can use this shader in parallel radix sort pipeline
// because we don't condiser arrays of other, arbitrary sizes, this shader is simplified (we don't compute/store sums)

layout(local_size_x = 8, local_size_y = 1, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) restrict readonly buffer InputBuffer {
    uint inputtt[];
};

layout(set = 0, binding = 1, std430) restrict writeonly buffer OutputBuffer {
    uint outputtt[];
};

shared uint temp[16];

void main() {
    // gl_LocalInvocationID.x is the thread id within the work group, 0 1 2 3 ... 15
    uint tid = gl_LocalInvocationID.x;

    // gl_WorkGroupID.x is the global id of the data chunk handled by this work group (in this case it's expected to be always 0)
    // gid is the global index of the processed element in the input buffer
    // e.g. work group 0: gid 0 1 2 3 ... 15
    uint gid = tid;

    // each thread loads two values
    // after this step temp[0..15] = data block
    temp[tid] = inputtt[gid];
    temp[tid + 8] = inputtt[gid + 8];

    // without this, some threads might start computing before data is loaded
    barrier();

    // used to control the stride of the elements to be added together in each step
    uint offset = 1;

    // up-sweep (reduce) phase
    // d >>= 1 <=> d = d / 2, so iterations are d = 8, 4, 2, 1 and correspond to the levels of the binary tree
    for (uint d = 8; d > 0; d >>= 1) {
        // without this some threads might start computing before the previous step is finished
        barrier();

        // only some threads are active in each step
        if (tid < d) {
            // find the two nodes of the binary tree to be added together
            // e.g. offset = 1: thread 0 adds temp[0] and temp[1], thread 1 adds temp[2] and temp[3], ...
            //      offset = 2: thread 0 adds temp[1] and temp[3], thread 1 adds temp[5] and temp[7], ...
            //      ...
            uint ai = offset * (2 * tid + 1) - 1;
            uint bi = offset * (2 * tid + 2) - 1;

            // right_node = right_node + left_node, e.g. [a b c d e f g h] -> [a a+b c c+d e e+f g g+h]
            temp[bi] += temp[ai];
        }

        // offset <<= 1 <=> offset = offset * 2, so iterations are offset = 1, 2, 4, 8
        offset <<= 1;
    }

    // we perform exclusive scan, so we need to set the root to 0 before the down-sweep phase
    // e.g. [a b c d e f g h] -> [a b c d e f g 0]
    // we don't store the sums in this case
    barrier();
    if (tid == 0) {
        temp[15] = 0;
    }
    barrier();

    // down-sweep phase
    // d = 1, 2, 4, 8 and correspond to the levels of the binary tree in reverse order
    for (uint d = 1; d < 16; d <<= 1) {
        // offset = 8, 4, 2, 1
        offset >>= 1;

        // without this some threads might start computing before the previous step is finished
        barrier();

        // only some threads are active in each step
        if (tid < d) {
            // analogically to the up-sweep phase, we find the two nodes of the binary tree to be processed together
            uint ai = offset * (2 * tid + 1) - 1;
            uint bi = offset * (2 * tid + 2) - 1;

            // left_node = right_node, right_node = right_node + left_node, e.g. [a b c d e f g 0] -> [a b c 0 e f g 0+d]
            uint t = temp[ai];
            temp[ai] = temp[bi];
            temp[bi] += t;
        }
    }

    // each thread writes two results to the output buffer
    barrier();
    outputtt[gid] = temp[tid];
    outputtt[gid + 8] = temp[tid + 8];
}
