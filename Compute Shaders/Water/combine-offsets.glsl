#[compute]
#version 450

// parallel radix sort, part 5
// this shader is used to compute for each group the (starting) locations of their digit subbuckets in the final, sorted array
// we call those locations group offsets
// thanks to group offsets each group knows where their digit subbuckets (contained within bigger digit buckets) start in the final, sorted array
// each group offset is calculated by one thread
// one group offset corresponds to one group and one digit, i.e. we have a 2D array group_offsets[group][digit]
// thus, group_offsets[group][digit] has the same layout as group_histograms[group][digit] and prefix_groups[group][digit]
// in reality, it's also flattened to be a 1D array
// group offset is calculated by adding two numbers
// the first number is the (starting) location in the final array of the bigger digit bucket
// the second number is the (staring) location of the digit subbucket (subbuckets are within bigger buckets) relative to the above bigger digit bucket
// their sum gives us the (starting) location of the group's digit subbucket in the final array

// if total_entries is greater than 256, then we need more than one invocation of this shader
layout(local_size_x = 256, local_size_y = 1, local_size_z = 1) in;

// computed in part 3
// contains 16 elements and represents the (starting) locations in the final array of the bigger digit buckets
layout(set = 0, binding = 0, std430) restrict readonly buffer DigitTotalsAfterScan {
    uint digit_totals_after_scan[];
};

// computed in part 4
// contains total_entries elements and represents the (starting) locations of the subbucktets relative to the above bigger buckets
layout(set = 0, binding = 1, std430) restrict readonly buffer PrefixGroups {
    uint prefix_groups[];
};

// contains total_entries elements
// will be used in part 6 by the final kernel in our parallel radix sort pipeline
layout(set = 0, binding = 2, std430) restrict writeonly buffer GroupOffsets {
    uint group_offsets[];
};

layout(push_constant) uniform Parameters {
    uint total_entries;    // total_entries = num_groups * 16
} params;

void main() {
    // id = 0 1 ... total_entires-1 (bigger/invalid indices are discarded)
    uint id = gl_GlobalInvocationID.x;

    // discard
    if (id >= params.total_entries) {
        return;
    }

    // each thread lands in some column in the prefix_groups[group][digit] array
    // we find the digit corresponding to this column
    uint digit = id % 16;

    // groups_offset = bigger bucket's (starting) location relative to the final array + subbucket's (starting) location reltive to the bigger bucket's (starting) location
    // the result is the subbucket's (starting) location in the final array (this is global location, not relative)
    group_offsets[id] = digit_totals_after_scan[digit] + prefix_groups[id];
}
