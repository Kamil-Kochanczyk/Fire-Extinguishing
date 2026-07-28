#[compute]
#version 450

// parallel radix sort, part 6 (final)
// this shader is used to move the elements of the unsorted array to their correct positions in the sorted array
// note that this shader sorts by digits, not by full numbers
// in our case a digit is a group of 4-bits of 32-bit unsigned integers
// so by "sorted" we mean "sorted by the digit being currently processed by parallel radix sort"
// if we want the array to be fully sorted we need 8 iterations of the entire pipeline (1 iteration for each group of 4 bits)
// we find the correct spots for all elements by using the offsets calculated in part 5
// each thread in a given group finds its key in the array to sort and extracts the correct digit from that key
// based on the digit and on the work group it's in, it finds the correct subbucket in the final array
// it then places its key in the found subbucket
// because in a given work group multiple threads can extract the same digit, all threads need to agree on the order
// e.g. they need to decide which one of them gets the first spot in the subbucket, which one gets the second spot, etc.
// earlier threads should get earlier spots in the subbuckets to preserve stability and correctness of the entire algorithm
// we solve this issue by assigning a rank to each thread based on the counters of the digits
// we do it using a naive for loop (this is the main place in the entire parallel radix sort pipeline which can/should be optimized)
// I tried different approaches to calculating ranks and the naive for loop as of now turns out to be the winner
// we can delete the value buffers/variables from this shader if we only sort keys, not key-value pairs

// each work group can process up to 256 elements of the array (same as in part 1)
layout(local_size_x = 256, local_size_y = 1, local_size_z = 1) in;

// the array to sort
layout(set = 0, binding = 0, std430) restrict readonly buffer KeysIn {
    uint keys_in[];
};

// the sorted array
layout(set = 0, binding = 1, std430) restrict writeonly buffer KeysOut {
    uint keys_out[];
};

// computed in part 5
layout(set = 0, binding = 2, std430) restrict readonly buffer GroupOffsets {
    uint group_offsets[];
};

// the values to sort by their corresponding keys
layout(set = 0, binding = 3, std430) restrict readonly buffer ValuesIn {
    uint values_in[];
};

// the values sorted by their corresponding keys
layout(set = 0, binding = 4, std430) restrict writeonly buffer ValuesOut {
    uint values_out[];
};

// used to determine the ranks of threads (positions within digit subbuckets in case of multiple threads processing the same digits)
shared uint s_digits[256];

layout(push_constant) uniform Parameters {
    uint shift;    // 0, 4, 8, ..., 28 (depending on which group of 4 bits we're currently processing)
    uint keys_size;    // the algorithm works with arrays of arbitrary sizes
} params;

void main() {
    // lid = 0 1 2 ... 255
    uint lid = gl_LocalInvocationID.x;

    // gid = 0 1 2 ... array_size-1 (gids greater than array_size-1 will be ignored in the shader)
    uint gid = gl_GlobalInvocationID.x;

    // group = 0 1 2 ... g ... G-1, where G is the number of work groups, G = ceil(array_size / 256)
    uint group = gl_WorkGroupID.x;

    // invalid digit, used for rank calculation later (valid digits are 0-15)
    // needs to be changed accordingly if we want to use digits defined differently than as 4 bit groups
    s_digits[lid] = 42;

    // sync
    barrier();

    // init
    uint key = 0;
    uint value = 0;
    uint digit = 0;

    // needed in two if statements, so we define it once here
    bool valid = (gid < params.keys_size);

    // only valid threads contribute
    if (valid) {

        // element in the unsorted array corresponding to the given thread
        key = keys_in[gid];
        value = values_in[gid];

        // same as in part 1
        digit = (key >> params.shift) & 0xF;

        // store digit in shared memory
        s_digits[lid] = digit;
    }

    // sync
    barrier();

    // only valid threads contribute
    if (valid) {

        // rank starts from 0, rank = 0 1 2 ...
        // this naive for loop is a potential performance killer
        uint rank = 0;
        for (uint i = 0; i < lid; i++) {
            if (s_digits[i] == digit) {
                rank++;
            }
        }

        // find the group offset in group_offsets[group][digit] corresponding to the given group and digit
        uint global_offset = group_offsets[group * 16 + digit];

        // final position of the element in the sorted array
        uint final_index = global_offset + rank;

        // congratulations, you finally sorted the array :)
        keys_out[final_index] = key;
        values_out[final_index] = value;
    }
}
