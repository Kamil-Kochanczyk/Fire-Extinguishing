#[compute]
#version 450

// compute shader used to save the information "Am I a neigbhor of the verbose particle or not?" in the alpha channel of the chosen texture

layout(local_size_x = 256, local_size_y = 1, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) restrict readonly buffer NeighborFlags {
    uint neighbor_flags[];
};

layout(set = 0, binding = 1, rgba32f) uniform image2D particle_pos_img;

layout(push_constant) uniform Parameters {
    uint particle_count;
    float image_size;
} params;

void main() {
    uint id = gl_GlobalInvocationID.x;

    if (id >= params.particle_count) {
        return;
    }

    ivec2 pixel_pos = ivec2(int(mod(id, params.image_size)), int(id / params.image_size));

    vec4 pixel = imageLoad(particle_pos_img, pixel_pos);

    pixel.a = float(neighbor_flags[id]);

    imageStore(particle_pos_img, pixel_pos, pixel);
}
