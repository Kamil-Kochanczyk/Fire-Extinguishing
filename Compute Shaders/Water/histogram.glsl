#[compute]
#version 450

// parallel radix sort, part 1
// this shader is used to count the occurrences of each of the first 16 digits (0-15) in each chunk of the array that we want to sort
// the counted values are local to each work group, not global (they need to be aggregated later)
// each thread extracts the desired digit (depending on which pass of parallel radix sort we're currently in)
// it then increments in local histogram the counter corresponding to that digit
// the final counter of each digit is then written back to the global histogram
// we count the first 16 digits because they correspond to 4 bits, 2^4 = 16
// in this version of parallel radix sort we consider the "digit" to be a group of 4 bits of a 32-bit unsinged integer
// each 32-bit unsigned integer has 8 groups of 4 bits so in the end we need 8 passes of parallel radix sort to sort our array

// each work group can process up to 256 elements of the array
layout(local_size_x = 256, local_size_y = 1, local_size_z = 1) in;

// the array to sort
layout(set = 0, binding = 0, std430) restrict readonly buffer KeysIn {
    uint keys_in[];
};

// global histogram
// a 2D array group_histograms[group][digit] flattened to be a 1D array
// e.g. for 16 digits we have group_histograms = [ g0d0 ... g0d15 g1d0 ... g1d15 g2d0 ... g2d15 g3d0 ... gGd15 ]
// we can still imagine it as 2D array in which columns represent digits and rows represent work groups
layout(set = 0, binding = 1, std430) restrict writeonly buffer GroupHistograms {
    uint group_histograms[];
};

// local histogram
// e.g. for 16 digits we have histogram = [ d0count d1count ... d14count d15count ]
shared uint local_hist[16];

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

    // initialize local histogram using the first 16 threads
    if (lid < 16) {
        local_hist[lid] = 0;
    }

    // sync
    barrier();

    // init
    uint key = 0;
    uint digit = 0;

    // only valid threads contribute
    if (gid < params.keys_size) {
        // element of the array corresponding to this thread
        key = keys_in[gid];

        // the next code line is a "digital microscope" - it slides the number over until the part we care about is under the lens and forgets everything else

        // "(key >> shift)": moves the specific group of bits we want to sort by to the very end (the right side) of the number
        // e.g. if we want the last 4 bits, shift is 0, if we want the next 4 bits, shift is 4

        // "& mask": "&" (bitwise AND) acts as a filter, "mask" is usually a string of 1s that "keeps" only the bits currently in the target window and turns everything else to 0
        // e.g. if our "chunk size" is 4 bits, our mask is 1111 in binary (which is 15 in decimal or 0xF in hex)

        // concrete example: imagine we are sorting the number 213 using 4-bit chunks
        // key: 213, binary: 1101 0101
        // mask: 15, binary: 0000 1111
        // round 1: getting the last 4 bits, (213 >> 0) & 15 <=> 1101 0101 & 0000 1111 <=> 0000 0101 (=5)
        // round 2: getting the next 4 bits, (213 >> 4) & 15 <=> 0000 1101 & 0000 1111 <=> 0000 1101 (=13)

        digit = (key >> params.shift) & 0xF;

        // atomic operation prevents race conditions (multiple threads trying to update the same counter at the same time)
        atomicAdd(local_hist[digit], 1);
    }

    // sync
    barrier();

    // the first 16 threads write the final group counters to the global histogram
    // they write it to the slice corresponding to their group, i.e. [... ggd0 ggd1 ... ggd14 ggd15 ... ]
    if (lid < 16) {
        group_histograms[group * 16 + lid] = local_hist[lid];
    }
}

// some remarks:

// don't return just before barrier()
// it causes indefinite waiting (deadlock)

// "if (condition)": some threads go inside, some skip it, GPU must run the "true" branch and then the "false" branch instead of doing all at once
// e.g. threads 0-15 are in the "true" branch and so they're active but threads 16-31 are in the "false" branch and so they're idle (then it reverses)
// this is called divergence
// small divergence -> acceptable, big divergence -> performance drops
