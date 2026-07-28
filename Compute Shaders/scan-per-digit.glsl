#[compute]
#version 450

// parallel radix sort, part 4
// this shader is used to perform (exclusive) scan for each column (i.e. for each digit) of our group_histograms[group][digit] array
// note that this scan is sequential per digit, it isn't parallel like for example in part 3
// this means that this time we don't use the parallel prefix scan (sum) algorithm (Blelloch algorithm) to scan each column
// this is for simplicity
// for 16 digits and at most 1 million elements in the array to sort (we don't expect more than that) we have ~4000 groups so it should still be pretty fast
// we perform the scan of each column by taking the advantage of clever indexing of our group_histograms[group][digit] array
// this makes the implementation of this step of parallel radix sort simpler
// we can still parallelize these column scans in the future, if we need to
// we need to perform these scans because group_histograms[group][digit] tells us where each digit bucket starts and ends in our sorted array...
// ...but it doesn't tell us where the subbuckets of each group are inside those buckets

// each thread performs a scan for exactly one digit (i.e. one column) in our array
layout(local_size_x = 16, local_size_y = 1, local_size_z = 1) in;

// global histogram
// a 2D array group_histograms[group][digit] flattened to be a 1D array
// e.g. for 16 digits we have group_histograms = [ g0d0 ... g0d15 g1d0 ... g1d15 g2d0 ... g2d15 g3d0 ... gGd15 ]
// we can still imagine it as 2D array in which columns represent digits and rows represent work groups
layout(set = 0, binding = 0, std430) restrict readonly buffer GroupHistograms {
    uint group_histograms[];
};

// prefix_groups[group][digit]
// array with the same layout as group_histograms[group][digit]
// it stores the resulting scans for each digit for each group
// we again think of it as being a 2D array but in reality it's flattened so we really operate on a 1D array
// when we think of it as being a 2D array, then, again, columns represent digits and rows represent groups
// each column of prefix_groups[group][digit] is the resulting scan of the corresponding column in group_histograms[group][digit]
// e.g. for 16 digits, prefix_groups = [ 0 0 ... 0 0 g1d0scanelem g1d1scanelem ... g1d14scanelem g1d15scanelem g2d0scanelem g2d1scanelem ... g2d14scanelem g2d15scanelem ... gGd15scanelem ]
layout(set = 0, binding = 1, std430) restrict writeonly buffer PrefixGroups {
    uint prefix_groups[];
};

layout(push_constant) uniform Parameters {
    uint num_groups;    // number of workgroups that operate on the array, G = ceil(array_size / 256)
} params;

void main() {
    // digit = 0 1 ... 14 15
    uint digit = gl_GlobalInvocationID.x;

    // we perform exclusive scans
    uint sum = 0;

    // each thread has its own column to process
    // it jumps over all rows along this column from top to bottom
    // in other words: each thread handles one digit and scans across groups
    for (uint g = 0; g < params.num_groups; g++) {
        uint idx = g*16 + digit;

        prefix_groups[idx] = sum;

        sum += group_histograms[idx];
    }
}
