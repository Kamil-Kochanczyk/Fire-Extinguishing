#[compute]
#version 450

// parallel radix sort, part 2
// this shader is used to compute the total sum of occurrences of each digit in the array that we want to sort with parallel radix sort
// each thread calculates total occurrences of one digit (in our case we have 16 digits (2^4 = 16), so we have 16 threads)
// it's achieved by jumping over this array: group_histograms = [ g0d0 ... g0d15 g1d0 ... g1d15 g2d0 ... g2d15 g3d0 ... gGd15 ]
// for example, thread 0 jumps over the elements (g0d0, g1d0, g2d0, ..., gGd0) and sums them up and writes the result to another buffer of size 16

// each thread sums up one digit -> 16 threads
layout(local_size_x = 16, local_size_y = 1, local_size_z = 1) in;

// global histogram
// a 2D array group_histograms[group][digit] flattened to be a 1D array
// e.g. for 16 digits we have group_histograms = [ g0d0 ... g0d15 g1d0 ... g1d15 g2d0 ... g2d15 g3d0 ... gGd15 ]
// we can still imagine it as 2D array in which columns represent digits and rows represent work groups
layout(set = 0, binding = 0, std430) restrict readonly buffer GroupHistograms {
    uint group_histograms[];
};

// digit_totals = [ d0totalcount d1totalcount ... d14totalcount d15totalcount ]
layout(set = 0, binding = 1, std430) restrict writeonly buffer DigitTotals {
    uint digit_totals[];
};

layout(push_constant) uniform Parameters {
    uint num_groups;    // number of workgroups that operate on the array, G = ceil(array_size / 256)
} params;

void main() {
    uint digit = gl_GlobalInvocationID.x;

    uint sum = 0;

    for (uint g = 0; g < params.num_groups; g++) {
        // jump over the elements (g0ddigit, g1ddigit, ..., gGddigit) and sum them up
        sum += group_histograms[g*16 + digit];
    }

    digit_totals[digit] = sum;
}
