#[compute]
#version 450

layout(local_size_x = 256, local_size_y = 1, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) restrict buffer Positions {
    vec2 positions[];
};

layout(set = 0, binding = 1, std430) restrict buffer Velocities {
    vec2 velocities[];
};

layout(set = 0, binding = 2, std430) restrict readonly buffer Densities {
    float densities[];
};

layout(set = 0, binding = 3, std430) restrict readonly buffer Forces {
    vec2 forces[];
};

layout(set = 0, binding = 4, std430) restrict readonly buffer SortedParticleIndices {
    uint sorted_particle_indices[];
};

layout(set = 0, binding = 5, std430) restrict readonly buffer StartIndices {
    uint start_indices[];
};

layout(set = 0, binding = 6, std430) restrict readonly buffer EndIndices {
    uint end_indices[];
};

layout(set = 0, binding = 7, std430) restrict readonly buffer IsAlive {
    uint is_alive[];
};

layout(set = 0, binding = 8, rgba32f) uniform image2D particle_pos_img;

layout(set = 0, binding = 9, r32f) uniform image2D glass_sdf_img;

layout(set = 0, binding = 10, rg32f) uniform image2D glass_sdf_gradient_img;

layout(push_constant) uniform Parameters {
    uint particle_count;
    float delta;
    float damping;    // e.g. 0.999
    float bounds_damping;    // e.g. 0.5
    float vel_clamp;    // e.g. 1.0
    float particle_pos_img_size;    // assuming square image, width = height
    float sdf_imgs_size_x;    // both SDF-related images have the same size
    float sdf_imgs_size_y;    // like above
    float adhesion_scale;
    float adhesion_threshold;    // e.g. smoothing_radius
    float particle_spacing;
    float smoothing_radius;    // cell size
    float poly6_2d_constant;    // 4 / (π * h^8)
    float mass;
    float xsph_scale;

    // M transform, i.e. translation + rotation + scaling (no shearing)
    // 6 floats: X column and Y column plus origin
    // see the GDScript code for explanation
    float M_X_x;
    float M_X_y;
    float M_Y_x;
    float M_Y_y;
    float M_origin_x;
    float M_origin_y;

    // M_rotation, i.e. the rotation part extracted from M
    // 4 floats: X column and Y column
    // just rotation, no translation, no scaling
    float M_rotation_X_x;
    float M_rotation_X_y;
    float M_rotation_Y_x;
    float M_rotation_Y_y;

    // our positions and velocities are in normalized space but the above transforms assume viewport (unnormalized) space
    // n = normalized, v = viewport (unnormalized)
    float n_to_v_scale_factor_x;
    float n_to_v_scale_factor_y;
    float v_to_n_scale_factor_x;
    float v_to_n_scale_factor_y;

    uint vis_neighborhood_search;    // 0 or 1
} params;

uint hash_cell(ivec2 cell) {
    return ((uint(cell.x) * 73856093u) ^ (uint(cell.y) * 19349663u)) % params.particle_count;
}

mat2 build_mat2(vec2 x, vec2 y) {
    return mat2(x, y);
}

mat2 build_inverse_mat2(vec2 x, vec2 y) {
    float det = (x.x * y.y) - (x.y * y.x);
    return (1.0 / det) * mat2(vec2(y.y, -x.y), vec2(-y.x, x.x));
}

vec2 apply_affine(vec2 x, vec2 y, vec2 origin, vec2 p) {
    return (build_mat2(x, y) * p) + origin;
}

vec2 apply_inverse_affine(vec2 x, vec2 y, vec2 origin, vec2 p) {
    mat2 inv_linear = build_inverse_mat2(x, y);
    return inv_linear * (p - origin);
}

vec2 apply_rotation(vec2 x, vec2 y, vec2 v) {
    // assuming that x and y are the columns of a rotation matrix
    return build_mat2(x, y) * v;
}

vec2 rotate_90_ccw(vec2 v) {
    return vec2(-v.y, v.x);
}

// deterministic pseudo-random generation of floats in the range from 0.0 to 1.0
float hash_uint(uint x) {
    x ^= x >> 16;
    x *= 0x7feb352d;
    x ^= x >> 15;
    x *= 0x846ca68b;
    x ^= x >> 16;
    return float(x) / float(0xffffffffu);
}

// calculate adhesion force contribution from SDF boundary particles
// boundary particles are created implicitly in multiple layers along the surface (as a grid)
// x_i: particle position in world space
// sdf_gradient_world: surface normal pointing outward, in world space, assumed to be normalized
// sdf_value: signed distance to the surface (positive = outside, negative = inside, zero = on the surface)
// particle_id: used as a seed for random number generation
vec2 calculate_adhesion_accel(vec2 x_i, vec2 sdf_gradient_world, float sdf_value, uint particle_id) {
    vec2 x_i_new = x_i;

    // generally, adhesion_threshold can be graater than smoothing_radius
    // but we only consider boundary particles within the smoothing_radius for adhesion calculation
    // so, if the particle's distance from the boundary is larger than the smoothing_radius, then we treat it AS IF it was closer than it really is, in order to allow calculations
    if (params.adhesion_threshold > params.smoothing_radius) {
        if (sdf_value > params.smoothing_radius) {
            // particle's virtual position for adhesion calculation
            // random offset is added to make sure the virtual position is within smoothing_radius distance from the boundary
            // this also avoids all particles having the same adhesion force when they are far from the boundary
            x_i_new = x_i - (((sdf_value - params.smoothing_radius) + (hash_uint(particle_id) * params.smoothing_radius)) * sdf_gradient_world);
        }
    }

    vec2 adhesion_accel = vec2(0.0, 0.0);
    float h2 = params.smoothing_radius * params.smoothing_radius;

    // sdf_value is positive when particle is outside the surface
    // we need to move along the normal direction to reach the surface
    // since sdf_gradient_world points outward, we move in the negative direction
    vec2 base_boundary_pos = x_i - (sdf_gradient_world * sdf_value);

    // we can imagine a square of side (2 * smoothing_radius) around the particle
    // we want to sample boundary particles within that square along the tangent direction (+ and - tangent direction, i.e. along the boundary edge)
    // we'll do sampling along the tangent direction multiple times, creating multiple tangent layers of boundary particles along the normal direction
    // this is to ensure we have enough boundary particles to interact with for better adhesion effect
    // so we'll essentially get a grid of boundary particles near the object's boundary
    // we assume the scale is small enough so that the boundary edge is approximately flat
    // the reference point for one tangent layer is the base_boundary_pos
    // we sample the same number of boundary particles on both sides of the reference point along the tangent direction
    // tangent_layer_num_samples = 2 * #how_many_particles_on_each_side + 1 (1 for the center one, which is exactly on the base_boundary_pos)
    // the spacing between samples is particle_spacing
    // we assume that particles are points, i.e. have no radius
    int tangent_layer_side_num_samples = int(ceil(params.smoothing_radius / params.particle_spacing));
    int tangent_layer_num_samples = (2 * tangent_layer_side_num_samples) + 1;

    // tangential direction along the surface (perpendicular to normal)
    vec2 tangent_dir = rotate_90_ccw(sdf_gradient_world);

    // create multiple tangent layers of boundary particles along the normal direction (into the solid)
    int num_tangent_layers = 3;
    float tangent_layer_spacing = params.particle_spacing;

    for (int tangent_layer = 0; tangent_layer < num_tangent_layers; tangent_layer++) {

        // where to place this tangent layer of boundary particles: move along the normal direction into the solid
        vec2 pos_along_normal = base_boundary_pos - (float(tangent_layer) * tangent_layer_spacing * sdf_gradient_world);

        // sample particles along the tangent direction for this tangent layer
        for (int s = -tangent_layer_side_num_samples; s <= tangent_layer_side_num_samples; s++) {

            // boundary particle position: move along tangent direction
            float offset_dist = float(s) * params.particle_spacing;
            vec2 x_j = pos_along_normal + (tangent_dir * offset_dist);

            // difference vector
            vec2 diff = x_i_new - x_j;
            float r2 = dot(diff, diff);

            // check if within smoothing radius
            if ((r2 < h2) && (r2 > 1e-6)) {

                // adhesion acceleration: a_adh = -alpha * sum((x_i_new - x_j) * W_ij)
                float term = h2 - r2;
                adhesion_accel += (-params.adhesion_scale * diff * params.poly6_2d_constant * term * term * term);
            }
        }
    }

    return adhesion_accel;
}

void main() {
    uint id = gl_GlobalInvocationID.x;

    if (id >= params.particle_count) {
        return;
    }

    if (is_alive[id] == 1u) {
        // our simulation runs in the normalized space to decouple it from the viewport size
        // this is why we can hardcode our world's boundaries
        float bounds_min_x = 0.0;
        float bounds_max_x = 1.0;
        float bounds_min_y = 0.0;
        float bounds_max_y = 1.0;

        vec2 pos = positions[id];
        vec2 vel = velocities[id];

        float rho = max(densities[id], 1e-6);
        vec2 force = forces[id];

        vec2 accel = force / rho;

        // dynamic object collision via signed distance field
        // SDF image encodes signed distance in R, SDF gradient image encodes normalized gradient in RG
        // unfortunately, it seems that we can't generalize this to a function because there is some problem with passing images as function parameters in GLSL
        // so we have to duplicate this code for each SDF-based object that we want to interact with, which is not ideal but should be fine for simple scenes
        vec2 M_X = vec2(params.M_X_x, params.M_X_y);
        vec2 M_Y = vec2(params.M_Y_x, params.M_Y_y);
        vec2 M_origin = vec2(params.M_origin_x, params.M_origin_y);
        vec2 M_rotation_X = vec2(params.M_rotation_X_x, params.M_rotation_X_y);
        vec2 M_rotation_Y = vec2(params.M_rotation_Y_x, params.M_rotation_Y_y);

        // for simplicity, we say that the (normalized) coordinate system corresponding to the "untouched" glass in called local space
        // therefore, the (normalized) coordinate system corresponding to the "touched" (moved/rotated/scaled) glass is called world space
        // both local and world space are normalized coordinate systems where (0, 0) is the top-left corner and (1, 1) is the bottom-right corner
        // local space is basically the UV coordinate space typically used by textures
        // world space is the particles' default coordinate system, used in other parts of the pipeline
        vec2 local_pos_tmp = apply_inverse_affine(M_X, M_Y, M_origin, vec2(params.n_to_v_scale_factor_x * pos.x, params.n_to_v_scale_factor_y * pos.y));
        vec2 local_pos = vec2(params.v_to_n_scale_factor_x * local_pos_tmp.x, params.v_to_n_scale_factor_y * local_pos_tmp.y);

        // since bounds are from 0 to 1 in local space, we can directly use local_pos as sdf_uv without needing to do the usual (pos - bounds_min) / (bounds_max - bounds_min) conversion
        // vec2 sdf_uv = (local_pos - vec2(bounds_min_x, bounds_min_y)) / vec2(bounds_max_x - bounds_min_x, bounds_max_y - bounds_min_y);
        vec2 sdf_uv = local_pos;

        // if uv is outside [0, 1], we skip the SDF-related stuff as it means the particle is outside the area covered by the SDF
        // in other words, it can't collide with the solid object represented by the SDF becuase it's too far
        bool outside_sdf_img = (sdf_uv.x < 0.0) || (sdf_uv.x > 1.0) || (sdf_uv.y < 0.0) || (sdf_uv.y > 1.0);

        if (!outside_sdf_img) {
            sdf_uv = clamp(sdf_uv, vec2(0.0), vec2(1.0));

            ivec2 sdf_px = ivec2(sdf_uv * vec2(params.sdf_imgs_size_x, params.sdf_imgs_size_y));
            sdf_px = clamp(sdf_px, ivec2(0), ivec2(int(params.sdf_imgs_size_x) - 1, int(params.sdf_imgs_size_y) - 1));

            // to be more accurate, we could also do some interpolation between texels
            float glass_sdf_value = imageLoad(glass_sdf_img, sdf_px).r;
            
            // already normalized, in local space
            vec2 glass_sdf_gradient_local = imageLoad(glass_sdf_gradient_img, sdf_px).xy;

            // transform to world space
            vec2 glass_sdf_gradient_world_tmp = apply_rotation(M_rotation_X, M_rotation_Y, vec2(params.n_to_v_scale_factor_x * glass_sdf_gradient_local.x, params.n_to_v_scale_factor_y * glass_sdf_gradient_local.y));
            vec2 glass_sdf_gradient_world = vec2(params.v_to_n_scale_factor_x * glass_sdf_gradient_world_tmp.x, params.v_to_n_scale_factor_y * glass_sdf_gradient_world_tmp.y);

            if ((glass_sdf_value > 0.0) && (glass_sdf_value < params.adhesion_threshold)) {
                // particle is near the surface (but outside), apply adhesion force (or acceleration, actually)
                vec2 adhesion_accel = calculate_adhesion_accel(pos, glass_sdf_gradient_world, glass_sdf_value, id);
                accel += adhesion_accel;
            }
        }

        // symplectic Euler integration
        vel += accel * params.delta;

        // optional XSPH smoothing
        if (params.xsph_scale > 0.0) {
            vec2 xsph_delta = vec2(0.0, 0.0);

            float h = params.smoothing_radius;
            float h2 = h * h;

            ivec2 base_cell = ivec2(floor(pos / h));

            for (int dy = -1; dy <= 1; dy++) {
                for (int dx = -1; dx <= 1; dx++) {

                    ivec2 neighbor_cell = base_cell + ivec2(dx, dy);
                    uint hash = hash_cell(neighbor_cell);

                    uint start_idx = start_indices[hash];
                    uint end_idx = end_indices[hash];

                    for (uint i = start_idx; i < end_idx; i++) {
                        uint neighbor_idx = sorted_particle_indices[i];

                        // avoid self in the calculations in this case
                        if (neighbor_idx == id) {
                            continue;
                        }

                        vec2 diff = positions[neighbor_idx] - pos;
                        float r2 = dot(diff, diff);

                        if (r2 < h2) {
                            float term = h2 - r2;
                            float rho_neighbor = densities[neighbor_idx];
                            vec2 vel_neighbor = velocities[neighbor_idx];
                            xsph_delta += (params.mass / rho_neighbor) * (vel_neighbor - vel) * (params.poly6_2d_constant * term * term * term);
                        }
                    }
                }
            }

            vel += params.xsph_scale * xsph_delta;
        }

        // optional damping (stability)
        vel *= params.damping;

        // optional velocity clamping (stability)
        vel = clamp(vel, -params.vel_clamp, params.vel_clamp);

        // symplectic Euler integration
        pos += vel * params.delta;
        
        // SDF collision response
        // particle moved so we repeat the previous steps
        local_pos_tmp = apply_inverse_affine(M_X, M_Y, M_origin, vec2(params.n_to_v_scale_factor_x * pos.x, params.n_to_v_scale_factor_y * pos.y));
        local_pos = vec2(params.v_to_n_scale_factor_x * local_pos_tmp.x, params.v_to_n_scale_factor_y * local_pos_tmp.y);
        sdf_uv = local_pos;
        outside_sdf_img = (sdf_uv.x < 0.0) || (sdf_uv.x > 1.0) || (sdf_uv.y < 0.0) || (sdf_uv.y > 1.0);

        if (!outside_sdf_img) {
            sdf_uv = clamp(sdf_uv, vec2(0.0), vec2(1.0));

            ivec2 sdf_px = ivec2(sdf_uv * vec2(params.sdf_imgs_size_x, params.sdf_imgs_size_y));
            sdf_px = clamp(sdf_px, ivec2(0), ivec2(int(params.sdf_imgs_size_x) - 1, int(params.sdf_imgs_size_y) - 1));

            // to be more accurate, we could also do some interpolation here
            float glass_sdf_value = imageLoad(glass_sdf_img, sdf_px).r;

            // if particle is inside the solid, push it out and reflect velocity
            if (glass_sdf_value < 0.0) {

                // already normalized, in local space
                vec2 glass_sdf_gradient_local = imageLoad(glass_sdf_gradient_img, sdf_px).xy;

                // transform to world space
                vec2 glass_sdf_gradient_world_tmp = apply_rotation(M_rotation_X, M_rotation_Y, vec2(params.n_to_v_scale_factor_x * glass_sdf_gradient_local.x, params.n_to_v_scale_factor_y * glass_sdf_gradient_local.y));
                vec2 glass_sdf_gradient_world = vec2(params.v_to_n_scale_factor_x * glass_sdf_gradient_world_tmp.x, params.v_to_n_scale_factor_y * glass_sdf_gradient_world_tmp.y);

                // push out of the solid in local space and convert back to world space
                vec2 corrected_local_pos = local_pos - (glass_sdf_value * glass_sdf_gradient_local);
                vec2 pos_tmp = apply_affine(M_X, M_Y, M_origin, vec2(params.n_to_v_scale_factor_x * corrected_local_pos.x, params.n_to_v_scale_factor_y * corrected_local_pos.y));
                pos = vec2(params.v_to_n_scale_factor_x * pos_tmp.x, params.v_to_n_scale_factor_y * pos_tmp.y);

                float v_normal_component = dot(vel, glass_sdf_gradient_world);

                // only react if moving INTO the surface
                if (v_normal_component < 0.0) {

                    vec2 v_n = v_normal_component * glass_sdf_gradient_world;
                    vec2 v_t = vel - v_n;

                    float restitution = 0.1;    // bounce, 0 for inelastic (stick to the surface), 1 for perfectly elastic (no energy loss, bounce back with the same speed)
                    float friction = 0.1;    // surface friction, 0 for no friction (smooth sliding along the surface), 1 for very high friction (stop all tangential movement)

                    vec2 new_v_n = -restitution * v_n;
                    vec2 new_v_t = (1.0 - friction) * v_t;

                    vel = new_v_n + new_v_t;
                }
                
                vel *= params.bounds_damping;
            }
        }

        // boundary handling, X axis
        if (pos.x < bounds_min_x) {
            pos.x = bounds_min_x;
            vel.x *= -params.bounds_damping;
        } else if (pos.x > bounds_max_x) {
            pos.x = bounds_max_x;
            vel.x *= -params.bounds_damping;
        }

        // boundary handling, Y axis
        if (pos.y < bounds_min_y) {
            pos.y = bounds_min_y;
            vel.y *= -params.bounds_damping;
        } else if (pos.y > bounds_max_y) {
            pos.y = bounds_max_y;
            vel.y *= -params.bounds_damping;
        }

        // finito!
        positions[id] = pos;
        velocities[id] = vel;
    }

    // if we don't visualize neighborhood search, this pass is the last pass
    if (params.vis_neighborhood_search == 0u) {
        ivec2 pixel_pos = ivec2(int(mod(id, params.particle_pos_img_size)), int(id / params.particle_pos_img_size));
        imageStore(particle_pos_img, pixel_pos, vec4(positions[id].x, positions[id].y, 0.0, 0.0));
    }
}
