#[compute]
#version 450

// compute shader used in PCISPH
// first part of the iterative loop
// calculates predicted positions for the next step based on current velocities and forces
// each time it runs it uses different (updated) pressure forces but the same (precomputed) non-pressure forces
// compared to the final integration logic, we include damping/clamping and collision response in the prediction but omit adhesion and xsph for simplicity and performance

layout(local_size_x = 256, local_size_y = 1, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) restrict readonly buffer Positions {
    vec2 positions[];
};

layout(set = 0, binding = 1, std430) restrict readonly buffer Velocities {
    vec2 velocities[];
};

layout(set = 0, binding = 2, std430) restrict readonly buffer Densities {
    float densities[];
};

layout(set = 0, binding = 3, std430) restrict readonly buffer NonPressureForces {
    vec2 non_pressure_forces[];
};

layout(set = 0, binding = 4, std430) restrict readonly buffer PressureForces {
    vec2 pressure_forces[];
};

layout(set = 0, binding = 5, std430) restrict writeonly buffer PredictedPositions {
    vec2 predicted_positions[];
};

layout(set = 0, binding = 6, std430) restrict readonly buffer IsAlive {
    uint is_alive[];
};

layout(set = 0, binding = 7, r32f) uniform restrict readonly image2D glass_sdf_img;

layout(set = 0, binding = 8, rg32f) uniform restrict readonly image2D glass_sdf_gradient_img;

layout(push_constant) uniform Parameters {
    uint particle_count;
    float delta;
    float damping;    // e.g. 0.999
    float vel_clamp;    // e.g. 1.0
    float sdf_imgs_size_x;    // both SDF-related images have the same size
    float sdf_imgs_size_y;    // like above

    // M transform, i.e. translation + rotation + scaling (no shearing)
    // 6 floats: X column and Y column plus origin
    // see the GDScript code for explanation
    float M_X_x;
    float M_X_y;
    float M_Y_x;
    float M_Y_y;
    float M_origin_x;
    float M_origin_y;

    // our positions and velocities are in normalized space but the above transforms assume viewport (unnormalized) space
    // n = normalized, v = viewport (unnormalized)
    float n_to_v_scale_factor_x;
    float n_to_v_scale_factor_y;
    float v_to_n_scale_factor_x;
    float v_to_n_scale_factor_y;
} params;

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

void main() {
    uint id = gl_GlobalInvocationID.x;

    if (id >= params.particle_count) {
        return;
    }

    if (is_alive[id] == 1u) {
        vec2 pos = positions[id];
        vec2 vel = velocities[id];
        vec2 accel = (non_pressure_forces[id] + pressure_forces[id]) / max(densities[id], 1e-6);

        // symplectic Euler integration
        vel += accel * params.delta;

        // optional damping (stability)
        vel *= params.damping;

        // optional velocity clamping (stability)
        vel = clamp(vel, -params.vel_clamp, params.vel_clamp);

        // symplectic Euler integration
        pos += vel * params.delta;

        // SDF collision response
        vec2 M_X = vec2(params.M_X_x, params.M_X_y);
        vec2 M_Y = vec2(params.M_Y_x, params.M_Y_y);
        vec2 M_origin = vec2(params.M_origin_x, params.M_origin_y);
        vec2 local_pos_tmp = apply_inverse_affine(M_X, M_Y, M_origin, vec2(params.n_to_v_scale_factor_x * pos.x, params.n_to_v_scale_factor_y * pos.y));
        vec2 local_pos = vec2(params.v_to_n_scale_factor_x * local_pos_tmp.x, params.v_to_n_scale_factor_y * local_pos_tmp.y);
        vec2 sdf_uv = local_pos;
        bool outside_sdf_img = (sdf_uv.x < 0.0) || (sdf_uv.x > 1.0) || (sdf_uv.y < 0.0) || (sdf_uv.y > 1.0);

        if (!outside_sdf_img) {
            sdf_uv = clamp(sdf_uv, vec2(0.0), vec2(1.0));

            ivec2 sdf_px = ivec2(sdf_uv * vec2(params.sdf_imgs_size_x, params.sdf_imgs_size_y));
            sdf_px = clamp(sdf_px, ivec2(0), ivec2(int(params.sdf_imgs_size_x) - 1, int(params.sdf_imgs_size_y) - 1));

            // to be more accurate, we could also do some interpolation here
            float glass_sdf_value = imageLoad(glass_sdf_img, sdf_px).r;

            // if particle is inside the solid, push it out (omit reflecting velocity becuase we won't be storing any predicted velocities)
            if (glass_sdf_value < 0.0) {

                // already normalized, in local space
                vec2 glass_sdf_gradient_local = imageLoad(glass_sdf_gradient_img, sdf_px).xy;

                // push out of the solid in local space and convert back to world space
                vec2 corrected_local_pos = local_pos - (glass_sdf_value * glass_sdf_gradient_local);
                vec2 pos_tmp = apply_affine(M_X, M_Y, M_origin, vec2(params.n_to_v_scale_factor_x * corrected_local_pos.x, params.n_to_v_scale_factor_y * corrected_local_pos.y));
                pos = vec2(params.v_to_n_scale_factor_x * pos_tmp.x, params.v_to_n_scale_factor_y * pos_tmp.y);
            }
        }

        float bounds_min_x = 0.0;
        float bounds_max_x = 1.0;
        float bounds_min_y = 0.0;
        float bounds_max_y = 1.0;

        // boundary handling, X axis
        if (pos.x < bounds_min_x) {
            pos.x = bounds_min_x;
        } else if (pos.x > bounds_max_x) {
            pos.x = bounds_max_x;
        }

        // boundary handling, Y axis
        if (pos.y < bounds_min_y) {
            pos.y = bounds_min_y;
        } else if (pos.y > bounds_max_y) {
            pos.y = bounds_max_y;
        }

        predicted_positions[id] = pos;
    }
}
